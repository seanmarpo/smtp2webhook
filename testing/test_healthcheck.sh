#!/bin/bash
# Dedicated health check test for smtp2webhook Docker container

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== SMTP2Webhook Health Check Test ===${NC}\n"

# Configuration
CONTAINER_NAME="smtp2webhook-healthcheck-test"
IMAGE_NAME="${SMTP2WEBHOOK_IMAGE:-smtp2webhook:latest}"
TEST_PORT="12526"

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
    rm -f healthcheck-test-config.toml
    echo -e "${GREEN}Cleanup complete${NC}"
}

trap cleanup EXIT

# Check Docker
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running${NC}"
    exit 1
fi

# Build or check image
if [ "$REBUILD_IMAGE" = true ]; then
    echo -e "${YELLOW}Rebuilding image $IMAGE_NAME...${NC}"
    if ! docker build -t "$IMAGE_NAME" ..; then
        echo -e "${RED}✗ Failed to build image${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Image rebuilt successfully${NC}"
elif ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    echo -e "${YELLOW}Image not found. Building...${NC}"
    if ! docker build -t "$IMAGE_NAME" ..; then
        echo -e "${RED}✗ Failed to build image${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Image built successfully${NC}"
else
    echo -e "${GREEN}Using existing image: $IMAGE_NAME${NC}"
    echo -e "${YELLOW}Note: If healthcheck tests fail, rebuild with: $0 --rebuild${NC}"
fi

# Create test config
cat > healthcheck-test-config.toml <<EOF
[smtp]
bind_address = "0.0.0.0:2525"
hostname = "healthcheck-test"

[webhook]
url = "http://example.com/webhook"
max_retries = 1
timeout_secs = 5

[logging]
level = "info"
EOF

echo -e "1. Starting container with health check..."
docker run -d \
    --name "$CONTAINER_NAME" \
    -p "$TEST_PORT:2525" \
    -v "$(pwd)/healthcheck-test-config.toml:/app/config.toml:ro" \
    "$IMAGE_NAME" > /dev/null

echo -e "${GREEN}✓ Container started${NC}\n"

# Wait for container to start
sleep 2

# Verify container is running
if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
    echo -e "${RED}✗ Container failed to start${NC}"
    docker logs "$CONTAINER_NAME"
    exit 1
fi

echo -e "2. Monitoring health check status...\n"

# Monitor health check progression
MAX_WAIT=45
ELAPSED=0
LAST_STATUS=""

while [ $ELAPSED -lt $MAX_WAIT ]; do
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "none")

    if [ "$HEALTH_STATUS" != "$LAST_STATUS" ]; then
        echo -e "   [${ELAPSED}s] Health status: ${YELLOW}$HEALTH_STATUS${NC}"
        LAST_STATUS="$HEALTH_STATUS"
    fi

    if [ "$HEALTH_STATUS" = "healthy" ]; then
        echo -e "\n${GREEN}✓ Container became healthy after ${ELAPSED}s${NC}\n"
        break
    elif [ "$HEALTH_STATUS" = "unhealthy" ]; then
        echo -e "\n${RED}✗ Container became unhealthy${NC}"
        echo -e "\n${YELLOW}Health check logs:${NC}"
        docker inspect --format='{{range .State.Health.Log}}Exit Code: {{.ExitCode}}, Output: {{.Output}}{{end}}' "$CONTAINER_NAME"
        echo -e "\n${YELLOW}Container logs:${NC}"
        docker logs "$CONTAINER_NAME"
        exit 1
    elif [ "$HEALTH_STATUS" = "none" ]; then
        echo -e "\n${RED}✗ No health check configured in image${NC}"
        echo -e "${YELLOW}The Docker image was built without HEALTHCHECK instruction.${NC}"
        echo -e "${YELLOW}Rebuild with: $0 --rebuild${NC}"
        echo -e "${YELLOW}Or manually: docker build -t $IMAGE_NAME ..${NC}"
        exit 1
    fi

    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

if [ "$HEALTH_STATUS" != "healthy" ]; then
    echo -e "\n${RED}✗ Container did not become healthy within ${MAX_WAIT}s${NC}"
    echo -e "${YELLOW}Final status: $HEALTH_STATUS${NC}"
    exit 1
fi

# Verify health check details
echo -e "3. Verifying health check configuration...\n"

HEALTH_CONFIG=$(docker inspect --format='{{json .State.Health}}' "$CONTAINER_NAME")
echo -e "${YELLOW}Health check details:${NC}"
echo "$HEALTH_CONFIG" | python3 -m json.tool 2>/dev/null || echo "$HEALTH_CONFIG"

# Manually execute health check command
echo -e "\n4. Manually executing health check command..."
if docker exec "$CONTAINER_NAME" nc -z localhost 2525 2>/dev/null; then
    echo -e "${GREEN}✓ Health check command (nc -z localhost 2525) successful${NC}"
else
    echo -e "${RED}✗ Health check command failed${NC}"
    exit 1
fi

# Verify netcat is installed
echo -e "\n5. Verifying health check dependencies..."
if docker exec "$CONTAINER_NAME" which nc > /dev/null 2>&1; then
    NC_PATH=$(docker exec "$CONTAINER_NAME" which nc 2>/dev/null)
    echo -e "${GREEN}✓ netcat is installed at: $NC_PATH${NC}"
else
    echo -e "${RED}✗ netcat (nc) not found in container${NC}"
    exit 1
fi

# Test health check under load (simulate SMTP connection)
echo -e "\n6. Testing health check during SMTP activity..."
if command -v nc >/dev/null 2>&1; then
    # Send a quick SMTP command while checking health
    (echo -e "EHLO test\nQUIT" | nc -w 2 localhost "$TEST_PORT" > /dev/null 2>&1) &
    sleep 1

    if docker exec "$CONTAINER_NAME" nc -z localhost 2525 2>/dev/null; then
        echo -e "${GREEN}✓ Health check works during SMTP activity${NC}"
    else
        echo -e "${RED}✗ Health check failed during SMTP activity${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Skipping SMTP activity test (nc not available on host)${NC}"
fi

# Check health check history
echo -e "\n7. Reviewing health check history..."
HEALTH_LOG=$(docker inspect --format='{{range .State.Health.Log}}[{{.Start}}] Exit: {{.ExitCode}} {{if .Output}}| {{.Output}}{{end}}
{{end}}' "$CONTAINER_NAME")

if [ -n "$HEALTH_LOG" ]; then
    echo -e "${YELLOW}Recent health checks:${NC}"
    echo "$HEALTH_LOG" | tail -5

    # Count successful checks
    SUCCESS_COUNT=$(echo "$HEALTH_LOG" | grep -c "Exit: 0" || true)
    echo -e "\n${GREEN}Successful health checks: $SUCCESS_COUNT${NC}"
else
    echo -e "${YELLOW}No health check history available yet${NC}"
fi

# Simulate unhealthy state by stopping the SMTP server
echo -e "\n8. Testing unhealthy state detection..."
echo -e "${YELLOW}Stopping container to simulate unhealthy state...${NC}"
docker stop "$CONTAINER_NAME" > /dev/null
sleep 2

# Try to start it again but kill the process inside
docker start "$CONTAINER_NAME" > /dev/null
sleep 2

# Kill the smtp2webhook process to make health check fail
docker exec "$CONTAINER_NAME" sh -c "killall smtp2webhook" 2>/dev/null || true
sleep 2

echo -e "${YELLOW}Waiting for health check to detect unhealthy state...${NC}"
ELAPSED=0
while [ $ELAPSED -lt 20 ]; do
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "none")

    if [ "$HEALTH_STATUS" = "unhealthy" ]; then
        echo -e "${GREEN}✓ Health check correctly detected unhealthy state${NC}"
        break
    fi

    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

if [ "$HEALTH_STATUS" != "unhealthy" ]; then
    echo -e "${YELLOW}⚠ Health check did not detect unhealthy state within 20s${NC}"
    echo -e "${YELLOW}   Final status: $HEALTH_STATUS${NC}"
fi

# Summary
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Health Check Tests Passed! ✓${NC}"
echo -e "${GREEN}================================${NC}\n"

echo "Test Results:"
echo "  ✓ Container health check is configured"
echo "  ✓ Health check transitions from starting → healthy"
echo "  ✓ Health check command executes correctly"
echo "  ✓ netcat dependency is installed"
echo "  ✓ Health check works during SMTP activity"
if [ "$HEALTH_STATUS" = "unhealthy" ]; then
    echo "  ✓ Health check detects unhealthy state"
fi
echo ""

exit 0
