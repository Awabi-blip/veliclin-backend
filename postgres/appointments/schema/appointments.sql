CREATE TYPE e_appointment_status AS ENUM ('Scheduled', 'Completed', 'Cancelled', 'On_going');

CREATE TABLE IF NOT EXISTS appointments (
    "appointment_id"     BIGSERIAL,
    "doctor_id"          UUID NOT NULL,
    "doctor_role"        e_staff_role NOT NULL CHECK (doctor_role = 'Doctor'::e_staff_role),
    "doctor_schedule_id" INT NOT NULL,
    "clinic_id"          UUID NOT NULL,
    "patient_id"         UUID NOT NULL,
    "status"             e_appointment_status NOT NULL DEFAULT 'Scheduled'::e_appointment_status,
    "scheduled_at"       TIMESTAMPTZ NOT NULL CHECK (EXTRACT(SECOND FROM "scheduled_at") = 0),
    "ends_at"            TIMESTAMPTZ NOT NULL,
    "meeting_link"       VARCHAR(2048),
    PRIMARY KEY ("appointment_id"),
    FOREIGN KEY ("doctor_id", "doctor_role") REFERENCES staffs_in_clinics("staff_id", "staff_role"),
    FOREIGN KEY ("patient_id", "clinic_id") REFERENCES patients_in_clinics("patient_id", "clinic_id"),
    FOREIGN KEY ("doctor_id", "schedule_id") REFERENCES doctors_schedule("doctor_id", "schedule_id")
);
-- 1. Add clinic_id column
ALTER TABLE appointments ADD UNIQUE ("appointment_id", "doctor_id", "clinic_id", "status");

CREATE TABLE IF NOT EXISTS appointments_information (
    "appointment_id" BIGINT,
    "doctor_id"      UUID NOT NULL,
    "clinic_id"      UUID NOT NULL,
    "note"           VARCHAR(1000),
    "diagnosis"      VARCHAR(500),
    "fee"            DECIMAL(2,1),
    "status"         e_appointment_status CHECK ("status" != 'Cancelled'),
    PRIMARY KEY ("appointment_id"),
    FOREIGN KEY ("appointment_id") REFERENCES  appointments("appointment_id"),
    FOREIGN KEY ("appointment_id", "doctor_id", "clinic_id", "status") REFERENCES 
    appointments("appointment_id", "doctor_id", "clinic_id", "status")
);



GRANT SELECT ON ALL TABLES IN SCHEMA public TO app;
CREATE VIEW view_appointments_as_doctors
with (security_invoker = true) AS
SELECT CONCAT(pic.first_name, ' ', pic.last_name) AS patient_name,
ap.appointment_id as appointment_id,
ap.scheduled_at as scheduled_at,
ap.ends_at as ends_at,
ap.meeting_link as meeting_link,
ap.status as status,
api.note as note,
api.fee as fee,
api.diagnosis as diagnosis
FROM patients_in_clinics AS pic JOIN appointments as ap
ON pic.patient_id = ap.patient_id
LEFT JOIN appointments_information as api
ON ap.appointment_id = api.appointment_id;


CREATE VIEW view_appointments_as_staffs
with (security_invoker = true) AS
SELECT CONCAT(profiles.first_name, ' ', profiles.last_name) AS doctor_name,
CONCAT(pic.first_name, ' ', pic.last_name) AS patient_name,
ap.appointment_id as appointment_id,
ap.scheduled_at as scheduled_at,
ap.ends_at as ends_at,
ap.status as status,
ap.clinic_id as clinic_id
FROM staffs_in_clinics AS sic JOIN appointments as ap
ON sic.staff_id = ap.doctor_id
JOIN profiles on ap.doctor_id = profiles.id
JOIN patients_in_clinics as pic 
ON pic.patient_id = ap.patient_id;

-- Update 'note' column from TEXT to VARCHAR(500)
ALTER TABLE appointments 
ALTER COLUMN note TYPE VARCHAR(1000);

ALTER TABLE appointments 
ALTER COLUMN meeting_link TYPE VARCHAR(2048);
-- Update 'diagnoses' column from TEXT to VARCHAR(500)
ALTER TABLE appointments 
ALTER COLUMN diagnosis TYPE VARCHAR(500);

create extension if not exists btree_gist;


