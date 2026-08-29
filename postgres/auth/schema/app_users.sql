-- Active: 1778842009804@@127.0.0.1@5432@cliniqo@public

CREATE TABLE IF NOT EXISTS app_users(
    "id" UUID DEFAULT gen_v7_uuid(),
    "name" VARCHAR(255) NOT NULL,
    "email" CITEXT UNIQUE NOT NULL,
    "onboarded" BOOLEAN DEFAULT FALSE NOT NULL,
    "clerk_sub" TEXT UNIQUE NOT NULL,
    PRIMARY KEY ("id"),
    UNIQUE (id, email)
);

select * from app_users;


ALTER TABLE app_users
ADD COLUMN clerk_sub TEXT UNIQUE;

ALTER TABLE app_users
ADD CONSTRAINT valid_email CHECK (email ~* '^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');

ALTER TABLE app_users ADD CONSTRAINT app_users_id_email_unique UNIQUE (id, email);

SELECT id FROM profiles ORDER BY id DESC LIMIT 10;

SELECT column_name, column_default
FROM information_schema.columns
WHERE table_name = 'profiles'
  AND column_name = 'id';