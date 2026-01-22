-- Migration 001: Initial Schema
-- Created: 2026-01-22

-- Tạo function update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Bảng question_templates
CREATE TABLE IF NOT EXISTS question_templates (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(500) NOT NULL,
    slug VARCHAR(500) UNIQUE,
    description TEXT,
    roles JSONB DEFAULT '[]',
    questions JSONB DEFAULT '[]',
    subjects JSONB DEFAULT '[]',
    subject_questions JSONB DEFAULT '[]',
    template_questions JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Bảng evaluation_sessions
CREATE TABLE IF NOT EXISTS evaluation_sessions (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(500) NOT NULL,
    description TEXT,
    evaluator_email VARCHAR(255),
    evaluator_name VARCHAR(255),
    deadline TIMESTAMP,
    subjects JSONB DEFAULT '[]',
    status VARCHAR(50) DEFAULT 'pending',
    link TEXT,
    token VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Bảng evaluation_responses
CREATE TABLE IF NOT EXISTS evaluation_responses (
    id VARCHAR(255) PRIMARY KEY,
    session_id VARCHAR(255),
    template_id VARCHAR(255),
    department VARCHAR(255),
    selected_subjects JSONB DEFAULT '[]',
    answers JSONB DEFAULT '{}',
    subject_details JSONB DEFAULT '[]',
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'completed'
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_templates_created ON question_templates(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_templates_slug ON question_templates(slug);
CREATE INDEX IF NOT EXISTS idx_templates_active ON question_templates(is_active);
CREATE INDEX IF NOT EXISTS idx_sessions_created ON evaluation_sessions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON evaluation_sessions(token);
CREATE INDEX IF NOT EXISTS idx_responses_session ON evaluation_responses(session_id);
CREATE INDEX IF NOT EXISTS idx_responses_template ON evaluation_responses(template_id);
CREATE INDEX IF NOT EXISTS idx_responses_submitted ON evaluation_responses(submitted_at DESC);

-- Triggers
DROP TRIGGER IF EXISTS update_templates_updated_at ON question_templates;
CREATE TRIGGER update_templates_updated_at
    BEFORE UPDATE ON question_templates
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_sessions_updated_at ON evaluation_sessions;
CREATE TRIGGER update_sessions_updated_at
    BEFORE UPDATE ON evaluation_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
