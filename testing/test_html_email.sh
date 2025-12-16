#!/bin/bash
# Test script to send an HTML email to the SMTP server

SMTP_HOST="localhost"
SMTP_PORT="2525"

echo "Sending HTML test email to ${SMTP_HOST}:${SMTP_PORT}..."
echo ""

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
  echo "Subject: HTML Test Email"
  echo "Date: $(date -R)"
  echo "Content-Type: text/html; charset=utf-8"
  echo "MIME-Version: 1.0"
  echo ""
  echo "<!DOCTYPE html>"
  echo "<html>"
  echo "<head>"
  echo "  <title>Test Email</title>"
  echo "</head>"
  echo "<body>"
  echo "  <h1>HTML Email Test</h1>"
  echo "  <p>This is a <strong>test email</strong> with <em>HTML formatting</em>.</p>"
  echo "  <ul>"
  echo "    <li>Item 1</li>"
  echo "    <li>Item 2</li>"
  echo "    <li>Item 3</li>"
  echo "  </ul>"
  echo "  <p style=\"color: blue;\">This text should be blue.</p>"
  echo "  <a href=\"https://example.com\">Click here</a>"
  echo "</body>"
  echo "</html>"
  echo "."
  sleep 0.5
  echo "QUIT"
  sleep 0.5
) | nc $SMTP_HOST $SMTP_PORT

echo ""
echo "HTML email sent!"
