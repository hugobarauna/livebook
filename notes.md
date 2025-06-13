# Livebook Project Exploration

## Project Overview
- **App**: Livebook - Interactive notebook platform for Elixir
- **Version**: 0.17.0-dev 
- **Framework**: Phoenix LiveView application
- **Requirements**: Erlang/OTP 25+, Elixir ~> 1.18

## Key Directories & Files
- `lib/` - Main application code
- `assets/` - Frontend assets (JS, CSS)
- `config/` - Configuration files
- `static/` - Static assets
- `test/` - Test files
- `docs/` - Documentation
- `elixirkit/` - ElixirKit integration (for desktop app)
- `iframe/` - Iframe-related code
- `proto/` - Protocol buffer definitions
- `rel/` - Release configuration

## Key Files Found
- `lib/livebook_cli.ex` - Command line interface
- `lib/livebook.ex` - Main application module
- `lib/livebook_app.ex` - App-specific logic
- `lib/livebook_web.ex` - Web interface module

## LiveView Structure
The application has a rich set of LiveViews including:
- `home_live.ex` - Main home page
- `session_live.ex` - Core notebook session interface (68KB file!)
- `apps_live.ex` - Apps management
- `app_live.ex` - Individual app interface
- `settings_live.ex` - Settings management
- `learn_live.ex` - Learning/tutorial section
- `open_live.ex` - File opening interface

## Router Structure
- Uses Phoenix LiveDashboard
- Has authentication pipelines (`:auth`, `:browser`)
- Complex routing with multiple live_sessions
- Supports both authenticated and public routes

## Dependencies Status
- Successfully fetching dependencies
- Project appears to compile cleanly
- Ready for development/exploration

## Next Steps
- Explore the web interface structure
- Check current routing and LiveViews
- Identify areas for potential enhancement or bug fixes

