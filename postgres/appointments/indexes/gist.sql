ALTER TABLE appointments 
ADD CONSTRAINT no_overlapping_appointments_doctors
EXCLUDE USING gist
(
    doctor_id WITH =,
    tstzrange(scheduled_at, ends_at) WITH &&
) WHERE (status IN ('Scheduled', 'On_going'));

ALTER TABLE appointments
ADD CONSTRAINT no_overlapping_appointments_patients
EXCLUDE USING gist
(
    patient_id WITH =,
    tstzrange(scheduled_at, ends_at) WITH &&
) WHERE (status IN ('Scheduled', 'On_going'));