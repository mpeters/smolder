--
-- Just set the version number for the database. 
-- This is used during upgrades since not every
-- smolder upgrade will involve a schema change.
--
CREATE TABLE db_version (
  db_version TEXT NOT NULL DEFAULT ''
);
