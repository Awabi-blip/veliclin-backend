CREATE UNIQUE INDEX unique_idx_doctor_patient_scheduled (
    doctor_id, patient_id
) WHERE status = 'Scheduled'::e_appointment_status;
