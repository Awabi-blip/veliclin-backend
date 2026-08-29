-- Active: 1778842009804@@127.0.0.1@5432@cliniqo
CREATE OR REPLACE FUNCTION f()
RETURNS TRIGGER AS $$
DECLARE
    ds  SMALLINT :=  (SELECT id FROM lookup_days WHERE day = NEW.day_shift_starts);
    de  SMALLINT :=  (SELECT id FROM lookup_days WHERE day = NEW.day_shift_ends);
BEGIN

    RAISE NOTICE 'ds: %, de: %', ds, de;

    if de = 1 and ds != 1 --if start day is monday and end day is not monday only then wrap
    	then de := 8;
    end if;

    RAISE NOTICE 'de after wrap check: %', de;

    if de - ds not in (0,1) or then
        RAISE NOTICE 'FAIL — spans more than 1 day: de - ds = %', de - ds;
        raise exception '';
    end if;  

    RAISE NOTICE 'span check passed';

    if NEW.day_shift_starts != NEW.day_shift_ends then

        RAISE NOTICE 'rollover detected — checking overlap';
        
        --day_shift_starts = Monday
        --day_shift_ends   = Tuesday

        if exists (SELECT 1 FROM doctors_schedule WHERE
            doctor_id = NEW.doctor_id
            AND schedule_id != NEW.schedule_id
            AND (
            
            --checking if an existing record for tuesday exists
            --where tuesday is the starting day
            (
            (day_shift_starts = NEW.day_shift_ends
            --this would check if there is a trailing day creeping INTO
            --another day
            --like if there is a meeting thats starting at 3am on tuesday
            --so a previously coming meeting that starts on monday lets say 11pm to 4am,
            --it doesnt overlap
            AND ('00:00:00'::TIME, time_shift_ends)
            OVERLAPS 
            ('00:00:00'::TIME, NEW.time_shift_ends))
            OR
            -- now check for the starting day, if there is an OVERLAPS
            -- betwen start and end time and this time
            (day_shift_starts = NEW.day_shift_starts
            AND day_shift_ends = day_shift_starts
            
            --so what this would check now

            AND (time_shift_starts, time_shift_ends::TIME)
            OVERLAPS
            (NEW.time_shift_starts, '23:59:00'::TIME))

            --lets say Monday has a timing started at 2pm, and ends at 7pm
            --if the newly added timing is not overlapping with the 2pm to 7pm period
            OR 
            ((day_shift_starts = NEW.day_shift_starts
            AND day_shift_starts != day_shift_ends)
            AND (time_shift_starts, '23:59:00'::TIME)
            OVERLAPS
            (NEW.time_shift_starts, '23:59:00'::TIME))

        ))
        ) then 
            RAISE NOTICE 'FAIL — overlap found';
            raise exception 'no';
        end if;

    elseif NEW.day_shift_starts = NEW.day_shift_ends then
        if exists (SELECT 1 FROM doctors_schedule WHERE
            doctor_id = NEW.doctor_id
            AND schedule_id != NEW.schedule_id
            AND(
            day_shift_starts = NEW.day_shift_starts
            AND day_shift_ends = NEW.day_shift_ends
            AND (time_shift_starts, time_shift_ends)
            OVERLAPS (
            NEW.time_shift_starts, NEW.time_shift_ends)
            
            --when there exists a 
            --record like where there ends a shift on tuesday 2am but starts on monday
            --and you try to add something like tuesday 1am to 3am
            OR 
            (day_shift_ends = NEW.day_shift_ends
            AND ('00:00:00'::TIME, time_shift_ends)
            OVERLAPS
            ('00:00:00'::TIME, NEW.time_shift_ends))


            --when there exista a record 
            --like there starts a shift on monday 7pm that ends on tuesday
            --but u try to add something like money 7pm to pm
            OR 
            (day_shift_ends != day_shift_starts
            AND (time_shift_starts, '23:59:00'::TIME )
            OVERLAPS
            (NEW.time_shift_starts, NEW.time_shift_ends)
            )
            ))
 
        then 
            raise exception 'no';
        end if;
    
    end if;

    RETURN NEW;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_doctors_schedule
AFTER UPDATE ON doctors_schedule
FOR EACH ROW
WHEN (
    OLD.doctor_id           IS DISTINCT FROM NEW.doctor_id          OR
    OLD.time_shift_starts   IS DISTINCT FROM NEW.time_shift_starts  OR
    OLD.day_shift_starts    IS DISTINCT FROM NEW.day_shift_starts   OR
    OLD.time_shift_ends     IS DISTINCT FROM NEW.time_shift_ends
)
EXECUTE FUNCTION f();

CREATE TRIGGER trg_doctors_schedule_insert
AFTER INSERT ON doctors_schedule
FOR EACH ROW
EXECUTE FUNCTION f();

INSERT INTO doctors_schedule (doctor_id, doctor_role, time_shift_starts, day_shift_starts, time_shift_ends)
VALUES ('019e4f5c-1995-72de-9ed3-09208984b11a', 'Doctor', '23:00:00', 'Monday', '01:00:00');

INSERT INTO doctors_schedule (doctor_id, doctor_role, time_shift_starts, day_shift_starts, time_shift_ends)
VALUES ('019e4f5c-1995-72de-9ed3-09208984b11a', 'Doctor', '08:00:00', 'Wednesday', '16:00:00');

INSERT INTO doctors_schedule (doctor_id, doctor_role, time_shift_starts, day_shift_starts, time_shift_ends)
VALUES ('019e4f5c-1995-72de-9ed3-09208984b11a', 'Doctor', '22:30:00', 'Monday', '03:00:00');


-- this didnt work, so perfect
INSERT INTO doctors_schedule (doctor_id, doctor_role, time_shift_starts, day_shift_starts, time_shift_ends)
VALUES ('019e4f5c-1995-72de-9ed3-09208984b11a', 'Doctor', '00:00:00', 'Tuesday'::e_working_days, '00:30:00');

--its rainin its not working wohoo
INSERT INTO doctors_schedule (doctor_id, doctor_role, time_shift_starts, day_shift_starts, time_shift_ends)
VALUES ('019e4f5c-1995-72de-9ed3-09208984b11a', 'Doctor', '15:00:00', 'Wednesday'::e_working_days, '02:00:00');

SELECT (
  '00:00:00'::TIME,
  '01:00:00'::TIME
)
OVERLAPS
(
  '00:00:00'::TIME,
  '00:30:00'::TIME
) AS overlapsornot;