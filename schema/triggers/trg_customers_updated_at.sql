--liquibase formatted sql

-- CREATE OR REPLACE TRIGGER needs Postgres 14+.
--changeset rkkoranteng:create-trigger-customers-updated-at runOnChange:true
--comment: Stamps customers.updated_at on every update
CREATE OR REPLACE TRIGGER trg_customers_updated_at
    BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
--rollback DROP TRIGGER trg_customers_updated_at ON customers;
