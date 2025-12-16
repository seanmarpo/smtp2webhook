#!/bin/bash
# Validation script to check all test files are present and executable

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    SMTP2WEBHOOK TEST SUITE VALIDATION                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Function to check if file exists and is executable
check_test_file() {
    local file=$1
    local description=$2

    if [ ! -f "$SCRIPT_DIR/$file" ]; then
        echo -e "${RED}✗${NC} $file - NOT FOUND"
        ((ERRORS++))
        return 1
    fi

    if [ ! -x "$SCRIPT_DIR/$file" ]; then
        echo -e "${YELLOW}⚠${NC} $file - exists but not executable"
        echo "  Run: chmod +x testing/$file"
        ((WARNINGS++))
        return 1
    fi

    echo -e "${GREEN}✓${NC} $file - OK ($description)"
    return 0
}

# Check required commands
echo "Checking required commands..."
if ! command -v nc &> /dev/null; then
    echo -e "${RED}✗${NC} netcat (nc) not found - required for tests"
    echo "  Install: brew install netcat (macOS) or apt-get install netcat (Linux)"
    ((ERRORS++))
else
    echo -e "${GREEN}✓${NC} netcat (nc) found"
fi

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗${NC} python3 not found - required for webhook server"
    ((ERRORS++))
else
    echo -e "${GREEN}✓${NC} python3 found"
fi

echo ""
echo "Checking test scripts..."

# Check all test files
check_test_file "test_send_email.sh" "Plain text email"
check_test_file "test_html_email.sh" "HTML email"
check_test_file "test_multipart_email.sh" "Multipart email"
check_test_file "test_base64_email.sh" "Base64 encoded email"
check_test_file "test_quoted_printable_email.sh" "Quoted-printable email"
check_test_file "test_attachment_email.sh" "Email with attachments"
check_test_file "run_all_tests.sh" "Master test runner"
check_test_file "test_webhook.py" "Test webhook server"

echo ""
echo "Checking documentation..."

if [ -f "$SCRIPT_DIR/README.md" ]; then
    echo -e "${GREEN}✓${NC} README.md exists"
else
    echo -e "${YELLOW}⚠${NC} README.md not found"
    ((WARNINGS++))
fi

echo ""
echo "Checking Python script syntax..."
if command -v python3 &> /dev/null; then
    if python3 -m py_compile "$SCRIPT_DIR/test_webhook.py" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} test_webhook.py syntax is valid"
    else
        echo -e "${RED}✗${NC} test_webhook.py has syntax errors"
        ((ERRORS++))
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC} Test suite is ready."
    echo ""
    echo "To run tests:"
    echo "  1. Start smtp2webhook:    cargo run"
    echo "  2. Start webhook server:  ./testing/test_webhook.py"
    echo "  3. Run tests:             ./testing/run_all_tests.sh"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS warning(s)${NC} - Tests should work but may need fixes"
    exit 0
else
    echo -e "${RED}✗ $ERRORS error(s), $WARNINGS warning(s)${NC}"
    echo "Please fix the errors before running tests."
    exit 1
fi
