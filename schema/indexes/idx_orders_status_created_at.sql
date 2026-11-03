--liquibase formatted sql

--changeset rkkoranteng:create-index-orders-status-created-at
--comment: Supports queries that list orders by status, newest first
CREATE INDEX idx_orders_status_created_at ON orders (status, created_at DESC);
--rollback DROP INDEX idx_orders_status_created_at;
