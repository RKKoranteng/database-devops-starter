--liquibase formatted sql

-- Sample used by test-lint.sh: must lint clean with risk-level=low. Never deployed.

--changeset sample:safe-create-table
CREATE TABLE sample_payments (
    payment_id bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id   bigint        NOT NULL REFERENCES orders (order_id),
    amount     numeric(12,2) NOT NULL,
    created_at timestamptz   NOT NULL DEFAULT now()
);
--rollback DROP TABLE sample_payments;

--changeset sample:safe-index runInTransaction:false
CREATE INDEX CONCURRENTLY idx_sample_payments_order_id ON sample_payments (order_id);
--rollback DROP INDEX CONCURRENTLY idx_sample_payments_order_id;
