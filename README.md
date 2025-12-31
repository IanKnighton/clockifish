# clockifish

A Swift command-line interface (CLI) tool for interacting with the Clockify time tracking API.

## Features

- 🚀 Start timers with optional descriptions and project associations
- ⏹️ Stop currently running timers
- 📊 Check the status of your current timer
- 🔐 Secure API key management via environment variables
- 📝 Well-documented and easy to test locally

## Requirements

- Swift 6.0 or later
- macOS 13 or later (or Linux with Swift installed)
- A Clockify account with API access

## Setup

### 1. Get Your Clockify Credentials

You'll need two pieces of information from your Clockify account:

**API Key:**
1. Log in to [Clockify](https://clockify.me)
2. Go to Settings → Profile
3. Scroll down to find your API key
4. Copy the API key

**Workspace ID:**
1. In Clockify, go to your workspace
2. Look at the URL - it will be like `https://app.clockify.me/workspaces/{workspace_id}/...`
3. Copy the workspace ID from the URL

### 2. Set Environment Variables

Add these to your shell profile (`~/.zshrc`, `~/.bashrc`, or equivalent):

```bash
export CLOCKIFY_API_KEY="your_api_key_here"
export CLOCKIFY_WORKSPACE_ID="your_workspace_id_here"
```

Then reload your shell:
```bash
source ~/.zshrc  # or ~/.bashrc
```

### 3. Build the Application

Clone the repository and build:

```bash
git clone https://github.com/IanKnighton/clockifish.git
cd clockifish
swift build -c release
```

### 4. Install (Optional)

Copy the executable to your PATH:

```bash
cp .build/release/clockifish /usr/local/bin/
```

Or run directly from the build directory:
```bash
.build/release/clockifish
```

## Usage

### Start a Timer

Start a simple timer:
```bash
clockifish timer start
```

Start a timer with a description:
```bash
clockifish timer start --description "Working on feature X"
# or shorthand:
clockifish timer start -d "Working on feature X"
```

Start a timer with a description and project:
```bash
clockifish timer start -d "Bug fix" -p "project_id_here"
```

### Stop a Timer

Stop the currently running timer:
```bash
clockifish timer stop
```

### Check Timer Status

Check if a timer is running and see its details:
```bash
clockifish timer status
```

### Help

Get help for any command:
```bash
clockifish --help
clockifish timer --help
clockifish timer start --help
```

## Testing Locally

### 1. Set up test environment variables

```bash
export CLOCKIFY_API_KEY="your_test_api_key"
export CLOCKIFY_WORKSPACE_ID="your_test_workspace_id"
```

### 2. Build and run

```bash
swift build
.build/debug/clockifish timer start -d "Test timer"
.build/debug/clockifish timer status
.build/debug/clockifish timer stop
```

### 3. Verify in Clockify

Check your Clockify dashboard to verify that the time entries were created and stopped correctly.

## Development

### Project Structure

```
clockifish/
├── Package.swift              # Swift Package Manager manifest
├── Sources/
│   └── clockifish/
│       ├── main.swift         # CLI entry point and command definitions
│       └── ClockifyClient.swift  # API client and data models
└── Tests/
    └── clockifishTests/       # Unit tests (if applicable)
```

### Building for Development

```bash
swift build
```

### Running Tests

```bash
swift test
```

### Code Documentation

The code is fully documented with Swift DocC-style comments. Key components:

- **`main.swift`**: Defines the CLI structure using Swift Argument Parser
- **`ClockifyClient.swift`**: Handles all API communication with Clockify
- **Environment Variables**: All configuration is done via environment variables for security

## Troubleshooting

### "CLOCKIFY_API_KEY environment variable is not set"

Make sure you've set the environment variable and reloaded your shell:
```bash
export CLOCKIFY_API_KEY="your_api_key"
source ~/.zshrc
```

### "API Error (401): Unauthorized"

Your API key may be incorrect. Double-check it in Clockify settings.

### "API Error (404): Not Found"

Your workspace ID may be incorrect. Verify it from the Clockify URL.

### "No timer is currently running"

This means there's no active timer when you tried to stop or check status. Start a timer first.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

Created by [Ian Knighton](https://github.com/IanKnighton)

Uses the [Clockify API](https://clockify.me/developers-api)
