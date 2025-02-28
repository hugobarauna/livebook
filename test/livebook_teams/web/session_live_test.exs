defmodule LivebookWeb.Integration.SessionLiveTest do
  use Livebook.TeamsIntegrationCase, async: true

  import Phoenix.LiveViewTest
  import Livebook.SessionHelpers

  alias Livebook.{Sessions, Session}

  setup do
    {:ok, session} = Sessions.create_session(notebook: Livebook.Notebook.new())

    on_exit(fn ->
      Session.close(session.pid)
    end)

    %{session: session}
  end

  describe "hubs" do
    test "selects the notebook hub", %{conn: conn, user: user, node: node, session: session} do
      hub = create_team_hub(user, node)
      id = hub.id
      personal_id = Livebook.Hubs.Personal.id()

      Session.subscribe(session.id)
      {:ok, view, _} = live(conn, ~p"/sessions/#{session.id}")

      assert Session.get_data(session.pid).notebook.hub_id == personal_id

      view
      |> element(~s/#select-hub-#{id}/)
      |> render_click()

      assert_receive {:operation, {:set_notebook_hub, _, ^id}}
      assert Session.get_data(session.pid).notebook.hub_id == hub.id
    end
  end

  describe "secrets" do
    test "creates a new secret", %{conn: conn, user: user, node: node, session: session} do
      team = create_team_hub(user, node)
      Session.subscribe(session.id)

      # loads the session page
      {:ok, view, _} = live(conn, ~p"/sessions/#{session.id}")

      # selects the notebook's hub with team hub id
      view
      |> element(~s/#select-hub-#{team.id}/)
      |> render_click()

      # clicks the button to add a new secret
      view
      |> with_target("#secrets_list")
      |> element("#new-secret-button")
      |> render_click(%{})

      # redirects to secrets action to
      # render the secret modal
      assert_patch(view, ~p"/sessions/#{session.id}/secrets")

      secret =
        build(:secret,
          name: "BIG_IMPORTANT_SECRET",
          value: "123",
          hub_id: team.id
        )

      attrs = %{
        secret: %{
          name: secret.name,
          value: secret.value,
          hub_id: team.id
        }
      }

      # fills and submits the secrets modal form
      # to create a new secret on team hub
      secrets_modal = with_target(view, "#secrets")
      form = element(secrets_modal, ~s{form[phx-submit="save"]})

      render_change(form, attrs)
      render_submit(form, attrs)

      # receives the operation event
      assert_receive {:operation, {:sync_hub_secrets, "__server__"}}
      assert secret in Livebook.Hubs.get_secrets(team)

      # checks the secret on the UI
      assert_session_secret(view, session.pid, secret, :hub_secrets)
    end

    test "redirects the user to update or delete a secret",
         %{conn: conn, user: user, node: node, session: session} do
      Livebook.Hubs.subscribe([:secrets, :connection])
      team = create_team_hub(user, node)
      id = team.id
      assert_receive {:hub_connected, ^id}

      Session.subscribe(session.id)

      # creates a secret
      secret_name = "BIG_IMPORTANT_SECRET_TO_BE_UPDATED_OR_DELETED"
      secret_value = "123"

      insert_secret(
        name: secret_name,
        value: secret_value,
        hub_id: team.id
      )

      assert_receive {:secret_created, %{name: ^secret_name, value: ^secret_value}}

      # selects the notebook's hub with team hub id
      Session.set_notebook_hub(session.pid, team.id)

      # loads the session page
      {:ok, view, _} = live(conn, ~p"/sessions/#{session.id}")

      # clicks the button to edit a secret
      view
      |> with_target("#secrets_list")
      |> element("#hub-#{id}-secret-#{secret_name}-edit-button")
      |> render_click()

      # redirects to hub page and loads the modal with
      # the secret name and value filled
      assert_redirect(view, ~p"/hub/#{id}/secrets/edit/#{secret_name}")
    end

    test "toggle a secret from team hub", %{conn: conn, session: session, user: user, node: node} do
      team = create_team_hub(user, node)
      Session.subscribe(session.id)

      # loads the session page
      {:ok, view, _} = live(conn, ~p"/sessions/#{session.id}")

      # selects the notebook's hub with team hub id
      Session.set_notebook_hub(session.pid, team.id)

      # creates a new secret
      secret =
        build(:secret,
          name: "POSTGRES_PASSWORD",
          value: "123456789",
          hub_id: team.id
        )

      assert Livebook.Teams.create_secret(team, secret) == :ok

      # receives the operation event
      assert_receive {:operation, {:sync_hub_secrets, "__server__"}}
      assert secret in Livebook.Hubs.get_secrets(team)

      # checks the secret on the UI
      Session.set_secret(session.pid, secret)
      assert_session_secret(view, session.pid, secret)
    end

    test "adding a missing secret using 'Add secret' button",
         %{conn: conn, user: user, node: node, session: session} do
      team = create_team_hub(user, node)

      secret =
        build(:secret,
          name: "MYSQL_PASS",
          value: "admin",
          hub_id: team.id
        )

      # selects the notebook's hub with team hub id
      Session.set_notebook_hub(session.pid, team.id)

      # subscribe and executes the code to trigger
      # the `System.EnvError` exception and outputs the 'Add secret' button
      Session.subscribe(session.id)
      section_id = insert_section(session.pid)
      code = ~s{System.fetch_env!("LB_#{secret.name}")}
      cell_id = insert_text_cell(session.pid, section_id, :code, code)

      Session.queue_cell_evaluation(session.pid, cell_id)
      assert_receive {:operation, {:add_cell_evaluation_response, _, ^cell_id, _, _}}

      # enters the session to check if the button exists
      {:ok, view, _} = live(conn, ~p"/sessions/#{session.id}")
      expected_url = ~p"/sessions/#{session.id}/secrets?secret_name=#{secret.name}"
      add_secret_button = element(view, "a[href='#{expected_url}']")
      assert has_element?(add_secret_button)

      # clicks the button and fills the form to create a new secret
      # that prefilled the name with the received from exception.
      render_click(add_secret_button)
      secrets_component = with_target(view, "#secrets-modal")
      form_element = element(secrets_component, "form[phx-submit='save']")
      assert has_element?(form_element)
      attrs = %{value: secret.value, hub_id: team.id}
      render_submit(form_element, %{secret: attrs})

      # receives the operation event
      assert_receive {:operation, {:sync_hub_secrets, "__server__"}}
      assert secret in Livebook.Hubs.get_secrets(team)

      # checks if the secret exists and is inside the session,
      # then executes the code cell again and checks if the
      # secret value is what we expected.
      assert_session_secret(view, session.pid, secret, :hub_secrets)
      Session.queue_cell_evaluation(session.pid, cell_id)

      assert_receive {:operation,
                      {:add_cell_evaluation_response, _, ^cell_id,
                       %{type: :terminal_text, text: output}, _}}

      assert output == "\e[32m\"#{secret.value}\"\e[0m"
    end

    test "granting access for missing secret using 'Add secret' button",
         %{conn: conn, user: user, node: node, session: session} do
      team = create_team_hub(user, node)

      secret =
        build(:secret,
          name: "PGPASS",
          value: "admin",
          hub_id: team.id
        )

      # selects the notebook's hub with team hub id
      Session.set_notebook_hub(session.pid, team.id)

      # subscribe and executes the code to trigger
      # the `System.EnvError` exception and outputs the 'Add secret' button
      Session.subscribe(session.id)
      section_id = insert_section(session.pid)
      code = ~s{System.fetch_env!("LB_#{secret.name}")}
      cell_id = insert_text_cell(session.pid, section_id, :code, code)

      Session.queue_cell_evaluation(session.pid, cell_id)
      assert_receive {:operation, {:add_cell_evaluation_response, _, ^cell_id, _, _}}

      # enters the session to check if the button exists
      {:ok, view, _} = live(conn, ~p"/sessions/#{session.id}")
      expected_url = ~p"/sessions/#{session.id}/secrets?secret_name=#{secret.name}"
      add_secret_button = element(view, "a[href='#{expected_url}']")
      assert has_element?(add_secret_button)

      # creates the secret
      assert Livebook.Teams.create_secret(team, secret) == :ok

      # receives the operation event
      assert_receive {:operation, {:sync_hub_secrets, "__server__"}}
      assert secret in Livebook.Hubs.get_secrets(team)

      # remove the secret from session
      Session.unset_secret(session.pid, secret.name)

      # clicks the button and checks if the 'Grant access' banner
      # is being shown, so clicks it's button to set the app secret
      # to the session, allowing the user to fetches the secret.
      render_click(add_secret_button)
      secrets_component = with_target(view, "#secrets-modal")

      assert render(secrets_component) =~
               "in #{hub_label(team)}. Allow this session to access it?"

      grant_access_button = element(secrets_component, "button", "Grant access")
      render_click(grant_access_button)

      # checks if the secret exists and is inside the session,
      # then executes the code cell again and checks if the
      # secret value is what we expected.
      assert_session_secret(view, session.pid, secret, :hub_secrets)
      Session.queue_cell_evaluation(session.pid, cell_id)

      assert_receive {:operation,
                      {:add_cell_evaluation_response, _, ^cell_id,
                       %{type: :terminal_text, text: output}, _}}

      assert output == "\e[32m\"#{secret.value}\"\e[0m"
    end
  end

  describe "files" do
    test "shows only hub's file systems",
         %{conn: conn, user: user, node: node, session: session} do
      Session.subscribe(session.id)
      Livebook.Hubs.subscribe([:file_systems])

      personal_id = Livebook.Hubs.Personal.id()
      personal_file_system = build(:fs_s3)
      Livebook.Hubs.Personal.save_file_system(personal_file_system)

      team = create_team_hub(user, node)
      team_id = team.id

      bucket_url = "https://my-own-bucket.s3.amazonaws.com"

      file_system =
        build(:fs_s3,
          id: Livebook.FileSystem.S3.id(team_id, bucket_url),
          bucket_url: bucket_url,
          hub_id: team_id
        )

      Livebook.Hubs.create_file_system(team, file_system)
      assert_receive {:file_system_created, team_file_system}

      # loads the session page
      {:ok, view, _html} = live(conn, ~p"/sessions/#{session.id}/add-file/storage")

      # change the hub to Personal
      # and checks the file systems from Personal
      Session.set_notebook_hub(session.pid, personal_id)
      assert_receive {:operation, {:set_notebook_hub, _client, ^personal_id}}

      # targets the file system dropdown menu
      file_system_menu = with_target(view, "#add-file-entry-modal #file-system-menu-content")

      # checks the file systems from Personal
      assert has_element?(file_system_menu, "#file-system-local")
      assert has_element?(file_system_menu, "#file-system-#{personal_file_system.id}")
      refute has_element?(file_system_menu, "#file-system-#{team_file_system.id}")

      # change the hub to Team
      # and checks the file systems from Team
      Session.set_notebook_hub(session.pid, team.id)
      assert_receive {:operation, {:set_notebook_hub, _client, ^team_id}}

      assert has_element?(file_system_menu, "#file-system-local")
      refute has_element?(file_system_menu, "#file-system-#{personal_file_system.id}")
      assert has_element?(file_system_menu, "#file-system-#{team_file_system.id}")
    end

    test "shows file system from offline hub", %{conn: conn, session: session} do
      Session.subscribe(session.id)
      Livebook.Hubs.subscribe([:file_systems])

      hub = offline_hub()
      hub_id = hub.id
      bucket_url = "https://#{hub.id}-file-system.s3.amazonaws.com"

      file_system =
        build(:fs_s3,
          id: Livebook.FileSystem.S3.id(hub_id, bucket_url),
          bucket_url: bucket_url,
          hub_id: hub_id,
          external_id: "123"
        )

      put_offline_hub_file_system(file_system)
      assert_receive {:file_system_created, ^file_system}

      # loads the session page
      {:ok, view, _html} = live(conn, ~p"/sessions/#{session.id}/add-file/storage")

      # change the hub to Personal
      # and checks the file systems from Offline hub
      Session.set_notebook_hub(session.pid, hub_id)
      assert_receive {:operation, {:set_notebook_hub, _client, ^hub_id}}

      # targets the file system dropdown menu
      file_system_menu = with_target(view, "#add-file-entry-select #file-system-menu-content")

      # checks the file systems from Offline hub
      assert has_element?(file_system_menu, "#file-system-local")
      assert has_element?(file_system_menu, "#file-system-#{file_system.id}")

      remove_offline_hub_file_system(file_system)
    end
  end
end
