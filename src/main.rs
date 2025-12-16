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
use tokio::sync::broadcast;
use webhook::WebhookClient;

#[tokio::main]
async fn main() -> Result<()> {
    // Load configuration
    let config_path = env::args()
        .nth(1)
        .unwrap_or_else(|| "config.toml".to_string());
    let config = Config::from_file(&config_path)?;

    // Initialize logger
    initialize_logger(&config.logging.level);

    info!("SMTP2Webhook starting...");
    info!("Configuration loaded from: {}", config_path);
    info!("SMTP server will bind to: {}", config.smtp.bind_address);
    info!("Webhook URL: {}", config.webhook.url);

    // Create webhook client
    let webhook_client = Arc::new(WebhookClient::new(config.webhook.clone())?);

    // Create shutdown channel
    let (shutdown_tx, shutdown_rx) = broadcast::channel(1);

    // Spawn shutdown signal handler
    tokio::spawn(async move {
        shutdown_signal().await;
        info!("Shutdown signal received, initiating graceful shutdown...");
        let _ = shutdown_tx.send(());
    });

    // Create and run SMTP server
    let smtp_server = SmtpServer::new(
        &config.smtp.bind_address,
        &config.smtp.hostname,
        webhook_client,
    );

    info!("SMTP server ready to accept connections");

    smtp_server.run(shutdown_rx).await?;

    info!("SMTP2Webhook shutdown complete");

    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
}

fn initialize_logger(level: &str) {
    let log_level = level.parse().unwrap_or(log::LevelFilter::Info);
    env_logger::Builder::from_default_env()
        .filter_level(log_level)
        .init();
}
