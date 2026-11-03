--liquibase formatted sql

-- CREATE OR REPLACE TRIGGER needs Postgres 14+.
--changeset rkkoranteng:create-trigger-orders-updated-at runOnChange:true
--comment: Stamps orders.updated_at on every update
CREATE OR REPLACE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
--rollback DROP TRIGGER trg_orders_updated_at ON orders;
