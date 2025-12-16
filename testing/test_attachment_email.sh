#!/bin/bash
# Test script to send an email with attachments to the SMTP server

SMTP_HOST="localhost"
SMTP_PORT="2525"

echo "Sending email with attachments to ${SMTP_HOST}:${SMTP_PORT}..."
echo ""

BOUNDARY="----=_Part_Boundary_001"

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
  echo "Subject: Email with Attachments Test"
  echo "Date: $(date -R)"
  echo "MIME-Version: 1.0"
  echo "Content-Type: multipart/mixed; boundary=\"${BOUNDARY}\""
  echo ""
  echo "This is a multi-part message in MIME format."
  echo ""
  echo "--${BOUNDARY}"
  echo "Content-Type: text/plain; charset=utf-8"
  echo "Content-Transfer-Encoding: 7bit"
  echo ""
  echo "This email contains multiple attachments."
  echo ""
  echo "Attachments:"
  echo "1. report.pdf - Monthly sales report"
  echo "2. data.csv - Customer data export"
  echo "3. screenshot.png - Dashboard screenshot"
  echo ""
  echo "Please review the attached files."
  echo ""
  echo "--${BOUNDARY}"
  echo "Content-Type: application/pdf"
  echo "Content-Transfer-Encoding: base64"
  echo "Content-Disposition: attachment; filename=\"report.pdf\""
  echo ""
  echo "JVBERi0xLjQKJeLjz9MKMyAwIG9iago8PC9UeXBlL1BhZ2UvUGFyZW50IDIgMCBSL1Jlc291cmNl"
  echo "czw8L0ZvbnQ8PC9GMSA0IDAgUj4+Pj4vTWVkaWFCb3hbMCAwIDYxMiA3OTJdL0NvbnRlbnRzIDUg"
  echo "MCBSPj4KZW5kb2JqCg=="
  echo ""
  echo "--${BOUNDARY}"
  echo "Content-Type: text/csv"
  echo "Content-Transfer-Encoding: 7bit"
  echo "Content-Disposition: attachment; filename=\"data.csv\""
  echo ""
  echo "Name,Email,Status"
  echo "John Doe,john@example.com,Active"
  echo "Jane Smith,jane@example.com,Active"
  echo ""
  echo "--${BOUNDARY}"
  echo "Content-Type: image/png"
  echo "Content-Transfer-Encoding: base64"
  echo "Content-Disposition: attachment; filename=\"screenshot.png\""
  echo ""
  echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9"
  echo "awAAAABJRU5ErkJggg=="
  echo ""
  echo "--${BOUNDARY}--"
  echo "."
  sleep 0.5
  echo "QUIT"
  sleep 0.5
) | nc $SMTP_HOST $SMTP_PORT

echo ""
echo "Email with attachments sent!"
echo ""
echo "Expected webhook payload should include:"
echo "  attachments: [\"report.pdf\", \"data.csv\", \"screenshot.png\"]"
