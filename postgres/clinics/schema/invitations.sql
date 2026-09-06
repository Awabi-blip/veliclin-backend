CREATE TABLE IF NOT EXISTS invitations(
    "invitation_id" SERIAL,
    "sender_id" UUID NOT NULL,
    "clinic_id" UUID NOT NULL,
    "role_invited_for" E_staff_role NOT NULL,
    "sender_email" CITEXT NOT NULL,
    "receiver_email" CITEXT NOT NULL,
    "receiver_id" UUID NOT NULL,
    PRIMARY KEY ("invitation_id"),
    UNIQUE ("sender_id", "receiver_email"),
    FOREIGN KEY ("sender_email", "sender_id") REFERENCES app_users("email", "id"),
    FOREIGN KEY ("receiver_email", "receiver_id") REFERENCES app_users("email", "id"),
    FOREIGN KEY (sender_id, clinic_id) REFERENCES clinics(owner_id, clinic_id)
);


ALTER TABLE invitations
ADD CONSTRAINT invitations_sender_clinic_fk
FOREIGN KEY (sender_id, clinic_id)
REFERENCES clinics(owner_id, clinic_id);

ALTER TABLE invitations
ADD CONSTRAINT invitations_sender_receiver_unique
UNIQUE (sender_id, receiver_id);

ALTER TABLE invitations
ADD CONSTRAINT invitations_sender_receiver_not_same
CHECK (
    receiver_email <> sender_email
    AND receiver_id <> sender_id
);

select * from invitations;

CREATE VIEW view_invitations
WITH (security_invoker = true) AS
SELECT 
    invitations.invitation_id AS invitation_id,
    clinics.clinic_name AS clinic_name,
    clinics.clinic_type AS clinic_type,
    clinics.city_name AS city_clinic_is_in,
    invitations.role_invited_for AS role_invited_for, 
    senders.first_name || ' ' || senders.last_name AS invited_by
FROM invitations
JOIN clinics ON invitations.clinic_id = clinics.clinic_id
JOIN profiles AS senders ON invitations.sender_id = senders.id;
 
