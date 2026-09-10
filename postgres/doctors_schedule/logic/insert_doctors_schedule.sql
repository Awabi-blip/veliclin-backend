-- staff can add doctor schedule given they are in the same clinic.


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



