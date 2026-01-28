#!/bin/bash
# Master test script to run all email test scenarios
# This script tests various email content types and encodings

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse command line arguments
RUN_DOCKER_TESTS=false
REBUILD_IMAGE=false

for arg in "$@"; do
    case $arg in
        --with-docker|-d)
            RUN_DOCKER_TESTS=true
            ;;
        --rebuild|-r)
            REBUILD_IMAGE=true
            RUN_DOCKER_TESTS=true
            ;;
    esac
done

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                         SMTP2WEBHOOK TEST SUITE                              ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$RUN_DOCKER_TESTS" = true ]; then
    echo "Running in Docker mode - will test containerized deployment"
    echo ""
    echo "This will run:"
    echo "  1. Docker integration tests"
    echo "  2. Health check tests"
    echo ""
    if [ "$REBUILD_IMAGE" = true ]; then
        echo "Image will be rebuilt before testing."
        echo ""
    fi
else
    echo "This script will send various test emails to test different content types."
    echo "Make sure you have:"
    echo "  1. smtp2webhook server running (cargo run)"
    echo "  2. Test webhook server running (./testing/test_webhook.py)"
    echo ""
    echo "To run Docker tests, use: $0 --with-docker"
    echo "To rebuild image and test, use: $0 --rebuild"
    echo ""
fi

echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Function to run a test and wait
run_test() {
    local test_name=$1
    local test_script=$2

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📧 Test: $test_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ -f "$SCRIPT_DIR/$test_script" ]; then
        bash "$SCRIPT_DIR/$test_script"
        echo "✓ Test sent successfully"
        echo "  Check the webhook server output for results"
        sleep 2
    else
        echo "✗ Test script not found: $test_script"
    fi
}

# Run Docker tests if requested
if [ "$RUN_DOCKER_TESTS" = true ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🐳 Docker Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    TEST_FAILED=false
    TEST_ARGS=""

    if [ "$REBUILD_IMAGE" = true ]; then
        TEST_ARGS="--rebuild"
    fi

    if [ -f "$SCRIPT_DIR/test_healthcheck.sh" ]; then
        if ! bash "$SCRIPT_DIR/test_healthcheck.sh" $TEST_ARGS; then
            echo "✗ Health check test failed"
            TEST_FAILED=true
        fi
        echo ""
    fi

    if [ -f "$SCRIPT_DIR/test_docker.sh" ]; then
        if ! bash "$SCRIPT_DIR/test_docker.sh" $TEST_ARGS; then
            echo "✗ Docker integration test failed"
            TEST_FAILED=true
        fi
        echo ""
    fi

    if [ "$TEST_FAILED" = true ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✗ Docker tests FAILED!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exit 1
    fi
else
    # Run email content tests
    run_test "Plain Text Email" "test_send_email.sh"
    run_test "HTML Email" "test_html_email.sh"
    run_test "Multipart Email (Text + HTML)" "test_multipart_email.sh"
    run_test "Base64 Encoded Email" "test_base64_email.sh"
    run_test "Quoted-Printable Encoded Email" "test_quoted_printable_email.sh"
    run_test "Email with Attachments" "test_attachment_email.sh"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ All tests completed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$RUN_DOCKER_TESTS" = true ]; then
    echo "Docker Test Summary:"
    echo "  ✓ All Docker tests passed successfully"
    echo ""
else
    echo "Test Summary:"
    echo "  1. Plain text email - Simple text content"
    echo "  2. HTML email - HTML formatted content"
    echo "  3. Multipart email - Both text and HTML versions"
    echo "  4. Base64 encoded - Base64 content transfer encoding"
    echo "  5. Quoted-printable - Quoted-printable encoding with special chars"
    echo "  6. Email with attachments - Multiple file attachments"
    echo ""
    echo "Review the webhook server output to verify all emails were processed correctly."
    echo "Each email should show:"
    echo "  - Clean plain text in body field"
    echo "  - Decoded content (not base64 or quoted-printable)"
    echo "  - HTML converted to plain text"
    echo "  - Attachment filenames listed (when present)"
    echo ""
fi
