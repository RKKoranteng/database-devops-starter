--liquibase formatted sql

--changeset rkkoranteng:create-index-orders-customer-id
--comment: Foreign keys are not indexed automatically in Postgres; speeds up joins and lookups by customer
CREATE INDEX idx_orders_customer_id ON orders (customer_id);
--rollback DROP INDEX idx_orders_customer_id;
