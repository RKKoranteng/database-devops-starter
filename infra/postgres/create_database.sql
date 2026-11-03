--liquibase formatted sql

-- CREATE DATABASE cannot run inside a transaction block.
--changeset rkkoranteng:create-app-database runInTransaction:false
--comment: Application database owned by db_owner. Skipped if the database already exists.
--preconditions onFail:MARK_RAN
--precondition-sql-check expectedResult:0 SELECT count(*) FROM pg_database WHERE datname = '${db_name}'
CREATE DATABASE ${db_name} OWNER ${db_owner};
--rollback empty
