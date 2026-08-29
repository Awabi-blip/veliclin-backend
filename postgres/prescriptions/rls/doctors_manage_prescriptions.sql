create policy doctors_manage_prescriptions
on            patient_prescriptions
for all
using (
    doctor_id  = NULLIF(current_setting('myapp.user_id', true), '')::uuid

);