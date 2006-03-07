-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Mon Mar  6 20:46:17 2006
-- 
BEGIN TRANSACTION;

--
-- Table: project_developer
--
CREATE TABLE project_developer (
  project int(11) NOT NULL,
  developer int(11) NOT NULL,
  preference int(11) NOT NULL,
  admin BOOL NOT NULL DEFAULT '0',
  added DATETIME NOT NULL,
  PRIMARY KEY (project, developer)
);

CREATE INDEX i_developer_project_developer on project_developer (developer);
CREATE INDEX i_project_project_developer on project_developer (project);
CREATE INDEX i_preference_project_developer on project_developer (preference);
COMMIT;
