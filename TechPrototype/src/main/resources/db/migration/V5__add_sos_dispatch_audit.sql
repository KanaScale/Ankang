ALTER TABLE emergency_event
  ADD COLUMN client_event_id VARCHAR(36) NULL AFTER user_id,
  ADD COLUMN triggered_at DATETIME NULL AFTER client_event_id,
  ADD COLUMN accuracy_meters DECIMAL(10,2) NULL AFTER longitude,
  ADD COLUMN location_source VARCHAR(32) NOT NULL DEFAULT 'unavailable' AFTER accuracy_meters,
  ADD UNIQUE KEY uk_emergency_event_user_client (user_id, client_event_id);

UPDATE emergency_event
SET triggered_at = created_at
WHERE triggered_at IS NULL;

ALTER TABLE emergency_event
  MODIFY COLUMN triggered_at DATETIME NOT NULL;

CREATE TABLE IF NOT EXISTS emergency_delivery_attempt (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  event_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  attempt_id VARCHAR(36) NOT NULL,
  contact_id BIGINT,
  channel VARCHAR(16) NOT NULL,
  status VARCHAR(32) NOT NULL,
  error_code VARCHAR(64),
  occurred_at DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_delivery_event_attempt (event_id, attempt_id),
  INDEX idx_delivery_user_event (user_id, event_id),
  INDEX idx_delivery_event_channel_status (event_id, channel, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
