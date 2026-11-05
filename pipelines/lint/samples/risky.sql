--liquibase formatted sql

-- Sample used by test-lint.sh: follows policy, but every changeset must be flagged
-- and the file must come out risk-level=high. Never deployed.

--changeset sample:risky-drop-table
DROP TABLE sample_archive;
--rollback CREATE TABLE sample_archive (archive_id bigint);

--changeset sample:risky-drop-column
ALTER TABLE orders DROP COLUMN status;
--rollback ALTER TABLE orders ADD COLUMN status text;

--changeset sample:risky-change-column-type
ALTER TABLE orders ALTER COLUMN total_amount TYPE numeric(14,2);
--rollback ALTER TABLE orders ALTER COLUMN total_amount TYPE numeric(12,2);

--changeset sample:risky-set-not-null
ALTER TABLE customers
    ALTER COLUMN full_name SET NOT NULL;
--rollback ALTER TABLE customers ALTER COLUMN full_name DROP NOT NULL;

--changeset sample:risky-validating-constraint
ALTER TABLE orders ADD CONSTRAINT chk_orders_total_positive CHECK (total_amount > 0);
--rollback ALTER TABLE orders DROP CONSTRAINT chk_orders_total_positive;

--changeset sample:risky-unique-constraint
ALTER TABLE customers ADD CONSTRAINT uq_customers_full_name UNIQUE (full_name);
--rollback ALTER TABLE customers DROP CONSTRAINT uq_customers_full_name;

--changeset sample:risky-blocking-index
CREATE INDEX idx_orders_total_amount ON orders (total_amount);
--rollback DROP INDEX idx_orders_total_amount;

--changeset sample:risky-unindexed-foreign-key
ALTER TABLE orders ADD COLUMN referred_by bigint REFERENCES customers (customer_id);
--rollback ALTER TABLE orders DROP COLUMN referred_by;
