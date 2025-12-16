use crate::config::WebhookConfig;
use crate::email::Email;
use anyhow::Result;
use log::{error, info, warn};
use reqwest::Client;
use std::time::Duration;

pub struct WebhookClient {
    client: Client,
    config: WebhookConfig,
}

impl WebhookClient {
    pub fn new(config: WebhookConfig) -> Result<Self> {
        let client = Client::builder()
            .timeout(Duration::from_secs(config.timeout_secs))
            .build()?;

        Ok(Self { client, config })
    }

    pub async fn send_email(&self, email: &Email) -> Result<()> {
        let mut last_error = None;

        for attempt in 0..=self.config.max_retries {
            if attempt > 0 {
                warn!(
                    "Retry attempt {}/{} for email from {}",
                    attempt, self.config.max_retries, email.from
                );

                // Exponential backoff with max cap of 30 seconds: 1s, 2s, 4s, 8s, 16s, 30s, 30s...
                let delay_secs = 2u64.pow(attempt - 1).min(30);
                tokio::time::sleep(Duration::from_secs(delay_secs)).await;
            }

            match self.send_request(email).await {
                Ok(_) => {
                    info!("Successfully sent email from {} to webhook", email.from);
                    return Ok(());
                }
                Err(e) => {
                    warn!(
                        "Failed to send email to webhook (attempt {}/{}): {}",
                        attempt + 1,
                        self.config.max_retries + 1,
                        e
                    );
                    last_error = Some(e);
                }
            }
        }

        // All retries exhausted
        let error = last_error.unwrap_or_else(|| anyhow::anyhow!("Unknown error"));
        error!(
            "Failed to send email from {} to webhook after {} attempts. Dropping email.",
            email.from,
            self.config.max_retries + 1
        );
        Err(error)
    }

    async fn send_request(&self, email: &Email) -> Result<()> {
        let mut request = self.client.post(&self.config.url).json(email);

        // Add custom headers from config
        for (key, value) in &self.config.headers {
            request = request.header(key, value);
        }

        let response = request.send().await?;

        if response.status().is_success() {
            Ok(())
        } else {
            Err(anyhow::anyhow!(
                "Webhook returned error status: {}",
                response.status()
            ))
        }
    }
}
