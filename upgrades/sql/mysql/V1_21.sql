ALTER TABLE smoke_report DROP COLUMN category;
DROP TABLE project_category;

CREATE TABLE smoke_report_tag  (
    id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    smoke_report    INT UNSIGNED NOT NULL,
    tag             VARCHAR(255) DEFAULT '',
    INDEX i_project_smoke_tag_tag (tag),
    CONSTRAINT `fk_smoke_report_tag_smoke_report` FOREIGN KEY (`smoke_report`) REFERENCES `smoke_report` (`id`) ON DELETE CASCADE
);
INSERT INTO smoke_report_tag (smoke_report, tag) SELECT id, category FROM smoke_report;
DELETE FROM smoke_report_tag WHERE tag IS NULL;
