--liquibase formatted sql

-- Sample used by test-lint.sh: follows policy but must be flagged risk-level=high. Never deployed.

--changeset sample:risky-drop-column
ALTER TABLE orders DROP COLUMN status;
--rollback ALTER TABLE orders ADD COLUMN status text;

--changeset sample:risky-blocking-index
CREATE INDEX idx_orders_total_amount ON orders (total_amount);
--rollback DROP INDEX idx_orders_total_amount;

--changeset sample:risky-unindexed-foreign-key
ALTER TABLE orders ADD COLUMN referred_by bigint REFERENCES customers (customer_id);
--rollback ALTER TABLE orders DROP COLUMN referred_by;
