CREATE TYPE e_staff_role AS ENUM('Doctor', 'Nurse', 'Manager', 'Receptionist');
CREATE TABLE IF NOT EXISTS staffs_in_clinics (
    "sic_id"     SERIAL PRIMARY KEY
    "staff_id"   UUID NOT NULL,
    "clinic_id"  UUID NOT NULL,
    "staff_role" e_staff_role NOT NULL,
    "is_active"  BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE("staff_id", "clinic_id", "staff_role"),
    UNIQUE("staff_id", "clinic_id"),
    PRIMARY KEY ("sic_id"), -- because one guy can only be staff in one clinic at a time
    FOREIGN KEY ("staff_id") REFERENCES profiles(id) ON DELETE CASCADE,
    FOREIGN KEY ("clinic_id") REFERENCES clinics("clinic_id") ON DELETE CASCADE
);

CREATE unique index ON staffs_in_clinics ("staff_id")
WHERE is_active = TRUE

ALTER TABLE staffs_in_clinics
    DROP CONSTRAINT staffs_in_clinics_pkey;

ALTER TABLE staffs_in_clinics
    ADD COLUMN sic_id SERIAL PRIMARY KEY;

ALTER TABLE staffs_in_clinics
ADD CONSTRAINT uq_staff_role UNIQUE (staff_id, staff_role);