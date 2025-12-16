#!/bin/bash
# Test script to send a quoted-printable encoded email to the SMTP server

SMTP_HOST="localhost"
SMTP_PORT="2525"

echo "Sending quoted-printable encoded test email to ${SMTP_HOST}:${SMTP_PORT}..."
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
  echo "Subject: Quoted-Printable Encoded Email Test"
  echo "Date: $(date -R)"
  echo "Content-Type: text/plain; charset=utf-8"
  echo "Content-Transfer-Encoding: quoted-printable"
  echo "MIME-Version: 1.0"
  echo ""
  # Quoted-printable encoded text with special characters and long lines
  echo "This is a quoted-printable encoded email message."
  echo ""
  echo "Special characters should be decoded correctly:"
  echo "- Caf=C3=A9 (café)"
  echo "- Na=C3=AFve (naïve)"
  echo "- R=C3=A9sum=C3=A9 (résumé)"
  echo "- =E2=98=95 Coffee emoji"
  echo ""
  echo "Long lines are broken with soft line breaks (=3D at end):"
  echo "This is a very long line that needs to be wrapped because it exceeds t=
he maximum line length allowed in quoted-printable encoding format which is=
 76 characters per line."
  echo ""
  echo "Special encoding:"
  echo "- Equals sign: =3D"
  echo "- Tab character:=09(should be a tab)"
  echo "- Spaces at end of line=20"
  echo ""
  echo "End of quoted-printable test message."
  echo "."
  sleep 0.5
  echo "QUIT"
  sleep 0.5
) | nc $SMTP_HOST $SMTP_PORT

echo ""
echo "Quoted-printable encoded email sent!"
