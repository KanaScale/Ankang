CREATE TABLE IF NOT EXISTS `user` (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(64) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  nickname VARCHAR(64),
  gender VARCHAR(16),
  age INT,
  phone VARCHAR(32),
  email VARCHAR(128),
  avatar_url VARCHAR(255),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS health_profile (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  height DECIMAL(6,2),
  weight DECIMAL(6,2),
  chronic_diseases JSON,
  allergies VARCHAR(255),
  medical_history TEXT,
  device VARCHAR(128),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_health_profile_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS health_record (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  type VARCHAR(32) NOT NULL,
  value DECIMAL(10,2),
  value1 DECIMAL(10,2),
  value2 DECIMAL(10,2),
  systolic INT,
  diastolic INT,
  unit VARCHAR(32),
  status VARCHAR(32) NOT NULL DEFAULT 'normal',
  source VARCHAR(32) NOT NULL DEFAULT 'manual',
  remark VARCHAR(255),
  recorded_at DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_health_record_user_type_time (user_id, type, recorded_at),
  INDEX idx_health_record_recorded_at (recorded_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS reminder (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  title VARCHAR(128) NOT NULL,
  type VARCHAR(32) NOT NULL DEFAULT 'other',
  description VARCHAR(255),
  remark VARCHAR(255),
  remind_at DATETIME,
  remind_time TIME,
  repeat_type VARCHAR(32) NOT NULL DEFAULT 'once',
  enabled TINYINT(1) NOT NULL DEFAULT 1,
  completed TINYINT(1) NOT NULL DEFAULT 0,
  last_completed_date DATE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_reminder_user_time (user_id, remind_at),
  INDEX idx_reminder_user_enabled (user_id, enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS emergency_contact (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  name VARCHAR(64) NOT NULL,
  relation VARCHAR(64),
  relationship VARCHAR(64),
  phone VARCHAR(32) NOT NULL,
  priority INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_emergency_contact_user_priority (user_id, priority)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS emergency_event (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  latitude DECIMAL(10,7),
  longitude DECIMAL(10,7),
  address VARCHAR(255),
  message VARCHAR(255),
  status VARCHAR(32) NOT NULL DEFAULT 'created',
  contacts_notified INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_emergency_event_user_time (user_id, created_at),
  INDEX idx_emergency_event_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS health_advice (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  title VARCHAR(128) NOT NULL,
  content TEXT NOT NULL,
  level VARCHAR(32) NOT NULL DEFAULT 'normal',
  advice_date DATE NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_health_advice_user_date (user_id, advice_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS device_bind (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  device_name VARCHAR(128) NOT NULL,
  device_type VARCHAR(64),
  provider VARCHAR(64),
  bind_status VARCHAR(32) NOT NULL DEFAULT 'active',
  last_sync_at DATETIME,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_device_bind_user_id (user_id),
  INDEX idx_device_bind_status (bind_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
