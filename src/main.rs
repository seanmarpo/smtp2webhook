mod config;
mod email;
mod smtp_server;
mod webhook;

use anyhow::Result;
use config::Config;
use log::info;
use smtp_server::SmtpServer;
use std::env;
use std::sync::Arc;
use webhook::WebhookClient;

#[tokio::main]
async fn main() -> Result<()> {
    // Load configuration
    let config_path = env::args()
        .nth(1)
        .unwrap_or_else(|| "config.toml".to_string());

    let config = Config::from_file(&config_path)?;

    // Initialize logger
    let log_level = config
        .logging
        .level
        .parse()
        .unwrap_or(log::LevelFilter::Info);
    env_logger::Builder::from_default_env()
        .filter_level(log_level)
        .init();

    info!("SMTP2Webhook starting...");
    info!("Configuration loaded from: {}", config_path);
    info!("SMTP server will bind to: {}", config.smtp.bind_address);
    info!("Webhook URL: {}", config.webhook.url);

    // Create webhook client
    let webhook_client = Arc::new(WebhookClient::new(config.webhook.clone())?);

    // Create and run SMTP server
    let smtp_server = SmtpServer::new(
        &config.smtp.bind_address,
        &config.smtp.hostname,
        webhook_client,
    );

    info!("SMTP server ready to accept connections");

    smtp_server.run().await?;

    Ok(())
}
