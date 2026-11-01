CREATE INDEX idx_clinics_for_rls ON clinics (
    clinic_id
);

CREATE INDEX idx_pic_for_rls ON staff_in_clinics (
    clinic_id, staff_id, staff_role
) WHERE is_active = TRUE;

