CREATE TABLE IF NOT EXISTS agent_action (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  action_id VARCHAR(64) NOT NULL UNIQUE,
  user_id BIGINT NOT NULL,
  target_user_id BIGINT NOT NULL,
  actor_role VARCHAR(32) NOT NULL DEFAULT 'PATIENT',
  session_id BIGINT,
  action_type VARCHAR(64) NOT NULL,
  status VARCHAR(32) NOT NULL,
  payload TEXT,
  result TEXT,
  error_message TEXT,
  expires_at DATETIME,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_agent_action_user_status (user_id, status),
  INDEX idx_agent_action_target_status (target_user_id, status),
  INDEX idx_agent_action_session (session_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
