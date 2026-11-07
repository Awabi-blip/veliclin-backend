-- Active: 1786733926332@@127.0.0.1@5433@veliclin_database
CREATE OR REPLACE FUNCTION f()
RETURNS TRIGGER AS $$
DECLARE
    ds  SMALLINT :=  (SELECT id FROM lookup_days WHERE day = NEW.day_shift_starts);
    de  SMALLINT :=  (SELECT id FROM lookup_days WHERE day = NEW.day_shift_ends);
BEGIN

    RAISE NOTICE 'ds: %, de: %', ds, de;

    if de = 1 and ds != 1
    	then de := 8;
    end if;

    --monday start and monday end is fine, but anything else, 
    --if monday is where ur appointment is ending then 
    --it must mean it would start on sunday
    -- if day_end is monday and day_start is sunday then 
    -- 8-7 works perfectly
    -- if day_end is sunday and day_start is saturday then 
    -- 7-6 works perfectly.

    if de - ds not in (0,1) then
        raise exception using 
        errcode = 'P2001', 
        message = 'Difference between day end and day start is zero or one';
    end if;  

    if NEW.day_shift_starts != NEW.day_shift_ends then
        
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
        raise exception using 
            errcode = 'P2001', 
            message = 'Appointment is outside of doctor''s schedule';
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
        raise exception using 
        errcode = 'P2001', 
        message = 'schedule out of sync with previous added schedules';
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



