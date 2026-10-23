CREATE TABLE IF NOT EXISTS health_event (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  event_id VARCHAR(36) NOT NULL UNIQUE,
  user_id BIGINT NOT NULL,
  event_type VARCHAR(64) NOT NULL,
  aggregate_id BIGINT NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'processing',
  risk_level VARCHAR(32),
  risk_score INT,
  summary VARCHAR(255),
  reasons_json JSON,
  sos_event_id BIGINT,
  occurred_at DATETIME NOT NULL,
  processed_at DATETIME,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_health_event_user_time (user_id, occurred_at),
  INDEX idx_health_event_status (status),
  INDEX idx_health_event_risk_level (risk_level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS health_event_timeline (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  health_event_id BIGINT NOT NULL,
  stage VARCHAR(64) NOT NULL,
  message VARCHAR(255) NOT NULL,
  occurred_at DATETIME NOT NULL,
  INDEX idx_health_event_timeline_event (health_event_id, occurred_at, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
