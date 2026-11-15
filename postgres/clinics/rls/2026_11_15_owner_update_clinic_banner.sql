-- Apply before deploying PATCH /clinics/{clinic_id}.
-- The HTTP handler only writes banner_url and checks the SessionCookie's owner flag,
-- clinic id, and the database owner id. RLS independently limits UPDATE to the owner.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'clinics'
          AND policyname = 'clinic_owner_update_banner'
    ) THEN
        CREATE POLICY clinic_owner_update_banner ON public.clinics
        FOR UPDATE
        USING (owner_id = NULLIF(current_setting('myapp.user_id', true), '')::uuid)
        WITH CHECK (owner_id = NULLIF(current_setting('myapp.user_id', true), '')::uuid);
    END IF;
END;
$$;

-- Keep column-scoped write privileges for installations using the app database role.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app') THEN
        GRANT UPDATE (banner_url) ON TABLE public.clinics TO app;
    END IF;
END;
$$;
