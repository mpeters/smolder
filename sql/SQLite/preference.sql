-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Mon Mar  6 20:46:10 2006
-- 
BEGIN TRANSACTION;

--
-- Table: preference
--
CREATE TABLE preference (
  id INTEGER PRIMARY KEY NOT NULL,
  email_type ENUM(7) NOT NULL DEFAULT 'full',
  email_freq ENUM(7) NOT NULL DEFAULT 'on_new'
);

COMMIT;
