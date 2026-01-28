# SMTP2Webhook

A lightweight Rust application that runs an SMTP server and forwards incoming emails to a configurable HTTP webhook.

Bridges the gap for software that only supports email notifications (monitoring tools, alerting systems) to modern webhook-based services like Discord, Slack, or any HTTP endpoint.

## Features

- 🚀 Lightweight SMTP server
- 🔗 Forwards emails to HTTP webhooks as JSON
- 🔄 Automatic retry logic with exponential backoff
- ⚙️ Simple TOML configuration
- 🔓 Accepts any SMTP authentication (designed for local/internal use)
- 📝 Structured logging

## Quick Start

### Using Docker (Recommended)

```bash
# Pull image from GitHub Container Registry
docker pull ghcr.io/seanmarpo/smtp2webhook:latest

# Create config file
cp config.toml.example config.toml
# Edit config.toml with your webhook URL

# Run with docker-compose
docker-compose up -d

# Or run directly
docker run -d \
  --name smtp2webhook \
  -p 2525:2525 \
  -v $(pwd)/config.toml:/app/config.toml:ro \
  ghcr.io/seanmarpo/smtp2webhook:latest
```

### Building from Source

**Prerequisites:** Rust 1.80 or higher

```bash
# Build
cargo build --release

# Configure
cp config.toml.example config.toml
# Edit config.toml with your webhook URL

# Run
cargo run --release
```

## Configuration

```toml
[smtp]
bind_address = "127.0.0.1:2525"  # Use "0.0.0.0:2525" for Docker
hostname = "localhost"

[webhook]
url = "http://localhost:8080/webhook"
max_retries = 3
timeout_secs = 30

# Optional: Custom headers for authentication
[webhook.headers]
Authorization = "Bearer your-token-here"
X-API-Key = "your-api-key"

[logging]
level = "info"  # trace, debug, info, warn, error
```

## Webhook Payload

Emails are sent as JSON POST requests:

```json
{
  "from": "sender@example.com",
  "to": ["recipient@example.com"],
  "subject": "Email Subject",
  "body": "Plain text email body content",
  "attachments": ["document.pdf", "image.png"]
}
```

**Content Handling:**
- Plain text emails delivered as-is
- HTML emails automatically converted to plain text
- Multipart emails use plain text version
- Base64 and Quoted-Printable encodings automatically decoded
- Attachment filenames listed (content not included)

## Testing

```bash
# Run Rust tests
cargo test

# Send test email
./testing/test_send_email.sh

# Test webhook receiver (separate terminal)
./testing/test_webhook.py

# Run all integration tests
./testing/run_all_tests.sh
```

## Docker

### Images

Pre-built images are available from GitHub Container Registry:

```bash
# Latest release
docker pull ghcr.io/seanmarpo/smtp2webhook:latest

# Specific version
docker pull ghcr.io/seanmarpo/smtp2webhook:v0.1.0
```

Or build locally:

```bash
docker build -t smtp2webhook .
```

### Configuration Notes

- Default port: 2525
- For Docker networking, use `bind_address = "0.0.0.0:2525"`
- Mount config as read-only: `-v $(pwd)/config.toml:/app/config.toml:ro`
- Use service names in docker-compose: `http://service-name:port/webhook`



## Error Handling

- Failed webhook requests retry up to `max_retries` times with exponential backoff
- After exhausting retries, email is dropped and error logged
- SMTP server responds with success to prevent email bounces

## Security Warning

⚠️ **For local/internal use only!**

- Accepts any SMTP authentication
- No TLS/SSL support
- Do not expose to public internet
- Use Docker networks to isolate containers

## License

See LICENSE file for details.