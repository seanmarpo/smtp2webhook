# SMTP2Webhook

A simple Rust application that runs an SMTP server and forwards incoming emails to a configurable HTTP webhook.

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
   ./test_send_email.sh
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

## Docker Deployment

### Using Docker Compose (Recommended)

The easiest way to run smtp2webhook with Docker:

1. **Create your configuration:**
   ```bash
   cp config.toml.example config.toml
   # Edit config.toml with your settings
   ```

2. **Start the services:**
   ```bash
   docker-compose up -d
   ```

This will start both the SMTP server and a test webhook receiver.

### Using Docker Manually

1. **Build the image:**
   ```bash
   docker build -t smtp2webhook .
   ```

2. **Run the container:**
   ```bash
   docker run -d \
     --name smtp2webhook \
     -p 2525:2525 \
     -v $(pwd)/config.toml:/app/config/config.toml:ro \
     smtp2webhook
   ```

### Docker Configuration Notes

- The SMTP server listens on port 2525 inside the container
- Mount your `config.toml` file to `/app/config/config.toml`
- The webhook URL should point to the appropriate service (use service names in docker-compose)
- Example webhook URL in docker-compose: `http://webhook-test:8080/webhook`

## Systemd Service (Linux)

To run smtp2webhook as a systemd service:

1. **Create a dedicated user:**
   ```bash
   sudo useradd -r -s /bin/false smtp2webhook
   ```

2. **Install the binary:**
   ```bash
   sudo cp target/release/smtp2webhook /opt/smtp2webhook/
   sudo cp config.toml /opt/smtp2webhook/
   sudo chown -R smtp2webhook:smtp2webhook /opt/smtp2webhook
   ```

3. **Install the service file:**
   ```bash
   sudo cp smtp2webhook.service /etc/systemd/system/
   sudo systemctl daemon-reload
   ```

4. **Start and enable the service:**
   ```bash
   sudo systemctl start smtp2webhook
   sudo systemctl enable smtp2webhook
   ```

5. **Check the status:**
   ```bash
   sudo systemctl status smtp2webhook
   sudo journalctl -u smtp2webhook -f
   ```

## Webhook Payload

Emails are sent to the webhook as JSON POST requests with the following structure:

```json
{
  "from": "sender@example.com",
  "to": ["recipient@example.com"],
  "subject": "Email Subject",
  "headers": {
    "From": "sender@example.com",
    "To": "recipient@example.com",
    "Subject": "Email Subject",
    "Date": "Mon, 1 Jan 2024 12:00:00 +0000"
  },
  "body": "Email body content",
  "raw": "Raw email data including headers and body"
}
```

## Testing

The repository includes test scripts to help you verify the setup:

### Using the Test Scripts

1. **Start the test webhook server** (in one terminal):
   ```bash
   python3 test_webhook.py
   ```

2. **Start smtp2webhook** (in another terminal):
   ```bash
   cargo run
   ```

3. **Send a test email** (in a third terminal):
   ```bash
   ./test_send_email.sh
   ```

The test webhook server will print the received email in a formatted way.

### Manual Testing

You can also test the SMTP server using tools like `telnet`, `swaks`, or any email client:

### Using swaks

```bash
swaks --to test@example.com \
      --from sender@example.com \
      --server localhost:2525 \
      --body "Test message"
```

### Using telnet

```bash
telnet localhost 2525
HELO localhost
MAIL FROM:<test@example.com>
RCPT TO:<recipient@example.com>
DATA
Subject: Test Email

This is a test message.
.
QUIT
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