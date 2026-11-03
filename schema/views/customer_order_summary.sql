--liquibase formatted sql

-- runOnChange: edit this file in place and Liquibase reapplies it on the next update.
--changeset rkkoranteng:create-view-customer-order-summary runOnChange:true
--comment: One row per customer with order count, lifetime value and last order date
CREATE OR REPLACE VIEW customer_order_summary AS
SELECT
    c.customer_id,
    c.email,
    count(o.order_id)                AS order_count,
    coalesce(sum(o.total_amount), 0) AS lifetime_value,
    max(o.created_at)                AS last_order_at
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.email;
--rollback DROP VIEW customer_order_summary;
