--liquibase formatted sql

-- Sample used by test-lint.sh: breaks policy, so linting must fail. Never deployed.

--changeset sample:missing-rollback
ALTER TABLE customers ADD COLUMN phone text;

--changeset sample:concurrent-in-transaction
CREATE INDEX CONCURRENTLY idx_customers_phone ON customers (phone);
--rollback DROP INDEX CONCURRENTLY idx_customers_phone;
