--
-- The list of registered developers (or users) or Smolder.
-- They have a default 'preference' but are also associated
-- with a project and a project specific preference via the
-- project_developer table
--
SET FOREIGN_KEY_CHECKS=0;
CREATE TABLE developer (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, 
    username    VARCHAR(255) NOT NULL DEFAULT '', 
    fname       VARCHAR(255) NOT NULL DEFAULT '',
    lname       VARCHAR(255) NOT NULL DEFAULT '',
    email       VARCHAR(255) NOT NULL DEFAULT '',
    password    VARCHAR(255) NOT NULL DEFAULT '',
    admin       BOOL NOT NULL DEFAULT 0,
    preference  INT UNSIGNED NOT NULL, 
    guest       BOOL NOT NULL DEFAULT 0,
    INDEX i_preference (preference), 
    UNIQUE KEY `unique_username` (username),
    CONSTRAINT `fk_developer_preference` FOREIGN KEY (`preference`) REFERENCES `preference` (`id`)
) TYPE=InnoDB;

