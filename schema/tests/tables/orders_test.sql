-- Tests for table orders.
-- Runs in a transaction that is rolled back afterwards. The test fails if any statement errors.

INSERT INTO customers (email, full_name) VALUES ('test.orders@example.com', 'Order Tester');

DO $$
DECLARE
    cid bigint := (SELECT customer_id FROM customers WHERE email = 'test.orders@example.com');
BEGIN
    -- new orders default to pending
    INSERT INTO orders (customer_id, total_amount) VALUES (cid, 10);
    IF (SELECT status FROM orders WHERE customer_id = cid) <> 'pending' THEN
        RAISE EXCEPTION 'a new order did not default to status pending';
    END IF;

    -- status must be one of the allowed values
    BEGIN
        INSERT INTO orders (customer_id, status, total_amount) VALUES (cid, 'lost', 10);
        RAISE EXCEPTION 'an invalid status was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;  -- expected
    END;

    -- total_amount can't be negative
    BEGIN
        INSERT INTO orders (customer_id, total_amount) VALUES (cid, -1);
        RAISE EXCEPTION 'a negative total_amount was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;  -- expected
    END;

    -- every order belongs to an existing customer
    BEGIN
        INSERT INTO orders (customer_id, total_amount) VALUES (-1, 10);
        RAISE EXCEPTION 'an order for a missing customer was accepted';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;  -- expected
    END;
END $$;
