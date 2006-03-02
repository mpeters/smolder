SET FOREIGN_KEY_CHECKS=0;
CREATE TABLE project_category (
    project             INT UNSIGNED NOT NULL, 
    category            VARCHAR(255) NOT NULL DEFAULT '',
    CONSTRAINT `fk_project_category_project` FOREIGN KEY (`project`) REFERENCES `project` (`id`) ON DELETE CASCADE,
    INDEX `i_project_category_category` (category),
    PRIMARY KEY `i_project_category` (project, category)
) TYPE=InnoDB;

