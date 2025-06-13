defmodule Livebook.Logger.JsonFormatter do
  @moduledoc """
  A custom logger formatter that outputs structured JSON logs.

  This formatter is designed to work with log aggregation services
  like Datadog, Splunk, or ELK stack that can parse JSON logs.
  """

  @doc """
  Formats log events as JSON.

  ## Options

    * `:metadata` - List of metadata keys to include in the JSON output.
      Defaults to `[:request_id, :module, :function, :file, :line]`

  ## Examples

      config :logger, :console,
        format: {Livebook.Logger.JsonFormatter, :format},module, :function]

  """
  def format(level, message, timestamp, metadata) do
    %{
      timestamp: format_timestamp(timestamp),
      level: level,
      message: IO.iodata_to_binary_metadata(metadata)
    }
    |> JSON.encode!()
    |> Kernel.<>("\n")
  end

  defp format_timestamp({{year, month, day}, {hour, minute, second, microsecond}}) do
    with {:ok, datetime} <-
           NaiveDateTime.new(year, month, day, hour, minute, second, {microsecond, 6}) do
      NaiveDateTime.to_iso8601(datetime)
    else
      _ -> "invalid_timestamp"
    end
  end

  defp format_metadata(metadata) do
    metadata
    |> Enum.into(%{})
    |> Map.take([:request_id, :module, :function, :file, :line, :pid, :registered_name])
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end
end
