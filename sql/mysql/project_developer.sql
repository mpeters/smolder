--
-- Which developers are assigned to which projects
-- and what are their project specific preferences
--
SET FOREIGN_KEY_CHECKS=0;
CREATE TABLE project_developer (
    project     INT UNSIGNED NOT NULL, 
    developer   INT UNSIGNED NOT NULL,
    preference  INT UNSIGNED NOT NULL,
    admin       BOOL NOT NULL DEFAULT 0,
    added       DATETIME NOT NULL,
    PRIMARY KEY (project, developer),
    INDEX i_developer (developer),
    INDEX i_project (project),
    INDEX i_preference (preference),
    CONSTRAINT `fk_project_developer_project` FOREIGN KEY (`project`) REFERENCES `project` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_project_developer_developer` FOREIGN KEY (`developer`) REFERENCES `developer` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_project_developer_preference` FOREIGN KEY (`preference`) REFERENCES `preference` (`id`)
) TYPE=InnoDB;

