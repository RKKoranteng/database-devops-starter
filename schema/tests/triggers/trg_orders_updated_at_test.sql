-- Tests for trigger trg_orders_updated_at (and its function set_updated_at).
-- Runs in a transaction that is rolled back afterwards. The test fails if any statement errors.
-- now() is fixed within a transaction, so the row starts with an old updated_at to compare against.

INSERT INTO customers (email, full_name) VALUES ('test.trg_orders@example.com', 'Trigger Tester');

INSERT INTO orders (customer_id, total_amount, created_at, updated_at)
SELECT customer_id, 10, '2000-01-01', '2000-01-01'
FROM customers WHERE email = 'test.trg_orders@example.com';

UPDATE orders SET status = 'paid'
WHERE customer_id = (SELECT customer_id FROM customers WHERE email = 'test.trg_orders@example.com');

DO $$
BEGIN
    IF (SELECT o.updated_at FROM orders o JOIN customers c ON c.customer_id = o.customer_id
        WHERE c.email = 'test.trg_orders@example.com') <= '2000-01-01' THEN
        RAISE EXCEPTION 'trg_orders_updated_at did not set updated_at on update';
    END IF;
END $$;
