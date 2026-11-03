--liquibase formatted sql

--changeset rkkoranteng:create-table-orders
--comment: Sample table of orders placed by customers
CREATE TABLE orders (
    order_id     bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  bigint        NOT NULL REFERENCES customers (customer_id),
    status       text          NOT NULL DEFAULT 'pending'
                               CHECK (status IN ('pending', 'paid', 'shipped', 'cancelled')),
    total_amount numeric(12,2) NOT NULL CHECK (total_amount >= 0),
    created_at   timestamptz   NOT NULL DEFAULT now(),
    updated_at   timestamptz   NOT NULL DEFAULT now()
);
--rollback DROP TABLE orders;
