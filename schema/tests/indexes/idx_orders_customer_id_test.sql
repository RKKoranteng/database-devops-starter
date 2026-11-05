-- Tests for index idx_orders_customer_id.
-- Runs in a transaction that is rolled back afterwards. The test fails if any statement errors.

DO $$
BEGIN
    -- A CREATE INDEX CONCURRENTLY that fails part way leaves an invalid index behind.
    IF NOT EXISTS (
        SELECT 1 FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
        WHERE c.relname = 'idx_orders_customer_id' AND i.indisvalid
    ) THEN
        RAISE EXCEPTION 'idx_orders_customer_id is missing or invalid';
    END IF;
END $$;
