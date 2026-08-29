-- Active: 1778842009804@@127.0.0.1@5432@cliniqo
CREATE TABLE IF NOT EXISTS patient_prescriptions(
    "id" BIGSERIAL,
    "appointment_id" BIGSERIAL,
    "patient_id" UUID NOT NULL,
    "patient_clinic_id" UUID,
    "doctor_id" UUID NOT NULL,
    "doctor_role" e_staff_role CHECK ("doctor_role" = 'Doctor'::e_staff_role),
    "doctor_clinic_id" UUID,
    "medication" TEXT NOT NULL,
    "potency" TEXT NOT NULL, -- i.e 500mg or any other unit
    "frequency" TEXT NOT NULL, -- 2 times a day etc
    "start_date" DATE NOT NULL DEFAULT CURRENT_DATE,
    "end_date" DATE NOT NULL, -- to get end date of a prescription, use start_date + days
    "metadata" JSONB,
    CHECK ("patient_clinic_id" = "doctor_clinic_id"),
    PRIMARY KEY ("id"),
    FOREIGN KEY ("patient_id", "patient_clinic_id") REFERENCES patients_in_clinics ("patient_id", "clinic_id") ON DELETE CASCADE,
    FOREIGN KEY ("doctor_id", "doctor_role", "doctor_clinic_id") REFERENCES staffs_in_clinics("staff_id", "staff_role", "clinic_id"),
    FOREIGN KEY ("appointment_id") REFERENCES appointments("appointment_id")
);
CREATE VIEW view_prescriptions
with (security_invoker = true) AS
SELECT 
pp.id as prescription_id,
CONCAT(pic.first_name, ' ', pic.last_name) AS patient_name,
CONCAT(profiles.first_name, ' ', profiles.last_name) AS doctor_name,
pp.medication AS medication,
pp.potency AS potency, 
pp.frequency AS frequency,
pp.start_date AS start_date, 
pp.end_date AS end_date, 
pp.metadata AS meta_data
FROM patients_in_clinics as pic
JOIN staffs_in_clinics as dic
ON pic.clinic_id = dic.clinic_id
JOIN patient_prescriptions as pp
ON pic.patient_id = pp.patient_id AND dic.staff_id = pp.doctor_id
JOIN profiles 
ON profiles.id = dic.staff_id;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app;



--create a trigger to ensure 
--that end date is greater than start date
CREATE OR REPLACE FUNCTION check_prescription_dates()
RETURNS TRIGGER AS $$
BEGIN
    if NEW.end_date <= NEW.start_date then
        raise exception 'end_date (%) must be greater than start_date (%)', NEW.end_date, NEW.start_date;
    end if;

    return NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_prescription_dates
BEFORE INSERT OR UPDATE ON patient_prescriptions
FOR EACH ROW
EXECUTE FUNCTION check_prescription_dates();

CREATE OR REPLACE FUNCTION check_active_prescriptions()
RETURNS TRIGGER AS $$
DECLARE
    active_count INT;
BEGIN
    SELECT COUNT(1) INTO active_count
    FROM patient_prescriptions
    WHERE patient_id = NEW.patient_id
      AND end_date > CURRENT_DATE;
    
    if active_count >= 5 then
        raise exception 'Patient % already has 5 active prescriptions', NEW.patient_id;
    end if;

    return NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_active_prescriptions
BEFORE INSERT ON patient_prescriptions
FOR EACH ROW
EXECUTE FUNCTION check_active_prescriptions();



-- ✅ valid insert
insert into patient_prescriptions 
    (appointment_id, patient_id, patient_clinic_id, doctor_id, doctor_role, doctor_clinic_id, medication, potency, frequency, start_date, end_date)
values 
    (1, '019e617d-6349-7f7d-b585-c3985c711483', '019e5587-ae16-7a31-b5fb-a6f8d081876e', '019e4f5c-1995-72de-9ed3-09208984b11a', 'Doctor'::e_staff_role, '019e5587-ae16-7a31-b5fb-a6f8d081876e', 'Paracetamol', '500mg', 'twice a day', CURRENT_DATE, CURRENT_DATE + 7);


-- ❌ end_date = start_date
insert into patient_prescriptions 
    (appointment_id, patient_id, patient_clinic_id, doctor_id, doctor_role, doctor_clinic_id, medication, potency, frequency, start_date, end_date)
values 
    (1, '019e617d-6349-7f7d-b585-c3985c711483', '019e5587-ae16-7a31-b5fb-a6f8d081876e', '019e4f5c-1995-72de-9ed3-09208984b11a', 'Doctor'::e_staff_role, '019e5587-ae16-7a31-b5fb-a6f8d081876e', 'Paracetamol', '500mg', 'twice a day', CURRENT_DATE, CURRENT_DATE);


-- ❌ end_date before start_date
insert into patient_prescriptions 
    (appointment_id, patient_id, patient_clinic_id, doctor_id, doctor_role, doctor_clinic_id, medication, potency, frequency, start_date, end_date)
values 
    (1, '019e617d-6349-7f7d-b585-c3985c711483', '019e5587-ae16-7a31-b5fb-a6f8d081876e', '019e4f5c-1995-72de-9ed3-09208984b11a', 'Doctor'::e_staff_role, '019e5587-ae16-7a31-b5fb-a6f8d081876e', 'Paracetamol', '500mg', 'twice a day', CURRENT_DATE, CURRENT_DATE - 1);


-- ❌ update moving end_date before start_date
update patient_prescriptions
set end_date = CURRENT_DATE - 1
where id = 1;


-- ❌ clinic mismatch
insert into patient_prescriptions 
    (appointment_id, patient_id, patient_clinic_id, doctor_id, doctor_role, doctor_clinic_id, medication, potency, frequency, start_date, end_date)
values 
    (1, '019e617d-6349-7f7d-b585-c3985c711483', '019e5587-ae16-7a31-b5fb-a6f8d081876e', '019e4f5c-1995-72de-9ed3-09208984b11a', 'Doctor'::e_staff_role, '00000000-0000-0000-0000-000000000000', 'Paracetamol', '500mg', 'twice a day', CURRENT_DATE, CURRENT_DATE + 7);


-- ❌ 6th active prescription — run valid insert 5 times first with appointment_ids 1-5, then:
insert into patient_prescriptions 
    (appointment_id, patient_id, patient_clinic_id, doctor_id, doctor_role, doctor_clinic_id, medication, potency, frequency, start_date, end_date)
values 
    (6, '019e617d-6349-7f7d-b585-c3985c711483', '019e5587-ae16-7a31-b5fb-a6f8d081876e', '019e4f5c-1995-72de-9ed3-09208984b11a', 'Doctor'::e_staff_role, '019e5587-ae16-7a31-b5fb-a6f8d081876e', 'Amoxicillin', '250mg', 'three times a day', CURRENT_DATE, CURRENT_DATE + 5);

DO $$
DECLARE
    v RECORD;
BEGIN
    FOR v IN
        SELECT
            n.nspname AS schema_name,
            c.relname AS view_name
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind = 'v'
          AND c.reloptions @> ARRAY['security_invoker=true']
          AND n.nspname NOT IN ('pg_catalog', 'information_schema')
          AND n.nspname NOT LIKE 'pg_toast%'
    LOOP
        RAISE NOTICE 'Updating %.%', v.schema_name, v.view_name;

        EXECUTE format(
            'ALTER VIEW %I.%I SET (security_invoker = false)',
            v.schema_name,
            v.view_name
        );
    END LOOP;
END
$$;