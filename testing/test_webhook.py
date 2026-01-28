#!/usr/bin/env python3
"""
Simple webhook server for testing smtp2webhook
Listens on port 8080 and prints received emails
"""

import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers["Content-Length"])
        body = self.rfile.read(content_length)

        try:
            data = json.loads(body)
            print("\n" + "=" * 80)
            print("📧 RECEIVED EMAIL")
            print("=" * 80)

            # Display HTTP headers sent by smtp2webhook
            print("\n🔧 HTTP Request Headers:")
            interesting_headers = [
                "Authorization",
                "X-API-Key",
                "X-Custom-Header",
                "User-Agent",
                "X-Source",
                "X-Environment",
                "X-Request-ID",
                "X-Tenant-ID",
                "X-Priority",
            ]
            for header in interesting_headers:
                if header in self.headers:
                    value = self.headers[header]
                    # Mask sensitive values
                    if header in ["Authorization", "X-API-Key"]:
                        if len(value) > 20:
                            value = value[:10] + "..." + value[-10:]
                    print(f"  {header}: {value}")

            print("\n📧 Email Content:")
            print(f"From: {data.get('from', 'N/A')}")
            print(f"To: {', '.join(data.get('to', []))}")
            print(f"Subject: {data.get('subject', 'N/A')}")

            # Display attachments if any
            attachments = data.get("attachments", [])
            if attachments:
                print(f"\n📎 Attachments ({len(attachments)}):")
                for i, filename in enumerate(attachments, 1):
                    print(f"  {i}. {filename}")

            # Display body
            body = data.get("body", "")
            if body:
                print(f"\n📝 Body ({len(body)} chars):")
                print(body)
            else:
                print("\n📝 Body: (empty)")

            print("=" * 80 + "\n")

            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status": "ok"}')
        except Exception as e:
            print(f"Error processing request: {e}", file=sys.stderr)
            self.send_response(500)
            self.end_headers()

    def log_message(self, format, *args):
        # Suppress default logging
        pass


if __name__ == "__main__":
    port = 8080
    server = HTTPServer(("0.0.0.0", port), WebhookHandler)
    print(f"🎯 Webhook server listening on http://localhost:{port}")
    print("Waiting for emails...\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n\nShutting down webhook server...")
        server.shutdown()
