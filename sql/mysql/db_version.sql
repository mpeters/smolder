--
-- Just set the version number for the database. 
-- This is used during upgrades since not every
-- smolder upgrade will involve a schema change.
--
SET FOREIGN_KEY_CHECKS=0;
CREATE TABLE db_version (
  db_version VARCHAR(255) NOT NULL DEFAULT ''
) TYPE=InnoDB;

