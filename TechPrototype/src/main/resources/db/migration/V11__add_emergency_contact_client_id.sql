ALTER TABLE emergency_contact
  ADD COLUMN client_contact_id VARCHAR(36) NULL AFTER user_id,
  ADD UNIQUE KEY uk_emergency_contact_user_client (user_id, client_contact_id);
