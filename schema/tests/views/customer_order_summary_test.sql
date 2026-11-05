-- Tests for view customer_order_summary.
-- Runs in a transaction that is rolled back afterwards. The test fails if any statement errors.

INSERT INTO customers (email, full_name) VALUES
    ('test.summary.buyer@example.com', 'Buyer'),
    ('test.summary.browser@example.com', 'Browser');

INSERT INTO orders (customer_id, total_amount)
SELECT customer_id, amount
FROM customers, (VALUES (10.00), (5.50)) AS amounts (amount)
WHERE email = 'test.summary.buyer@example.com';

DO $$
DECLARE
    buyer   customer_order_summary;
    browser customer_order_summary;
BEGIN
    SELECT * INTO buyer FROM customer_order_summary WHERE email = 'test.summary.buyer@example.com';
    SELECT * INTO browser FROM customer_order_summary WHERE email = 'test.summary.browser@example.com';

    -- a customer with orders
    IF buyer.customer_id IS NULL THEN
        RAISE EXCEPTION 'a customer with orders is missing from the view';
    END IF;
    IF buyer.order_count <> 2 OR buyer.lifetime_value <> 15.50 OR buyer.last_order_at IS NULL THEN
        RAISE EXCEPTION 'wrong summary for a customer with orders: %', buyer;
    END IF;

    -- a customer with no orders still appears, with zeros
    IF browser.customer_id IS NULL THEN
        RAISE EXCEPTION 'a customer with no orders is missing from the view';
    END IF;
    IF browser.order_count <> 0 OR browser.lifetime_value <> 0 OR browser.last_order_at IS NOT NULL THEN
        RAISE EXCEPTION 'wrong summary for a customer with no orders: %', browser;
    END IF;
END $$;
