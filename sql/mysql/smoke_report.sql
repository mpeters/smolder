--
-- Individual smoke report uploaded for a project. Contains
-- summary information (pass, fail, skip, todo, test_files, total, etc)
-- even though they are contained in the actual XMl files stored for
-- each report. This allows for faster access to this summary info
--
SET FOREIGN_KEY_CHECKS=0;
CREATE TABLE smoke_report  (
    id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, 
    project         INT UNSIGNED NOT NULL, 
    developer       INT UNSIGNED NOT NULL, 
    added           DATETIME NOT NULL,
    architecture    VARCHAR(255) NOT NULL DEFAULT '',
    platform        VARCHAR(255) NOT NULL DEFAULT '',
    pass            INT UNSIGNED NOT NULL DEFAULT 0,
    fail            INT UNSIGNED NOT NULL DEFAULT 0,
    skip            INT UNSIGNED NOT NULL DEFAULT 0,
    todo            INT UNSIGNED NOT NULL DEFAULT 0,
    todo_pass       INT UNSIGNED NOT NULL DEFAULT 0,
    test_files      INT UNSIGNED NOT NULL DEFAULT 0,
    total           INT UNSIGNED NOT NULL DEFAULT 0,
    comments        BLOB NOT NULL DEFAULT '',
    invalid         BOOL NOT NULL DEFAULT 0,
    invalid_reason  BLOB NOT NULL DEFAULT '',
    duration        INT UNSIGNED NOT NULL DEFAULT 0,
    category        VARCHAR(255) DEFAULT NULL,
    purged          BOOLEAN NOT NULL DEFAULT 0,
    failed          BOOLEAN NOT NULL DEFAULT 0,
    INDEX i_project (project),
    INDEX i_developer (developer),
    INDEX i_category (category),
    INDEX i_project_category (project, category),
    CONSTRAINT `fk_smoke_report_project` FOREIGN KEY (`project`) REFERENCES `project` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_smoke_report_developer` FOREIGN KEY (`developer`) REFERENCES `developer` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_smoke_report_project_category` FOREIGN KEY (`project`, `category`) REFERENCES `project_category` (`project`, `category`) ON DELETE NO ACTION
) TYPE=InnoDB;

