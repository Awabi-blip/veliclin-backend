-- Active: 1786733926332@@127.0.0.1@5433@veliclin_database
zoha_id :   019f8cbb-0e9c-75ff-8c93-e1735e9c4a8e
ayesha_id : 019f8cbb-caf8-7fb4-99e4-88421e1167c2
raiden_clinic_id : 019f8cc7-dac4-7568-ae80-c74982b31409

select * from staffs_in_clinics;


select * from app_users;

select * from profiles;
INSERT INTO "profiles"("id","first_name","last_name","gender","dob") VALUES('019f8cbb-caf8-7fb4-99e4-88421e1167c2','Ayesha','Baig','Female','2005-07-01');

INSERT INTO "staffs_in_clinics"("staff_id","clinic_id","staff_role") VALUES('019f8cbb-caf8-7fb4-99e4-88421e1167c2','019f8cc7-dac4-7568-ae80-c74982b31409','Doctor');
INSERT INTO "staffs_in_clinics"("staff_id","clinic_id","staff_role") VALUES('019f8caa-a51a-7e7f-8208-403bc23616b8','019f8cc7-dac4-7568-ae80-c74982b31409','Manager');


select * from clinics;

CREATE TYPE e_clinic_type AS ENUM (
    'General_Clinic',
    'Dental_Clinic',
    'Maternity_Home',
    'CMW_Clinic',
    'Nursing_Home',
    'Homeopathic_Clinic',
    'Tibb_Clinic',
    'Physiotherapy_Clinic',
    'Rehabilitation_Centre',
    'Aesthetic_Clinic',
    'Diagnostic_Laboratory',
    'Radiological_Imaging_Centre',
    'Dialysis_Centre',
    'Lithotripsy_Centre'
);

CREATE TYPE e_clinic_plan AS ENUM('free_trial', 'basic', 'premium');
select * from clinics;

CREATE TABLE IF NOT EXISTS clinics (
    "clinic_id" UUID NOT NULL DEFAULT gen_v7_uuid(),
    "owner_id" UUID NOT NULL UNIQUE,
    "clinic_name" VARCHAR(100) NOT NULL,
    "clinic_type" E_clinic_type NOT NULL,
    "city_name" VARCHAR(128) NOT NULL,
    "address" VARCHAR(500) NOT NULL,
    "contact_number" VARCHAR(15) NOT NULL CHECK(contact_number ~ '^\+\d{7,15}$'),
    "banner_url" TEXT CHECK(banner_url ~* '^https?:\/\/([\w\-]+\.)+[\w]{2,}(\/[\w\-._~:/?#\[\]@!$&''()*+,;=%]*)?$'),
    "plan" E_clinic_plan NOT NULL DEFAULT 'free_trial'::E_clinic_plan,
    "expires_at" TIMESTAMPTZ NOT NULL,
    "all_visibility" BOOLEAN NOT NULL,
    PRIMARY KEY ("clinic_id"),
    UNIQUE("clinic_id", "owner_id"),
    FOREIGN KEY ("owner_id") REFERENCES profiles("id") ON DELETE CASCADE
);


ALTER TABLE clinics ADD COLUMN "timezone" VARCHAR(64) NOT NULL DEFAULT 'UTC';

CREATE OR REPLACE FUNCTION is_valid_timezone() 
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 from pg_timezone_names WHERE name ILIKE new.timezone
    ) THEN RAISE EXCEPTION 'Timezone not valid';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql STABLE

-- 1. Create the trigger on the clinics table
CREATE TRIGGER trg_validate_clinic_timezone
BEFORE INSERT OR UPDATE ON clinics
FOR EACH ROW
EXECUTE FUNCTION is_valid_timezone();


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

CREATE TABLE IF NOT EXISTS referrals (
    "id" BIGSERIAL,
    "patient_id" UUID NOT NULL,
    "reffered_by" UUID NOT NULL,
    "refferer_role" e_staff_role CHECK ("refferer_role" = 'Doctor'::e_staff_role),
    "reffered_to" UUID NOT NULL,
    "reffered_to_role" e_staff_role CHECK ("reffered_to_role" = 'Doctor'::e_staff_role),
    "clinic_id" UUID NOT NULL,
    PRIMARY KEY ("id"),
    FOREIGN KEY ("patient_id", "clinic_id") REFERENCES patients_in_clinics("patient_id", "clinic_id"),
    FOREIGN KEY ("reffered_by", "refferer_role", "clinic_id") REFERENCES staffs_in_clinics("staff_id", "staff_role", "clinic_id"),
    FOREIGN KEY ("reffered_to", "reffered_to_role" , "clinic_id") REFERENCES staffs_in_clinics("staff_id", "staff_role", "clinic_id")
);

ALTER TABLE referrals
ADD CONSTRAINT chk_different_staff CHECK ("reffered_by" <> "reffered_to");

CREATE TYPE e_neurotype AS ENUM ('Typical', 'ASD', 'ADHD', 'OCD', 'Dyslexia',
'Dyspraxia', 'Dyscalculia', 'Dysgraphia');

CREATE TYPE e_blood_type AS ENUM ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-');

CREATE TABLE IF NOT EXISTS patients_in_clinics ( -- not a junction table
    "patient_id"     UUID NOT NULL DEFAULT gen_v7_uuid(),
    "added_by"       UUID NOT NULL,
    "adder_role"     e_staff_role NOT NULL CHECK ("adder_role" = 'Doctor'::e_staff_role),
    "clinic_id"      UUID NOT NULL,
    "first_name"     VARCHAR(40) NOT NULL,
    "last_name"      VARCHAR(40) NOT NULL,
    "contact_number" VARCHAR(15) NOT NULL CHECK(contact_number ~ '^\+\d{7,15}$'),
    "email"          CITEXT,
    "gender"         e_gender NOT NULL
    UNIQUE ("clinic_id", "contact_number"),
    UNIQUE ("patient_id", "clinic_id", "added_by"),
    UNIQUE ("patient_id", "clinic_id"),
    PRIMARY KEY ("patient_id"),
    FOREIGN KEY ("added_by", "adder_role", "clinic_id") REFERENCES staffs_in_clinics("staff_id", "staff_role","clinic_id")
);

select * from staffs_in_clinics;

INSERT INTO patients_in_clinics 
    (patient_id, added_by, adder_role, clinic_id, first_name, last_name, contact_number, email, gender)
VALUES 
    (gen_v7_uuid(), '019f8cbb-caf8-7fb4-99e4-88421e1167c2', 'Doctor', '019f8cc7-dac4-7568-ae80-c74982b31409', 'Fatima', 'Khan', '+923001234567', 'fatima@example.com', 'Female');

delete from patients_in_clinics;
CREATE TABLE IF NOT EXISTS patients_information (
    "patient_id"  UUID NOT NULL,
    "added_by"    UUID NOT NULL,
    "clinic_id"   UUID NOT NULL,
    "neurotype"   e_neurotype DEFAULT 'Typical'::E_neurotype,
    "blood_type"  e_blood_type,
    "height_cm"   DECIMAL(4,1),
    "weight_kg"   DECIMAL (5,2),
    "note"        VARCHAR(500),
    PRIMARY KEY   ("patient_id"),
    FOREIGN KEY   ("patient_id") REFERENCES patients_in_clinics ("patient_id")
    ON DELETE CASCADE,
    UNIQUE        ("patient_id", "clinic_id"),
    
    FOREIGN KEY   ("patient_id", "added_by", "clinic_id")
    REFERENCES    patients_in_clinics ("patient_id", "added_by", "clinic_id")
    ON DELETE CASCADE
);

GRANT SELECT ON ALL TABLES IN SCHEMA public TO app;

drop view view_patients_as_doctors;
--create a view for returning patients
create view view_patients_as_doctors
with (security_invoker = true) as
select 
    pic.patient_id        as patient_id,
    concat(pic.first_name, ' ', 
    pic.last_name)        as full_name,
    pic.contact_number      as phone_number,
    pic.email             as email,
    pic.gender            as gender,
    pin.neurotype         as neurotype,
    pin.blood_type        as blood_type,
    pin.height_cm         as height_cm,
    pin.weight_kg         as weight_kg,
    pin.note              as note
from patients_in_clinics  as pic
join patients_information as pin
on   pic.patient_id       = pin.patient_id;

drop view view_patients_as_doctors;



create view view_patients_as_staff
with (security_invoker = true) as
select 
    pic.patient_id        as patient_id,
    concat(pic.first_name, ' ', 
    pic.last_name)        as full_name,
    pic.contact_number      as phone_number,
    pic.email             as email,
    pic.gender            as gender
from patients_in_clinics  as pic;

drop view view_patients_as_staff;
set role postgres;

ALTER TABLE patients_in_clinics
ADD COLUMN "adder_role" e_staff_role NOT NULL CHECK ("adder_role" = 'Doctor'::e_staff_role),
ADD UNIQUE ("patient_id", "clinic_id", "added_by"),
ADD UNIQUE ("patient_id", "clinic_id"),
ADD FOREIGN KEY ("added_by", "adder_role", "clinic_id") REFERENCES staffs_in_clinics("staff_id", "staff_role", "clinic_id");


ALTER TABLE patients_in_clinics
DROP CONSTRAINT patients_in_clinics_patient_id_clinic_id_key,
ADD CONSTRAINT patients_in_clinics_patient_id_clinic_id_added_by_key
    UNIQUE ("patient_id", "clinic_id", "added_by");
