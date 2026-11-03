--liquibase formatted sql

-- splitStatements:false keeps the semicolons inside the plpgsql body from splitting the statement.
--changeset rkkoranteng:create-procedure-place-order runOnChange:true splitStatements:false
--comment: Creates a pending order for an existing customer
CREATE OR REPLACE PROCEDURE place_order(p_customer_id bigint, p_total_amount numeric)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = p_customer_id) THEN
        RAISE EXCEPTION 'customer % does not exist', p_customer_id;
    END IF;

    INSERT INTO orders (customer_id, total_amount)
    VALUES (p_customer_id, p_total_amount);
END;
$$;
--rollback DROP PROCEDURE place_order(bigint, numeric);
