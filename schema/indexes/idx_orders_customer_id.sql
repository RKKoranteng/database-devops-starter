--liquibase formatted sql

-- CONCURRENTLY builds the index without blocking writes, and cannot run inside a transaction.
--changeset rkkoranteng:create-index-orders-customer-id runInTransaction:false
--comment: Foreign keys are not indexed automatically in Postgres; speeds up joins and lookups by customer
CREATE INDEX CONCURRENTLY idx_orders_customer_id ON orders (customer_id);
--rollback DROP INDEX CONCURRENTLY idx_orders_customer_id;
