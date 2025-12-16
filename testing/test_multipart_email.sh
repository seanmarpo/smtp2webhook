#!/bin/bash
# Test script to send a multipart email (text + HTML) to the SMTP server

SMTP_HOST="localhost"
SMTP_PORT="2525"

echo "Sending multipart test email to ${SMTP_HOST}:${SMTP_PORT}..."
echo ""

BOUNDARY="----=_Part_123456789_987654321.1234567890"

(
  sleep 0.5
  echo "HELO test.local"
  sleep 0.5
  echo "MAIL FROM:<sender@example.com>"
  sleep 0.5
  echo "RCPT TO:<recipient@example.com>"
  sleep 0.5
  echo "DATA"
  sleep 0.5
  echo "From: sender@example.com"
  echo "To: recipient@example.com"
  echo "Subject: Multipart Email Test (Text + HTML)"
  echo "Date: $(date -R)"
  echo "MIME-Version: 1.0"
  echo "Content-Type: multipart/alternative; boundary=\"${BOUNDARY}\""
  echo ""
  echo "This is a multi-part message in MIME format."
  echo ""
  echo "--${BOUNDARY}"
  echo "Content-Type: text/plain; charset=utf-8"
  echo "Content-Transfer-Encoding: 7bit"
  echo ""
  echo "This is the PLAIN TEXT version of the email."
  echo ""
  echo "It contains:"
  echo "- Simple text formatting"
  echo "- Multiple lines"
  echo "- No HTML tags"
  echo ""
  echo "This is what users with text-only email clients will see."
  echo ""
  echo "--${BOUNDARY}"
  echo "Content-Type: text/html; charset=utf-8"
  echo "Content-Transfer-Encoding: 7bit"
  echo ""
  echo "<!DOCTYPE html>"
  echo "<html>"
  echo "<head>"
  echo "  <meta charset=\"utf-8\">"
  echo "  <title>Multipart Email Test</title>"
  echo "</head>"
  echo "<body style=\"font-family: Arial, sans-serif;\">"
  echo "  <h1 style=\"color: #333;\">This is the HTML version</h1>"
  echo "  <p>This email contains <strong>both plain text and HTML</strong> versions.</p>"
  echo "  <p>It contains:</p>"
  echo "  <ul>"
  echo "    <li><em>Rich formatting</em></li>"
  echo "    <li><strong>Bold and italic text</strong></li>"
  echo "    <li><span style=\"color: red;\">Colored text</span></li>"
  echo "  </ul>"
  echo "  <p>This is what users with HTML-capable email clients will see.</p>"
  echo "  <hr>"
  echo "  <p style=\"font-size: 12px; color: #666;\">Sent via smtp2webhook multipart test</p>"
  echo "</body>"
  echo "</html>"
  echo ""
  echo "--${BOUNDARY}--"
  echo "."
  sleep 0.5
  echo "QUIT"
  sleep 0.5
) | nc $SMTP_HOST $SMTP_PORT

echo ""
echo "Multipart email sent!"
