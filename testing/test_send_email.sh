#!/bin/bash
# Test script to send an email to the SMTP server

SMTP_HOST="localhost"
SMTP_PORT="2525"

echo "Sending test email to ${SMTP_HOST}:${SMTP_PORT}..."
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
  echo "Subject: Test Email from smtp2webhook"
  echo "Date: $(date -R)"
  echo ""
  echo "This is a test email body."
  echo "It has multiple lines."
  echo ""
  echo "Sent via smtp2webhook test script."
  echo "."
  sleep 0.5
  echo "QUIT"
  sleep 0.5
) | nc $SMTP_HOST $SMTP_PORT

echo ""
echo "Email sent!"
