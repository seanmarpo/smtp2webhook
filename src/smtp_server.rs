use crate::email::Email;
use crate::webhook::WebhookClient;
use anyhow::Result;
use log::{error, info, warn};
use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{TcpListener, TcpStream};

pub struct SmtpServer {
    bind_address: String,
    hostname: String,
    webhook_client: Arc<WebhookClient>,
}

impl SmtpServer {
    pub fn new(bind_address: &str, hostname: &str, webhook_client: Arc<WebhookClient>) -> Self {
        Self {
            bind_address: bind_address.to_string(),
            hostname: hostname.to_string(),
            webhook_client,
        }
    }

    pub async fn run(self) -> Result<()> {
        let listener = TcpListener::bind(&self.bind_address).await?;
        info!("SMTP server listening on {}", self.bind_address);

        loop {
            match listener.accept().await {
                Ok((stream, addr)) => {
                    info!("New connection from {}", addr);
                    let hostname = self.hostname.clone();
                    let webhook_client = self.webhook_client.clone();

                    tokio::spawn(async move {
                        if let Err(e) = handle_connection(stream, hostname, webhook_client).await {
                            error!("Connection error: {}", e);
                        }
                    });
                }
                Err(e) => {
                    error!("Failed to accept connection: {}", e);
                }
            }
        }
    }
}

async fn handle_connection(
    stream: TcpStream,
    hostname: String,
    webhook_client: Arc<WebhookClient>,
) -> Result<()> {
    let (reader, mut writer) = stream.into_split();
    let mut reader = BufReader::new(reader);

    // Send greeting
    writer
        .write_all(format!("220 {} SMTP Ready\r\n", hostname).as_bytes())
        .await?;

    let mut from: Option<String> = None;
    let mut to: Vec<String> = Vec::new();
    let mut data_mode = false;
    let mut email_data = String::new();

    let mut line = String::new();

    loop {
        line.clear();
        let bytes_read = reader.read_line(&mut line).await?;

        if bytes_read == 0 {
            break; // Connection closed
        }

        let command = line.trim();
        info!("Received: {}", command);

        if data_mode {
            if command == "." {
                // End of data
                data_mode = false;

                // Parse and send email
                let from_addr = from.clone().unwrap_or_else(|| "unknown".to_string());
                let to_addrs = to.clone();

                match parse_email(&from_addr, &to_addrs, &email_data) {
                    Some(email) => {
                        let webhook = webhook_client.clone();
                        tokio::spawn(async move {
                            if let Err(e) = webhook.send_email(&email).await {
                                error!("Failed to send email to webhook: {}", e);
                            }
                        });
                        writer.write_all(b"250 OK: Message accepted\r\n").await?;
                    }
                    None => {
                        warn!("Failed to parse email");
                        writer.write_all(b"250 OK: Message accepted\r\n").await?;
                    }
                }

                // Reset for next email
                from = None;
                to.clear();
                email_data.clear();
            } else {
                email_data.push_str(&line);
            }
        } else {
            let upper_command = command.to_uppercase();

            if upper_command.starts_with("HELO") || upper_command.starts_with("EHLO") {
                writer
                    .write_all(format!("250 {} Hello\r\n", hostname).as_bytes())
                    .await?;
            } else if upper_command.starts_with("MAIL FROM:") {
                let addr = extract_email_address(command);
                from = Some(addr);
                writer.write_all(b"250 OK\r\n").await?;
            } else if upper_command.starts_with("RCPT TO:") {
                let addr = extract_email_address(command);
                to.push(addr);
                writer.write_all(b"250 OK\r\n").await?;
            } else if upper_command.starts_with("DATA") {
                writer
                    .write_all(b"354 Start mail input; end with <CRLF>.<CRLF>\r\n")
                    .await?;
                data_mode = true;
            } else if upper_command.starts_with("QUIT") {
                writer.write_all(b"221 Bye\r\n").await?;
                break;
            } else if upper_command.starts_with("RSET") {
                from = None;
                to.clear();
                email_data.clear();
                writer.write_all(b"250 OK\r\n").await?;
            } else if upper_command.starts_with("NOOP") {
                writer.write_all(b"250 OK\r\n").await?;
            } else if upper_command.starts_with("AUTH") {
                // Accept any authentication
                if upper_command.contains("PLAIN") {
                    writer
                        .write_all(b"235 Authentication successful\r\n")
                        .await?;
                } else if upper_command.contains("LOGIN") {
                    writer.write_all(b"334 VXNlcm5hbWU6\r\n").await?; // "Username:" in base64
                    line.clear();
                    reader.read_line(&mut line).await?;
                    writer.write_all(b"334 UGFzc3dvcmQ6\r\n").await?; // "Password:" in base64
                    line.clear();
                    reader.read_line(&mut line).await?;
                    writer
                        .write_all(b"235 Authentication successful\r\n")
                        .await?;
                } else {
                    writer
                        .write_all(b"235 Authentication successful\r\n")
                        .await?;
                }
            } else {
                writer.write_all(b"250 OK\r\n").await?;
            }
        }
    }

    Ok(())
}

fn extract_email_address(command: &str) -> String {
    let parts: Vec<&str> = command.splitn(2, ':').collect();
    if parts.len() == 2 {
        let addr = parts[1].trim();
        // Remove < and > if present
        addr.trim_start_matches('<')
            .trim_end_matches('>')
            .trim()
            .to_string()
    } else {
        "unknown".to_string()
    }
}

fn parse_email(from: &str, to: &[String], raw_data: &str) -> Option<Email> {
    let mut body = String::new();
    let mut subject = String::new();
    let mut in_headers = true;
    let mut current_header = String::new();

    for line in raw_data.lines() {
        if in_headers {
            if line.is_empty() {
                // Process last header before switching to body
                if !current_header.is_empty() {
                    process_header(&current_header, &mut subject);
                    current_header.clear();
                }
                in_headers = false;
                continue;
            }

            // Handle folded headers (continuation lines starting with whitespace)
            if line.starts_with(' ') || line.starts_with('\t') {
                current_header.push(' ');
                current_header.push_str(line.trim());
            } else {
                // Process previous header if exists
                if !current_header.is_empty() {
                    process_header(&current_header, &mut subject);
                }
                current_header = line.to_string();
            }
        } else {
            body.push_str(line);
            body.push('\n');
        }
    }

    // Process last header if still in headers mode
    if in_headers && !current_header.is_empty() {
        process_header(&current_header, &mut subject);
    }

    Some(Email {
        from: from.to_string(),
        to: to.to_vec(),
        subject,
        body: body.trim().to_string(),
    })
}

fn process_header(header_line: &str, subject: &mut String) {
    if let Some((key, value)) = header_line.split_once(':') {
        if key.trim().eq_ignore_ascii_case("subject") {
            *subject = value.trim().to_string();
        }
    }
}
