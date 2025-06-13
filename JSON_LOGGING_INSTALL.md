# Livebook JSON Logging Feature Installation Guide

## 🎯 Overview
This bundle adds JSON logging support to Livebook via the `LIVEBOOK_LOG_FORMAT` environment variable, making it easy to integrate with log aggregation services like Datadog, Splunk, or ELK stack.

## 📋 Prerequisites
- Git installed on your local machine
- Elixir and Phoenix development environment
- Fresh clone of the Livebook repository

## 🚀 Installation Steps

### Step 1: Clone Livebook (if you haven't already)
```bash
git clone https://github.com/livebook-dev/livebook.git
cd livebook
```

### Step 2: Download the Bundle
Copy the `livebook-json-logging.bundle` file to your local machine and place it in your Livebook project directory.

### Step 3: Apply the Bundle
```bash
# Verify the bundle is valid
git bundle verify livebook-json-logging.bundle

# Create a new branch for the JSON logging feature
git checkout -b feature/json-logging

# Apply all commits from the bundle
git pull livebook-json-logging.bundle main
```

### Step 4: Install Dependencies and Test
```bash
# Install dependencies
mix deps.get

# Compile the project
mix compile

# Test console logging (default)
mix phx.server

# Test JSON logging (in a new terminal)
LIVEBOOK_LOG_FORMAT=json mix phx.server
```

## 🔧 Usage

### Environment Variable Options
- `LIVEBOOK_LOG_FORMAT=console` - Default human-readable format
- `LIVEBOOK_LOG_FORMAT=json` - Structured JSON format for log aggregation

### Console Format Example
```
2025-06-13 18:04:53.296 [info] Running LivebookWeb.Endpoint with Bandit 1.6.8 at 127.0.0.1:4000 (http)
```

### JSON Format Example
```json
{"message":"Running LivebookWeb.Endpoint with Bandit 1.6.8 at 127.0.0.1:4000 (http)","timestamp":"2025-06-13T18:04:46.000671","level":"info"}
```

## 🏗️ Implementation Details

### Files Added/Modified
1. **`lib/livebook/logger/json_formatter.ex`** - New JSON formatter module
2. **`lib/livebook/config.ex`** - Added `log_format!/1` validation function
3. **`lib/livebook.ex`** - Integrated JSON logging into runtime configuration

### Validation
The implementation includes proper validation:
- Accepts only "console" or "json" values
- Falls back to "console" for invalid values
- Follows existing Livebook configuration patterns

## 🔍 Testing the Feature

### Quick Test
```bash
# Test JSON format
LIVEBOOK_LOG_FORMAT=json mix run -e "require Logger; Logger.info(\"Test JSON logging\")"

# Test console format  
LIVEBOOK_LOG_FORMAT=console mix run -e "require Logger; Logger.info(\"Test console logging\")"
```

### Production Usage
Set the environment variable in your deployment:
```bash
export LIVEBOOK_LOG_FORMAT=json
```

## 🤝 Contributing
This feature is ready for production use and follows Livebook's existing patterns. Consider submitting a pull request to the main Livebook repository!

## 📝 Commit History
- `c4eace8c` - Document successful JSON logging implementation
- `8ecd9aa0` - Fix syntax error in config_runtime/0
- `e99d472a` - Add JSON logging configuration to runtime config
- `0a991594` - Fix JSON formatter implementation
- `0b6ab3c5` - Add JSON logger formatter
- `c706129c` - Add log_format validation function

## 🎉 Success!
You now have JSON logging support in your Livebook installation. Perfect for integrating with modern log aggregation and monitoring systems!
