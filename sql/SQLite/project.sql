-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Mon Mar  6 20:46:13 2006
-- 
BEGIN TRANSACTION;

--
-- Table: project
--
CREATE TABLE project (
  id INTEGER PRIMARY KEY NOT NULL,
  name VARCHAR(255) NOT NULL DEFAULT '',
  start_date DATETIME,
  public BOOL NOT NULL DEFAULT '1',
  default_platform VARCHAR(255) NOT NULL DEFAULT '',
  default_arch VARCHAR(255) NOT NULL DEFAULT '',
  allow_anon BOOL NOT NULL DEFAULT '0'
);

CREATE UNIQUE INDEX i_project_name_project on project (name);
COMMIT;
