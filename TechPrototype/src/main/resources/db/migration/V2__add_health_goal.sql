CREATE TABLE IF NOT EXISTS health_goal (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  steps_target VARCHAR(64),
  steps_note VARCHAR(128),
  sleep_target VARCHAR(64),
  sleep_note VARCHAR(128),
  blood_pressure_target VARCHAR(64),
  blood_pressure_note VARCHAR(128),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_health_goal_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
