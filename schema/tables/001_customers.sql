--liquibase formatted sql

--changeset rkkoranteng:create-table-customers
--comment: Sample table of customers
CREATE TABLE customers (
    customer_id bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       text        NOT NULL UNIQUE,
    full_name   text        NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);
--rollback DROP TABLE customers;
