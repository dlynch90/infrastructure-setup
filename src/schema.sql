-- D1 Database Schema for Empathy First Media Agency AI Platform

-- Conversations table for chat history
CREATE TABLE conversations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    request_id TEXT NOT NULL UNIQUE,
    messages TEXT NOT NULL, -- JSON array of messages
    response TEXT NOT NULL,
    model_used TEXT NOT NULL,
    token_count INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Knowledge base for RAG
CREATE TABLE knowledge_base (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    category TEXT,
    tags TEXT, -- JSON array of tags
    source_url TEXT,
    created_by TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- User sessions and rate limiting
CREATE TABLE user_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    session_token TEXT NOT NULL UNIQUE,
    client_info TEXT, -- JSON object with client details
    expires_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- API usage tracking
CREATE TABLE api_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    client_id TEXT,
    endpoint TEXT NOT NULL,
    method TEXT NOT NULL,
    request_size INTEGER,
    response_size INTEGER,
    processing_time_ms INTEGER,
    status_code INTEGER,
    ip_address TEXT,
    user_agent TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Generated content storage metadata
CREATE TABLE generated_content (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    request_id TEXT NOT NULL,
    content_type TEXT NOT NULL, -- 'text', 'image', 'audio', etc.
    title TEXT,
    description TEXT,
    r2_key TEXT, -- Key in R2 bucket
    public_url TEXT,
    metadata TEXT, -- JSON object with additional metadata
    expires_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_conversations_user_id ON conversations(user_id);
CREATE INDEX idx_conversations_created_at ON conversations(created_at);
CREATE INDEX idx_knowledge_base_category ON knowledge_base(category);
CREATE INDEX idx_knowledge_base_tags ON knowledge_base(tags);
CREATE INDEX idx_api_usage_user_id ON api_usage(user_id);
CREATE INDEX idx_api_usage_created_at ON api_usage(created_at);
CREATE INDEX idx_generated_content_user_id ON generated_content(user_id);

-- Views for analytics
CREATE VIEW daily_usage AS
SELECT
    DATE(created_at) as date,
    user_id,
    COUNT(*) as requests,
    SUM(token_count) as total_tokens,
    AVG(processing_time_ms) as avg_response_time
FROM conversations
GROUP BY DATE(created_at), user_id;

CREATE VIEW model_usage AS
SELECT
    model_used,
    COUNT(*) as usage_count,
    AVG(token_count) as avg_tokens,
    AVG(processing_time_ms) as avg_processing_time
FROM conversations
GROUP BY model_used;

-- Triggers for updated_at
CREATE TRIGGER update_conversations_updated_at
    AFTER UPDATE ON conversations
BEGIN
    UPDATE conversations SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER update_knowledge_base_updated_at
    AFTER UPDATE ON knowledge_base
BEGIN
    UPDATE knowledge_base SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;