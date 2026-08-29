CREATE INDEX idx_register_users_1 ON app_users(
    id
) INCLUDE (onboarded);

CREATE INDEX idx_register_users_2 ON staffs_in_clinics(
    staff_id
) INCLUDE (staff_role, clinic_id);

CREATE INDEX idx_register_users_3 ON clinics(
    owner_id
) INCLUDE (expires_at);


CREATE INDEX idx_register_users_4 ON clinics (
    clinic_id
) INCLUDE (expires_at);
