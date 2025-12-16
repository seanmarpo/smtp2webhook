use serde::Serialize;

#[derive(Debug, Serialize, Clone)]
pub struct Email {
    pub from: String,
    pub to: Vec<String>,
    pub subject: String,
    pub body: String,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub attachments: Vec<String>,
}
