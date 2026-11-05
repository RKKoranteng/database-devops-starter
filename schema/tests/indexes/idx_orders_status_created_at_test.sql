-- Tests for index idx_orders_status_created_at.
-- Runs in a transaction that is rolled back afterwards. The test fails if any statement errors.

DO $$
BEGIN
    -- A CREATE INDEX CONCURRENTLY that fails part way leaves an invalid index behind.
    IF NOT EXISTS (
        SELECT 1 FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
        WHERE c.relname = 'idx_orders_status_created_at' AND i.indisvalid
    ) THEN
        RAISE EXCEPTION 'idx_orders_status_created_at is missing or invalid';
    END IF;
END $$;
