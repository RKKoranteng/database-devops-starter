--liquibase formatted sql

--changeset rkkoranteng:create-owner-role
--comment: Login role that owns the application database. Skipped if the role already exists.
--preconditions onFail:MARK_RAN
--precondition-sql-check expectedResult:0 SELECT count(*) FROM pg_roles WHERE rolname = '${db_owner}'
CREATE ROLE ${db_owner} WITH LOGIN PASSWORD '${owner_password}';
--rollback empty
