-- Tests for procedure place_order.
-- Runs in a transaction that is rolled back afterwards. The test fails if any statement errors.

INSERT INTO customers (email, full_name) VALUES ('test.place_order@example.com', 'Buyer');

DO $$
DECLARE
    cid bigint := (SELECT customer_id FROM customers WHERE email = 'test.place_order@example.com');
BEGIN
    -- creates a pending order for an existing customer
    CALL place_order(cid, 42.50);
    IF NOT EXISTS (
        SELECT 1 FROM orders WHERE customer_id = cid AND total_amount = 42.50 AND status = 'pending'
    ) THEN
        RAISE EXCEPTION 'place_order did not create a pending order';
    END IF;

    -- rejects a customer that doesn't exist, with its own error message
    BEGIN
        CALL place_order(-1, 10);
        RAISE EXCEPTION 'place_order accepted a missing customer';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM NOT LIKE 'customer % does not exist' THEN
            RAISE;
        END IF;
    END;
END $$;
