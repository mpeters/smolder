-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Mon Mar  6 20:46:06 2006
-- 
BEGIN TRANSACTION;

--
-- Table: db_version
--
CREATE TABLE db_version (
  db_version VARCHAR(255) NOT NULL DEFAULT ''
);

COMMIT;
