#!/bin/bash
# Test script to send a base64-encoded email to the SMTP server

SMTP_HOST="localhost"
SMTP_PORT="2525"

echo "Sending base64-encoded test email to ${SMTP_HOST}:${SMTP_PORT}..."
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
  echo "Subject: Base64 Encoded Email Test"
  echo "Date: $(date -R)"
  echo "Content-Type: text/plain; charset=utf-8"
  echo "Content-Transfer-Encoding: base64"
  echo "MIME-Version: 1.0"
  echo ""
  # This is base64-encoded text that says:
  # "This is a base64-encoded email message.
  #
  # It should be properly decoded by the email parser.
  #
  # Features tested:
  # - Base64 decoding
  # - Multi-line content
  # - Special characters: café, naïve, résumé
  #
  # End of test message."
  echo "VGhpcyBpcyBhIGJhc2U2NC1lbmNvZGVkIGVtYWlsIG1lc3NhZ2UuCgpJdCBzaG91bGQgYmUgcHJv"
  echo "cGVybHkgZGVjb2RlZCBieSB0aGUgZW1haWwgcGFyc2VyLgoKRmVhdHVyZXMgdGVzdGVkOgotIEJh"
  echo "c2U2NCBkZWNvZGluZwotIE11bHRpLWxpbmUgY29udGVudAotIFNwZWNpYWwgY2hhcmFjdGVyczog"
  echo "Y2Fmw6ksIG5hw691dmUsIHLDqXN1bcOpCgpFbmQgb2YgdGVzdCBtZXNzYWdlLg=="
  echo "."
  sleep 0.5
  echo "QUIT"
  sleep 0.5
) | nc $SMTP_HOST $SMTP_PORT

echo ""
echo "Base64-encoded email sent!"
