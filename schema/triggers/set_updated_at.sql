--liquibase formatted sql

-- splitStatements:false keeps the semicolons inside the plpgsql body from splitting the statement.
--changeset rkkoranteng:create-function-set-updated-at runOnChange:true splitStatements:false
--comment: Trigger function that stamps updated_at on every row update
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;
--rollback DROP FUNCTION set_updated_at();
