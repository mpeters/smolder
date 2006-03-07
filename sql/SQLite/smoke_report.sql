-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Mon Mar  6 20:46:19 2006
-- 
BEGIN TRANSACTION;

--
-- Table: smoke_report
--
CREATE TABLE smoke_report (
  id INTEGER PRIMARY KEY NOT NULL,
  project int(11) NOT NULL,
  developer int(11) NOT NULL,
  added DATETIME NOT NULL,
  architecture VARCHAR(255) NOT NULL DEFAULT '',
  platform VARCHAR(255) NOT NULL DEFAULT '',
  pass int(11) NOT NULL DEFAULT '0',
  fail int(11) NOT NULL DEFAULT '0',
  skip int(11) NOT NULL DEFAULT '0',
  todo int(11) NOT NULL DEFAULT '0',
  test_files int(11) NOT NULL DEFAULT '0',
  total int(11) NOT NULL DEFAULT '0',
  format ENUM(4) NOT NULL DEFAULT 'XML',
  comments BLOB(65535) NOT NULL DEFAULT '',
  invalid BOOL NOT NULL DEFAULT '0',
  invalid_reason BLOB(65535) NOT NULL DEFAULT '',
  html_file VARCHAR(255),
  duration int(11) NOT NULL DEFAULT '0',
  category VARCHAR(255) DEFAULT NULL
);

CREATE INDEX i_project_smoke_report on smoke_report (project);
CREATE INDEX i_developer_smoke_report on smoke_report (developer);
CREATE INDEX i_category_smoke_report on smoke_report (category);
CREATE INDEX i_project_category_smoke_repor on smoke_report (project, category);
COMMIT;
