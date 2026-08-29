-- Active: 1778842009804@@127.0.0.1@5432@cliniqo
CREATE TYPE e_working_days AS ENUM ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
 'Saturday', 'Sunday');

CREATE TABLE lookup_days(
    id SMALLSERIAL CHECK (id <= 7),
    day e_working_days NOT NULL
);

CREATE TABLE IF NOT EXISTS doctors_schedule (
    "schedule_id"       SERIAL,
    "doctor_id"         UUID NOT NULL,   
    "clinic_id"         clinic_id NOT NULL,
    "doctor_role"       e_staff_role NOT NULL CHECK (doctor_role = 'Doctor'::e_staff_role),
    "time_shift_starts" TIME(0) NOT NULL CHECK (EXTRACT(SECOND FROM "time_shift_starts") = 0),
    "day_shift_starts"  e_working_days NOT NULL,
    "time_shift_ends"   TIME(0) NOT NULL CHECK (EXTRACT(SECOND FROM "time_shift_ends") = 0),
    "day_shift_ends"    e_working_days NOT NULL GENERATED ALWAYS AS (
                            e_D("time_shift_starts", "day_shift_starts", "time_shift_ends")
                        ) STORED,
    "is_deleted"        BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY ("schedule_id"),
    FOREIGN KEY ("doctor_id", "doctor_role") REFERENCES staffs_in_clinics("staff_id", "staff_role") 
    ON DELETE CASCADE
    
);

-- Shift 1: Monday 08:00–16:00 (same day)
INSERT INTO doctors_schedule 
    (doctor_id, doctor_role, clinic_id, time_shift_starts, day_shift_starts, time_shift_ends)
VALUES 
    ('019f8cbb-caf8-7fb4-99e4-88421e1167c2', 'Doctor', '019f8cc7-dac4-7568-ae80-c74982b31409', '08:00', 'Monday', '16:00');

-- Shift 2: Monday 22:00–Tuesday 06:00 (crosse midnight)
INSERT INTO doctors_schedule 
    (doctor_id, doctor_role, clinic_id, time_shift_starts, day_shift_starts, time_shift_ends)
VALUES 
    ('019f8cbb-caf8-7fb4-99e4-88421e1167c2', 'Doctor', '019f8cc7-dac4-7568-ae80-c74982b31409', '22:00', 'Monday', '06:00');

select * from doctors_schedule;

select * from patients_in_clinics;

ALTER TABLE doctors_schedule 
ALTER COLUMN "day_shift_ends" SET NOT NULL;
ALTER TABLE doctors_schedule
ADD CONSTRAINT uq_doctors_schedule_doctor_id_schedule_id UNIQUE (doctor_id, schedule_id);

ALTER TABLE doctors_schedule
ADD COLUMN clinic_id UUID NOT NULL,

DROP CONSTRAINT doctors_schedule_doctor_id_doctor_role_fkey,
ADD CONSTRAINT doctors_schedule_doctor_id_doctor_role_clinic_id_fkey
    FOREIGN KEY (doctor_id, doctor_role, clinic_id)
    REFERENCES staffs_in_clinics(staff_id, staff_role, clinic_id)
    ON DELETE CASCADE;

CREATE OR REPLACE FUNCTION e_D(
    shift_start TIME, starting_day E_working_days, 
    shift_ends TIME
) RETURNS E_working_days AS $$
DECLARE
    ending_day       e_working_days;
    starting_day_id  SMALLINT       := (SELECT id FROM lookup_days WHERE day = starting_day);
    s_time           TIME           := shift_start::TIME;
    e_time           TIME           := shift_ends::TIME;
BEGIN


    if e_time < s_time then

        if starting_day_id = 7 then
            starting_day_id := 0;
        end if;

        SELECT day INTO ending_day FROM lookup_days
        WHERE id = starting_day_id+1;

    elseif e_time > s_time then
        ending_day := starting_day;

        RAISE NOTICE 'ending day %', ending_day;
    
    end if;

    if ending_day is NULL
        then raise exception 'ending day is null';
    end if;
    
    RETURN ending_day;
END;
    
$$ LANGUAGE plpgsql IMMUTABLE;

