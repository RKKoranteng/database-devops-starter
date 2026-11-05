-- Tests for trigger trg_customers_updated_at (and its function set_updated_at).
-- Runs in a transaction that is rolled back afterwards. The test fails if any statement errors.
-- now() is fixed within a transaction, so the row starts with an old updated_at to compare against.

INSERT INTO customers (email, full_name, created_at, updated_at)
VALUES ('test.trg_customers@example.com', 'Before', '2000-01-01', '2000-01-01');

UPDATE customers SET full_name = 'After' WHERE email = 'test.trg_customers@example.com';

DO $$
BEGIN
    IF (SELECT updated_at FROM customers WHERE email = 'test.trg_customers@example.com') <= '2000-01-01' THEN
        RAISE EXCEPTION 'trg_customers_updated_at did not set updated_at on update';
    END IF;
END $$;
