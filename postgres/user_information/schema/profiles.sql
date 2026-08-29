CREATE TYPE e_gender AS ENUM ('Male', 'Female');


CREATE TABLE IF NOT EXISTS profiles(
    id UUID,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    gender e_gender NOT NULL,
    DoB DATE NOT NULL,
    PRIMARY KEY(id),
    FOREIGN KEY(id) REFERENCES app_users(id) ON DELETE CASCADE
);

--to check or not to check user > 18 years old(TODO if approved)
CREATE OR REPLACE FUNCTION check_user_is_adult(
)
RETURNS TRIGGER AS $$
DECLARE
BEGIN
    
    IF EXTRACT(YEAR FROM AGE(NEW.DoB::DATE)) < 18 THEN
        RAISE EXCEPTION 'user is not an adult';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_user_age 
BEFORE UPDATE OR INSERT 
ON profiles
FOR EACH ROW
EXECUTE FUNCTION check_user_is_adult();
