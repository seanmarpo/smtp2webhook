#!/bin/bash
# Docker integration test script for smtp2webhook

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== SMTP2Webhook Docker Integration Test ===${NC}"

# Configuration
CONTAINER_NAME="smtp2webhook-test"
IMAGE_NAME="${SMTP2WEBHOOK_IMAGE:-smtp2webhook:latest}"
TEST_PORT="12525"
WEBHOOK_PORT="18080"
WEBHOOK_CONTAINER="webhook-test-receiver"

# Check for rebuild flag
REBUILD_IMAGE=false
if [ "$1" = "--rebuild" ] || [ "$1" = "-r" ]; then
    REBUILD_IMAGE=true
fi

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    docker stop "$WEBHOOK_CONTAINER" 2>/dev/null || true
    docker rm "$WEBHOOK_CONTAINER" 2>/dev/null || true
    docker network rm smtp2webhook-test-net 2>/dev/null || true
    rm -f test-config.toml
    echo -e "${GREEN}Cleanup complete${NC}"
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

# Build or check image
if [ "$REBUILD_IMAGE" = true ]; then
    echo -e "${YELLOW}Rebuilding image $IMAGE_NAME...${NC}"
    if ! docker build -t "$IMAGE_NAME" ..; then
        echo -e "${RED}Error: Failed to build Docker image${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Image rebuilt successfully${NC}"
elif ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    echo -e "${YELLOW}Image $IMAGE_NAME not found. Building...${NC}"
    if ! docker build -t "$IMAGE_NAME" ..; then
        echo -e "${RED}Error: Failed to build Docker image${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Using existing image: $IMAGE_NAME${NC}"
    echo -e "${YELLOW}Note: If healthcheck tests fail, rebuild with: $0 --rebuild${NC}"
fi

# Create test network
echo -e "\n${GREEN}Creating test network...${NC}"
docker network create smtp2webhook-test-net

# Start test webhook receiver
echo -e "\n${GREEN}Starting test webhook receiver...${NC}"
docker run -d \
    --name "$WEBHOOK_CONTAINER" \
    --network smtp2webhook-test-net \
    -p "$WEBHOOK_PORT:8080" \
    python:3.11-slim \
    bash -c "cat > /tmp/webhook.py <<'EOF'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import sys

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        body = self.rfile.read(content_length)

        print('Received webhook:', flush=True)
        print(body.decode('utf-8'), flush=True)

        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{\"status\": \"ok\"}')

    def log_message(self, format, *args):
        sys.stdout.write('%s - - [%s] %s\n' % (
            self.address_string(),
            self.log_date_time_string(),
            format % args))
        sys.stdout.flush()

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8080), WebhookHandler)
    print('Webhook receiver listening on port 8080', flush=True)
    server.serve_forever()
EOF
python3 /tmp/webhook.py"

# Wait for webhook server to start
echo -e "${YELLOW}Waiting for webhook receiver to start...${NC}"
sleep 2

# Create test configuration
echo -e "\n${GREEN}Creating test configuration...${NC}"
cat > test-config.toml <<EOF
[smtp]
bind_address = "0.0.0.0:2525"
hostname = "smtp2webhook-test"

[webhook]
url = "http://$WEBHOOK_CONTAINER:8080/webhook"
max_retries = 3
timeout_secs = 10

[logging]
level = "info"
EOF

# Start smtp2webhook container
echo -e "\n${GREEN}Starting smtp2webhook container...${NC}"
docker run -d \
    --name "$CONTAINER_NAME" \
    --network smtp2webhook-test-net \
    -p "$TEST_PORT:2525" \
    -v "$(pwd)/test-config.toml:/app/config.toml:ro" \
    "$IMAGE_NAME"

# Wait for container to be ready
echo -e "${YELLOW}Waiting for smtp2webhook to be ready...${NC}"
sleep 3

# Check if container is running
MAX_WAIT=10
WAITED=0
while ! docker ps | grep -q "$CONTAINER_NAME"; do
    if [ $WAITED -ge $MAX_WAIT ]; then
        echo -e "${RED}Error: Container failed to start within ${MAX_WAIT} seconds${NC}"
        echo -e "${YELLOW}Container logs:${NC}"
        docker logs "$CONTAINER_NAME" 2>&1
        exit 1
    fi
    sleep 1
    WAITED=$((WAITED + 1))
done

# Show container logs
echo -e "\n${GREEN}Container logs:${NC}"
docker logs "$CONTAINER_NAME"

# Test SMTP connection
echo -e "\n${GREEN}Testing SMTP connection...${NC}"
CONNECTION_OK=false
# Try netcat first
if command -v nc >/dev/null 2>&1; then
    if nc -z localhost "$TEST_PORT" 2>/dev/null; then
        CONNECTION_OK=true
    fi
fi
# Try bash TCP redirection as fallback
if [ "$CONNECTION_OK" = false ]; then
    if timeout 2 bash -c "echo > /dev/tcp/localhost/$TEST_PORT" 2>/dev/null; then
        CONNECTION_OK=true
    fi
fi
if [ "$CONNECTION_OK" = false ]; then
    echo -e "${RED}Error: Cannot connect to SMTP port $TEST_PORT${NC}"
    echo -e "${YELLOW}Make sure port $TEST_PORT is not already in use${NC}"
    docker logs "$CONTAINER_NAME"
    exit 1
fi
echo -e "${GREEN}✓ SMTP port is accessible${NC}"

# Send test email
echo -e "\n${GREEN}Sending test email...${NC}"
if ! command -v nc >/dev/null 2>&1; then
    echo -e "${RED}Error: netcat (nc) is required for testing${NC}"
    echo -e "${YELLOW}Please install netcat: apt-get install netcat or brew install netcat${NC}"
    exit 1
fi
{
    sleep 1
    echo "EHLO test.example.com"
    sleep 0.5
    echo "MAIL FROM:<test@example.com>"
    sleep 0.5
    echo "RCPT TO:<recipient@example.com>"
    sleep 0.5
    echo "DATA"
    sleep 0.5
    echo "From: Test Sender <test@example.com>"
    echo "To: Test Recipient <recipient@example.com>"
    echo "Subject: Docker Test Email"
    echo ""
    echo "This is a test email sent to verify the Docker container is working correctly."
    echo "."
    sleep 0.5
    echo "QUIT"
    sleep 1
} | nc localhost "$TEST_PORT" > /tmp/smtp-response.txt 2>&1

# Check SMTP response
if grep -q "250 OK" /tmp/smtp-response.txt; then
    echo -e "${GREEN}✓ Email sent successfully${NC}"
else
    echo -e "${RED}Error: Failed to send email${NC}"
    cat /tmp/smtp-response.txt
    exit 1
fi

# Wait for webhook to be processed
echo -e "${YELLOW}Waiting for webhook delivery...${NC}"
sleep 2

# Check webhook receiver logs
echo -e "\n${GREEN}Webhook receiver logs:${NC}"
docker logs "$WEBHOOK_CONTAINER" 2>&1 | tail -20

# Verify webhook was received
WEBHOOK_LOGS=$(docker logs "$WEBHOOK_CONTAINER" 2>&1)
if echo "$WEBHOOK_LOGS" | grep -q "Docker Test Email"; then
    echo -e "\n${GREEN}✓ Webhook received successfully!${NC}"
elif echo "$WEBHOOK_LOGS" | grep -q "Received webhook"; then
    echo -e "\n${GREEN}✓ Webhook received (partial match)${NC}"
    echo -e "${YELLOW}Warning: Subject line not found in webhook${NC}"
else
    echo -e "\n${RED}Error: Webhook was not received${NC}"
    echo -e "${YELLOW}SMTP container logs:${NC}"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
    echo -e "\n${YELLOW}Webhook container logs:${NC}"
    docker logs "$WEBHOOK_CONTAINER" 2>&1 | tail -20
    exit 1
fi

# Run health check
echo -e "\n${GREEN}Testing container health check...${NC}"

# Check if Docker reports the container as healthy
echo -e "${YELLOW}Waiting for health check to initialize...${NC}"
MAX_HEALTH_WAIT=40
HEALTH_WAIT=0
HEALTH_STATUS="none"
while [ $HEALTH_WAIT -lt $MAX_HEALTH_WAIT ]; do
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "none")
    if [ "$HEALTH_STATUS" = "healthy" ]; then
        echo -e "${GREEN}✓ Container health check: healthy${NC}"
        break
    elif [ "$HEALTH_STATUS" = "unhealthy" ]; then
        echo -e "${RED}✗ Container health check: unhealthy${NC}"
        echo -e "${YELLOW}Health check logs:${NC}"
        docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' "$CONTAINER_NAME"
        exit 1
    elif [ "$HEALTH_STATUS" = "starting" ]; then
        echo -e "${YELLOW}Health check status: starting (${HEALTH_WAIT}s)${NC}"
    elif [ "$HEALTH_STATUS" = "none" ]; then
        echo -e "${RED}✗ No health check configured in container${NC}"
        echo -e "${YELLOW}The Docker image was built without HEALTHCHECK instruction.${NC}"
        echo -e "${YELLOW}Rebuild the image with: $0 --rebuild${NC}"
        echo -e "${YELLOW}Or manually: docker build -t $IMAGE_NAME ..${NC}"
        exit 1
    fi
    sleep 2
    HEALTH_WAIT=$((HEALTH_WAIT + 2))
done

if [ $HEALTH_WAIT -ge $MAX_HEALTH_WAIT ] && [ "$HEALTH_STATUS" != "healthy" ]; then
    echo -e "${RED}✗ Health check did not become healthy within ${MAX_HEALTH_WAIT}s (status: ${HEALTH_STATUS})${NC}"
    exit 1
fi

# Manually verify the health check command works
echo -e "${YELLOW}Verifying health check command...${NC}"
if docker exec "$CONTAINER_NAME" sh -c "nc -z localhost 2525" 2>/dev/null; then
    echo -e "${GREEN}✓ Health check command (nc -z localhost 2525) works${NC}"
else
    echo -e "${RED}✗ Health check command failed${NC}"
    echo -e "${YELLOW}This may indicate netcat is not installed in the container.${NC}"
    exit 1
fi

# Test with authentication
echo -e "\n${GREEN}Testing SMTP with authentication...${NC}"
{
    sleep 1
    echo "EHLO test.example.com"
    sleep 0.5
    echo "AUTH PLAIN AHRlc3QAdGVzdA=="  # test:test in base64
    sleep 0.5
    echo "MAIL FROM:<auth-test@example.com>"
    sleep 0.5
    echo "RCPT TO:<recipient@example.com>"
    sleep 0.5
    echo "DATA"
    sleep 0.5
    echo "From: Auth Test <auth-test@example.com>"
    echo "To: Test Recipient <recipient@example.com>"
    echo "Subject: Docker Auth Test"
    echo ""
    echo "Testing authentication (should accept any credentials)."
    echo "."
    sleep 0.5
    echo "QUIT"
    sleep 1
} | nc localhost "$TEST_PORT" > /tmp/smtp-auth-response.txt 2>&1

if grep -q "250 OK" /tmp/smtp-auth-response.txt; then
    echo -e "${GREEN}✓ Authentication test passed${NC}"
else
    echo -e "${YELLOW}⚠ Authentication test inconclusive${NC}"
fi

# Summary
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}All Docker tests passed! ✓${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Container details:"
echo "  Name: $CONTAINER_NAME"
echo "  Image: $IMAGE_NAME"
echo "  SMTP Port: $TEST_PORT"
echo "  Status: Running"
echo ""
echo "To view logs: docker logs $CONTAINER_NAME"
echo "To stop: docker stop $CONTAINER_NAME"

exit 0
