ALTER TABLE reminder
  ADD COLUMN client_reminder_id VARCHAR(36) NULL AFTER user_id,
  ADD UNIQUE KEY uk_reminder_user_client (user_id, client_reminder_id);
