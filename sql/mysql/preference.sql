--
-- Developer's preferences. Linked to by the developer and
-- project_developer tables
--
SET FOREIGN_KEY_CHECKS=0;
CREATE TABLE preference (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, 
    email_type  ENUM ('full', 'summary', 'link') NOT NULL DEFAULT 'full',
    email_freq  ENUM ('on_new', 'on_fail', 'never') NOT NULL DEFAULT 'on_new',
    email_limit INT UNSIGNED NOT NULL DEFAULT 0,
    email_sent  INT UNSIGNED NOT NULL DEFAULT 0,
    email_sent_timestamp DATETIME
) TYPE=InnoDB;

