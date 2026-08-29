## Schema Rules
- every table must have an RLS policy for SELECT
- those which have an Update, Delete in API code, must have an RLS policy
- the procedures I control, must use security definer functions, with proper auth flow (rls pattern in the procedure/function itself)

## Functions
- e_D() — figures out what day a shift ends on, handles midnight crossover
- f() — validates shift doesn't span more than 1 day, checks overlap on rollover day (trigger) (mostly works)

### appointments:
- add_appointments() — creates appointments in check with the doctor's schedules, invalidates if the appointment is out of bounds, or does not fit into the schedule.

- delete_appointment() — sets the said appointment's status to 
cancelled.

## Security
- create_appointment -> managers, doctors, receptionists 
- delete_appointment -> managers, doctors, receptionists 
- add_data  -> doctors
- add_patients -> doctors or staff, but under a doctors name.
- insert_doctors_schedule -> managers, doctors, receptionists
- delete_doctors_schedule -> managers, doctors, receptionists


### schedules:
- insert_doctors_schedule() — inserts data into doctors_schedule, 
transaction level isolation, accepts parameters in a frontend friendly order,
and inserts in sync with the table columns.
- delete_doctor_schedule() — Soft-deletes a doctor's schedule by setting is_deleted = TRUE, and cancels all appointments if p_delete_appointments is true, it also cancels all the associated appointments.

## Tables
- staffs_in_clinics — one staff member per clinic at a time
- doctors_schedule — shift schedule, day_shift_ends column is generated from e_D
...
