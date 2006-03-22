--
-- Projects being looked after in this installation
--

SET FOREIGN_KEY_CHECKS=0;
CREATE TABLE project (
    id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, 
    name                VARCHAR(255) NOT NULL DEFAULT '',
    start_date          DATETIME NULL,
    public              BOOL NOT NULL DEFAULT 1,
    default_platform    VARCHAR(255) NOT NULL DEFAULT '',
    default_arch        VARCHAR(255) NOT NULL DEFAULT '',
    graph_start         ENUM('project', 'year', 'month', 'week', 'day') NOT NULL DEFAULT 'project',
    allow_anon          BOOL NOT NULL DEFAULT 0,
    UNIQUE KEY i_project_name (name)
) TYPE=InnoDB;

