-- Tests for table customers.
-- Runs in a transaction that is rolled back afterwards. The test fails if any statement errors.

INSERT INTO customers (email, full_name) VALUES ('test.customers@example.com', 'First Customer');

DO $$
BEGIN
    -- email is unique
    BEGIN
        INSERT INTO customers (email, full_name) VALUES ('test.customers@example.com', 'Second Customer');
        RAISE EXCEPTION 'a duplicate email was accepted';
    EXCEPTION WHEN unique_violation THEN
        NULL;  -- expected
    END;

    -- timestamps are filled in by default
    IF (SELECT created_at IS NULL OR updated_at IS NULL
        FROM customers WHERE email = 'test.customers@example.com') THEN
        RAISE EXCEPTION 'created_at and updated_at were not set by default';
    END IF;
END $$;
