ALTER TABLE `user`
  ADD COLUMN role VARCHAR(32) NOT NULL DEFAULT 'PATIENT' AFTER avatar_url;

CREATE TABLE IF NOT EXISTS care_relation (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  patient_user_id BIGINT NOT NULL,
  caregiver_user_id BIGINT NULL,
  relation_type VARCHAR(32),
  permissions VARCHAR(255),
  status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
  invite_code VARCHAR(64),
  invite_expire_at DATETIME,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_patient_user (patient_user_id),
  INDEX idx_caregiver_user (caregiver_user_id),
  INDEX idx_invite_code (invite_code),
  INDEX idx_care_relation_status (status),
  UNIQUE KEY uk_patient_caregiver (patient_user_id, caregiver_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE agent_conversation
  ADD COLUMN target_user_id BIGINT NULL AFTER user_id,
  ADD COLUMN actor_role VARCHAR(32) NOT NULL DEFAULT 'PATIENT' AFTER target_user_id,
  ADD INDEX idx_agent_conversation_actor_target (user_id, target_user_id, actor_role, updated_at);
