SET FOREIGN_KEY_CHECKS=0;
CREATE TABLE preference (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, 
    email_type  ENUM ('full', 'summary', 'link') NOT NULL DEFAULT 'full',
    email_freq  ENUM ('on_new', 'on_fail', 'never') NOT NULL DEFAULT 'on_new'
) TYPE=InnoDB;

INSERT INTO preference (id) VALUES (1);

