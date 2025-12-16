#!/bin/bash
# Master test script to run all email test scenarios
# This script tests various email content types and encodings

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                         SMTP2WEBHOOK TEST SUITE                              ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "This script will send various test emails to test different content types."
echo "Make sure you have:"
echo "  1. smtp2webhook server running (cargo run)"
echo "  2. Test webhook server running (./testing/test_webhook.py)"
echo ""
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

# Run all tests
run_test "Plain Text Email" "test_send_email.sh"
run_test "HTML Email" "test_html_email.sh"
run_test "Multipart Email (Text + HTML)" "test_multipart_email.sh"
run_test "Base64 Encoded Email" "test_base64_email.sh"
run_test "Quoted-Printable Encoded Email" "test_quoted_printable_email.sh"
run_test "Email with Attachments" "test_attachment_email.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ All tests completed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
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
