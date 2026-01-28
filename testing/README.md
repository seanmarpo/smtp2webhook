# SMTP2Webhook Testing

This directory contains test scripts for smtp2webhook functionality.

## Test Scripts

### Email Content Tests
- `test_send_email.sh` - Plain text email
- `test_html_email.sh` - HTML formatted email
- `test_multipart_email.sh` - Multipart (text + HTML) email
- `test_base64_email.sh` - Base64 encoded content
- `test_quoted_printable_email.sh` - Quoted-printable encoding
- `test_attachment_email.sh` - Email with file attachments

### Docker Tests
- `test_docker_simple.sh` - Basic Docker smoke test (container starts and runs)
- `test_docker.sh` - Full Docker integration test (includes SMTP, webhook, and healthcheck)
- `test_healthcheck.sh` - Dedicated healthcheck functionality test

### Utilities
- `run_all_tests.sh` - Master test runner
- `test_webhook.py` - Test webhook receiver server
- `validate_tests.sh` - Validation script

## Running Tests

### Email Content Tests
```bash
# Start the webhook receiver
./testing/test_webhook.py

# In another terminal, start smtp2webhook
cargo run config.toml

# In a third terminal, run tests
./testing/run_all_tests.sh
```

### Docker Tests
```bash
# Run all Docker tests including healthcheck
./testing/run_all_tests.sh --with-docker

# Rebuild image and run Docker tests (recommended after Dockerfile changes)
./testing/run_all_tests.sh --rebuild

# Or run individual tests
./testing/test_healthcheck.sh
./testing/test_docker_simple.sh
./testing/test_docker.sh

# Rebuild image for individual tests
./testing/test_healthcheck.sh --rebuild
./testing/test_docker.sh --rebuild
```

## Healthcheck Tests

The `test_healthcheck.sh` script verifies:
1. ✓ Container health check is configured
2. ✓ Health status transitions from `starting` → `healthy`
3. ✓ Health check command (`nc -z localhost 2525`) executes correctly
4. ✓ netcat dependency is installed in the container
5. ✓ Health check works during SMTP activity
6. ✓ Health check detects unhealthy state

### Healthcheck Configuration
- **Command**: `nc -z localhost 2525`
- **Interval**: 30 seconds
- **Timeout**: 3 seconds
- **Start period**: 5 seconds
- **Retries**: 3 attempts before marking unhealthy

The healthcheck verifies the SMTP server is accepting connections on port 2525.

## Troubleshooting

### Health check status shows "none"
This means the Docker image was built before the HEALTHCHECK instruction was added to the Dockerfile.

**Solution**: Rebuild the image:
```bash
./testing/run_all_tests.sh --rebuild
# or
docker build -t smtp2webhook:latest .
```

### Tests show success but actually failed
Fixed in latest version - tests now properly check exit codes and fail when healthcheck tests fail.

### Health check command fails inside container
Verify netcat is installed:
```bash
docker exec <container> which nc
```

If missing, the Dockerfile needs to include `netcat-openbsd` in the `apk add` command.

## Requirements

- Docker (for Docker tests)
- netcat (`nc`)
- Python 3 (for webhook receiver)
- Rust toolchain (for non-Docker tests)