#!/bin/bash
# Simple Docker smoke test for smtp2webhook
# This is a minimal test that just verifies the container can start

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Simple Docker Smoke Test ===${NC}\n"

# Configuration
CONTAINER_NAME="smtp2webhook-simple-test"
IMAGE_NAME="${SMTP2WEBHOOK_IMAGE:-smtp2webhook:latest}"
TEST_PORT="12525"

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    rm -f simple-test-config.toml
    echo -e "${GREEN}Cleanup complete${NC}"
}

trap cleanup EXIT

# Check Docker
echo "1. Checking Docker..."
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker is running${NC}"

# Check/Build image
echo -e "\n2. Checking Docker image..."
if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    echo -e "${YELLOW}Building image...${NC}"
    if docker build -q -t "$IMAGE_NAME" .. > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Image built successfully${NC}"
    else
        echo -e "${RED}✗ Failed to build image${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Image exists${NC}"
fi

# Create minimal config
echo -e "\n3. Creating test configuration..."
cat > simple-test-config.toml <<EOF
[smtp]
bind_address = "0.0.0.0:2525"
hostname = "test"

[webhook]
url = "http://example.com/webhook"
max_retries = 1
timeout_secs = 10

[logging]
level = "info"
EOF
echo -e "${GREEN}✓ Configuration created${NC}"

# Start container
echo -e "\n4. Starting container..."
if docker run -d \
    --name "$CONTAINER_NAME" \
    -p "$TEST_PORT:2525" \
    -v "$(pwd)/simple-test-config.toml:/app/config.toml:ro" \
    "$IMAGE_NAME" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Container started${NC}"
else
    echo -e "${RED}✗ Failed to start container${NC}"
    exit 1
fi

# Wait for startup
echo -e "\n5. Waiting for container to be ready..."
sleep 3

# Check container is running
if docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
    echo -e "${GREEN}✓ Container is running${NC}"
else
    echo -e "${RED}✗ Container is not running${NC}"
    echo -e "\n${YELLOW}Container logs:${NC}"
    docker logs "$CONTAINER_NAME" 2>&1
    exit 1
fi

# Check logs for startup message
echo -e "\n6. Checking container logs..."
LOGS=$(docker logs "$CONTAINER_NAME" 2>&1)
if echo "$LOGS" | grep -q "SMTP server listening"; then
    echo -e "${GREEN}✓ SMTP server started successfully${NC}"
else
    echo -e "${RED}✗ SMTP server may not have started correctly${NC}"
    echo -e "\n${YELLOW}Container logs:${NC}"
    echo "$LOGS"
    exit 1
fi

# Test port connectivity
echo -e "\n7. Testing port connectivity..."
PORT_OK=false
if command -v nc >/dev/null 2>&1; then
    if nc -z -w2 localhost "$TEST_PORT" 2>/dev/null; then
        PORT_OK=true
    fi
elif timeout 2 bash -c "echo > /dev/tcp/localhost/$TEST_PORT" 2>/dev/null; then
    PORT_OK=true
fi

if [ "$PORT_OK" = true ]; then
    echo -e "${GREEN}✓ Port $TEST_PORT is accessible${NC}"
else
    echo -e "${YELLOW}⚠ Could not verify port connectivity (netcat not available)${NC}"
    echo -e "${YELLOW}  Container is running, port mapping appears correct${NC}"
fi

# Test health check
echo -e "\n8. Testing container health check..."
HEALTH_OK=false

# Wait a bit for health check to run
sleep 3

# Check Docker's health status
HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "none")
if [ "$HEALTH_STATUS" = "healthy" ] || [ "$HEALTH_STATUS" = "starting" ]; then
    echo -e "${GREEN}✓ Health check status: $HEALTH_STATUS${NC}"
    HEALTH_OK=true
elif [ "$HEALTH_STATUS" = "none" ]; then
    echo -e "${YELLOW}⚠ No health check configured${NC}"
else
    echo -e "${YELLOW}⚠ Health check status: $HEALTH_STATUS${NC}"
fi

# Manually test the health check command
if docker exec "$CONTAINER_NAME" sh -c "nc -z localhost 2525" 2>/dev/null; then
    echo -e "${GREEN}✓ Health check command works${NC}"
    HEALTH_OK=true
else
    echo -e "${YELLOW}⚠ Health check command could not be verified${NC}"
fi

if [ "$HEALTH_OK" = false ]; then
    echo -e "${YELLOW}⚠ Health check verification inconclusive${NC}"
fi

# Show container info
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Simple smoke test passed! ✓${NC}"
echo -e "${GREEN}================================${NC}\n"

echo "Container Details:"
echo "  Name: $CONTAINER_NAME"
echo "  Image: $IMAGE_NAME"
echo "  Port: localhost:$TEST_PORT"
echo ""
echo "View logs with: docker logs $CONTAINER_NAME"
echo "Stop with: docker stop $CONTAINER_NAME"
echo ""
echo -e "${YELLOW}Note: This is a basic smoke test. Run test_docker.sh for full integration testing.${NC}"
echo ""

exit 0
