-- staff can add doctor schedule given they are in the same clinic.
select * from app_users;
set myapp.user_id = '01a1b57b-3e2b-7dbe-b5ce-4f6dfb4def7a';
call insert_doctors_schedule 
('01a1b57b-3e2b-7dbe-b5ce-4f6dfb4def7a'::UUID, 
'Tuesday'::e_working_days ,
'13:00:00',
 '17:00:00');

delete from doctors_schedule;

set role app;

select * from doctors_schedule;
select * from staffs_in_clinics join clinics on staffs_in_clinics.clinic_id = clinics.clinic_id;
CREATE OR REPLACE PROCEDURE insert_doctors_schedule(
    p_doctor_id UUID,
    p_day_shift_starts e_working_days,
    p_time_shift_starts TIME,
    p_time_shift_ends TIME
) AS $$ 
DECLARE
    -- fetches current_user_id
    v_staff_id  uuid := current_setting('myapp.user_id');

    --checks if the clinic exists, where the current_user who is v_staff_id
    --exists

    v_valid_clinic_id             uuid := (
            select clinic_id
            from   staffs_in_clinics
            where  staff_id   = v_staff_id
            and  staff_role in (
                'Doctor'::e_staff_role,
                'Manager'::e_staff_role,
                'Receptionist'::e_staff_role
            )
        );
    
    -- fetches the doctor_id
    v_valid_doctor_clinic_id    uuid := (
        select clinic_id
        from   staffs_in_clinics
        where  staff_id = p_doctor_id
    );
BEGIN


    if (v_valid_clinic_id) is null 
    or 
    (v_valid_doctor_clinic_id is null) then
        raise exception using 
        errcode = 'P2001',
        message =  'unauthorised/doctor not found';
    end if;

    if v_valid_doctor_clinic_id != v_valid_clinic_id then
        raise exception using 
        errcode = 'P2001',
        message = 'the doctor does not belong to yer clinic'; 
    end if;

    perform pg_advisory_xact_lock(hashtext(p_doctor_id::text));

    insert into doctors_schedule
    (  
        doctor_id,
        doctor_role,
        clinic_id,
        time_shift_starts,
        day_shift_starts,
        time_shift_ends
    ) values (
        p_doctor_id,
        'Doctor'::e_staff_role,
        v_valid_clinic_id,
        p_time_shift_starts,
        p_day_shift_starts,
        p_time_shift_ends
    );
END;
$$ LANGUAGE plpgsql;


create or replace function test_staff_schedule_ok()
returns setof text as $$
begin

    perform set_config('myapp.user_id', '01a1b57b-3e2b-7dbe-b5ce-4f6dfb4def7a', true)

    returns next lives_ok(
        $q$ call insert_doctors_schedule 
            ('01a1b57b-3e2b-7dbe-b5ce-4f6dfb4def7a'::UUID, 
            'Sunday'::e_working_days ,
            '8:00:00', -- 8am to 2pm
            '14:00:00');
        $q$,
            'Successfully added appointment for Zyn Khan from sunday 8am to 2pm.'
    );

    returns next throws_ok(
        $q$ call insert_doctors_schedule 
            ('01a1b57b-3e2b-7dbe-b5ce-4f6dfb4def7a'::UUID, 
            'Sunday'::e_working_days ,
            '10:00:00',
            '14:00:00')
        $q$,
            'P2001',
            'schedule out of sync with previous added schedules',
            'because the previous existence of an appointment from 8am to 2pm on sunday, this is rejected as it is on 3pm to 4pm'
    );

    returns next throws_ok(
        $q$ call insert_doctors_schedule 
            ('01a1b57b-3e2b-7dbe-b5ce-4f6dfb4def7a'::UUID, 
            'Saturday'::e_working_days ,
            '00:00:00',
            '09:00:00')
        $q$,
            'P2001',
            'schedule out of sync with previous added schedules',
            'because the previous existence of an appointment from 8am to 4pm on sunday, this is rejected as it starts on saturday 12am which is fine but ends at 9am which overlaps with another schedule.'
    );
    )


end;
$$ language plpgsql;