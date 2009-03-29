DROP TABLE project_category;

CREATE TABLE smoke_report_tag  (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    smoke_report    INTEGER NOT NULL,
    tag             TEXT DEFAULT '',
    CONSTRAINT 'fk_smoke_report_tag_smoke_report' FOREIGN KEY ('smoke_report') REFERENCES 'smoke_report' ('id') ON DELETE CASCADE
);
CREATE INDEX i_project_smoke_tag_tag ON smoke_report_tag (tag);
INSERT INTO smoke_report_tag (smoke_report, tag) SELECT id, category FROM smoke_report;
DELETE FROM smoke_report_tag WHERE tag IS NULL;

