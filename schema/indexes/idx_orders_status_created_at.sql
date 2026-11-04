--liquibase formatted sql

-- CONCURRENTLY builds the index without blocking writes, and cannot run inside a transaction.
--changeset rkkoranteng:create-index-orders-status-created-at runInTransaction:false
--comment: Supports queries that list orders by status, newest first
CREATE INDEX CONCURRENTLY idx_orders_status_created_at ON orders (status, created_at DESC);
--rollback DROP INDEX CONCURRENTLY idx_orders_status_created_at;
