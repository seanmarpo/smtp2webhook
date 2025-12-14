# SMTP2Webhook

A simple Rust application that runs an SMTP server and forwards incoming emails to a configurable HTTP webhook.

Specifically designed to bridge the gap in software that only supports notifications via email, such as monitoring tools or alerting systems.

Now you can send webhooks for any email based notification to Discord, Slack, or any other service that supports webhooks.

## Features

- 🚀 Lightweight SMTP server
- 🔗 Forwards emails to HTTP webhooks as JSON
- 🔄 Automatic retry logic with exponential backoff
- ⚙️ Simple TOML configuration
- 🔓 Accepts any SMTP authentication (designed for local/internal use)
- 📝 Structured logging

## Installation

### Prerequisites

- Rust 1.70 or higher
- Cargo

### Building from Source

```bash
cargo build --release
```

The binary will be available at `target/release/smtp2webhook`.

## Quick Start

1. **Build the project:**
   ```bash
   cargo build --release
   ```

2. **Create a configuration file:**
   ```bash
   cp config.toml.example config.toml
   # Edit config.toml to set your webhook URL
   ```

3. **Run the server:**
   ```bash
   cargo run --release
   ```

4. **Send a test email** (using netcat):
   ```bash
   ./testing/test_send_email.sh
   ```

## Configuration

Copy the example configuration file and customize it:

```bash
cp config.toml.example config.toml
```

### Configuration Options

```toml
[smtp]
# The address to bind the SMTP server to
bind_address = "127.0.0.1:2525"
# Server hostname
hostname = "localhost"

[webhook]
# The HTTP endpoint to POST emails to
url = "http://localhost:8080/webhook"
# Number of retry attempts on failure
max_retries = 3
# Timeout in seconds for each request
timeout_secs = 30

# Optional: Custom HTTP headers to send with webhook requests
# Uncomment and modify as needed for authentication, etc.
# [webhook.headers]
# Authorization = "Bearer your-token-here"
# X-API-Key = "your-api-key"
# X-Custom-Header = "custom-value"

[logging]
# Log level: trace, debug, info, warn, error
level = "info"
```

#### Custom Headers

You can add custom HTTP headers to webhook requests for authentication or other purposes:

```toml
[webhook]
url = "https://api.example.com/webhook"
max_retries = 3
timeout_secs = 30

[webhook.headers]
Authorization = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
X-API-Key = "your-secret-api-key"
X-Custom-Header = "custom-value"
User-Agent = "smtp2webhook/0.1.0"
```

Common use cases for custom headers:
- **Authentication**: `Authorization`, `X-API-Key`
- **Request identification**: `X-Request-ID`, `X-Correlation-ID`
- **Custom metadata**: `X-Source`, `X-Environment`
- **Content negotiation**: `Accept`, `Accept-Language`
```

## Usage

Run the server with the default config file (`config.toml`):

```bash
cargo run
```

Or specify a custom configuration file:

```bash
cargo run -- /path/to/config.toml
```

For the release binary:

```bash
./target/release/smtp2webhook [config.toml]
```

## Webhook Payload

Emails are sent to the webhook as JSON POST requests with the following structure:

```json
{
  "from": "sender@example.com",
  "to": ["recipient@example.com"],
  "subject": "Email Subject",
  "body": "Email body content",
}
```

## Error Handling

- If the webhook fails, the server will retry up to `max_retries` times with exponential backoff
- After exhausting retries, the email is dropped and an error is logged
- The SMTP server will still respond with success to the sender to avoid email bounces

## Security Note

⚠️ **This server is designed for local/internal use only!**

- It accepts any SMTP authentication
- No TLS/SSL support by default
- Do not expose this server to the public internet

## License

See LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
