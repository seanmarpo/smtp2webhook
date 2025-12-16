use crate::email::Email;
use crate::webhook::WebhookClient;
use anyhow::Result;
use log::{error, info, warn};
use mail_parser::{MessageParser, MimeHeaders};
use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{TcpListener, TcpStream};

// Input validation limits
const MAX_EMAIL_SIZE: usize = 50 * 1024 * 1024; // 50MB
const MAX_LINE_LENGTH: usize = 10000; // 10KB per line

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

    pub async fn run(self, shutdown: tokio::sync::broadcast::Receiver<()>) -> Result<()> {
        let listener = TcpListener::bind(&self.bind_address).await?;
        info!("SMTP server listening on {}", self.bind_address);

        let mut shutdown_rx = shutdown;

        loop {
            tokio::select! {
                _ = shutdown_rx.recv() => {
                    info!("Shutdown signal received, stopping SMTP server");
                    break;
                }
                result = listener.accept() => {
                    match result {
                        Ok((stream, addr)) => {
                            info!("New connection from {}", addr);
                            let hostname = self.hostname.clone();
                            let webhook_client = Arc::clone(&self.webhook_client);

                            tokio::spawn(async move {
                                if let Err(e) = handle_connection(stream, &hostname, webhook_client).await {
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

        Ok(())
    }
}

async fn handle_connection(
    stream: TcpStream,
    hostname: &str,
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
                let from_addr = from.as_deref().unwrap_or("unknown");
                let to_addrs = &to;

                match parse_email(from_addr, to_addrs, &email_data) {
                    Some(email) => {
                        let webhook = Arc::clone(&webhook_client);
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
                // Validate line length
                if line.len() > MAX_LINE_LENGTH {
                    writer.write_all(b"500 Line too long\r\n").await?;
                    data_mode = false;
                    from = None;
                    to.clear();
                    email_data.clear();
                    continue;
                }

                // Validate total email size
                if email_data.len() + line.len() > MAX_EMAIL_SIZE {
                    writer
                        .write_all(b"552 Message size exceeds limit\r\n")
                        .await?;
                    data_mode = false;
                    from = None;
                    to.clear();
                    email_data.clear();
                    continue;
                }

                email_data.push_str(&line);
            }
        } else {
            let upper_command = command.to_uppercase();

            // Handle AUTH command inline to avoid borrow issues
            if upper_command.starts_with("AUTH") {
                if upper_command.contains("LOGIN") {
                    writer.write_all(b"334 VXNlcm5hbWU6\r\n").await?; // "Username:" in base64
                    line.clear();
                    reader.read_line(&mut line).await?;
                    writer.write_all(b"334 UGFzc3dvcmQ6\r\n").await?; // "Password:" in base64
                    line.clear();
                    reader.read_line(&mut line).await?;
                }
                writer
                    .write_all(b"235 Authentication successful\r\n")
                    .await?;
            } else {
                let should_quit = handle_smtp_command(
                    &upper_command,
                    &mut from,
                    &mut to,
                    &mut data_mode,
                    &mut writer,
                    hostname,
                )
                .await?;

                if should_quit {
                    break; // Exit the connection loop
                }
            }
        }
    }

    Ok(())
}

async fn handle_smtp_command(
    upper_command: &str,
    from: &mut Option<String>,
    to: &mut Vec<String>,
    data_mode: &mut bool,
    writer: &mut tokio::net::tcp::OwnedWriteHalf,
    hostname: &str,
) -> Result<bool> {
    if upper_command.starts_with("HELO") || upper_command.starts_with("EHLO") {
        writer
            .write_all(format!("250 {} Hello\r\n", hostname).as_bytes())
            .await?;
    } else if upper_command.starts_with("MAIL FROM:") {
        *from = Some(extract_email_address(upper_command));
        writer.write_all(b"250 OK\r\n").await?;
    } else if upper_command.starts_with("RCPT TO:") {
        to.push(extract_email_address(upper_command));
        writer.write_all(b"250 OK\r\n").await?;
    } else if upper_command.starts_with("DATA") {
        writer
            .write_all(b"354 Start mail input; end with <CRLF>.<CRLF>\r\n")
            .await?;
        *data_mode = true;
    } else if upper_command.starts_with("QUIT") {
        writer.write_all(b"221 Bye\r\n").await?;
        writer.flush().await?;
        return Ok(true); // Signal to close connection
    } else if upper_command.starts_with("RSET") {
        *from = None;
        to.clear();
        writer.write_all(b"250 OK\r\n").await?;
    } else if upper_command.starts_with("NOOP") {
        writer.write_all(b"250 OK\r\n").await?;
    } else {
        writer.write_all(b"500 Command not recognized\r\n").await?;
    }

    Ok(false) // Continue connection
}

fn extract_email_address(command: &str) -> String {
    command
        .split_once(':')
        .map(|(_, addr)| {
            addr.trim()
                .trim_start_matches('<')
                .trim_end_matches('>')
                .to_string()
        })
        .unwrap_or_else(|| "unknown".to_string())
}

fn parse_email(from: &str, to: &[String], raw_data: &str) -> Option<Email> {
    let parser = MessageParser::default();
    let message = parser.parse(raw_data.as_bytes())?;

    let subject = message.subject().unwrap_or("").to_string();

    // mail_parser automatically converts HTML to text
    // body_text(0) gets the first text body part, converting HTML if needed
    let body = message
        .body_text(0)
        .map(|s| s.to_string())
        .unwrap_or_default();

    // Extract attachment filenames
    let mut attachments = Vec::new();
    for part in &message.parts {
        if let Some(filename) = part.attachment_name() {
            attachments.push(filename.to_string());
        }
    }

    Some(Email {
        from: from.to_string(),
        to: to.to_vec(),
        subject,
        body,
        attachments,
    })
}
