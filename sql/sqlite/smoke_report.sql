CREATE TABLE smoke_report  (
    id              INTEGER PRIMARY KEY AUTOINCREMENT, 
    project         INTEGER NOT NULL, 
    developer       INTEGER NOT NULL, 
    added           INTEGER NOT NULL,
    architecture    TEXT DEFAULT '',
    platform        TEXT DEFAULT '',
    pass            INTEGER DEFAULT 0,
    fail            INTEGER DEFAULT 0,
    skip            INTEGER DEFAULT 0,
    todo            INTEGER DEFAULT 0,
    test_files      INTEGER DEFAULT 0,
    total           INTEGER DEFAULT 0,
    format          TEXT DEFAULT 'XML',
    comments        BLOB DEFAULT '',
    invalid         INTEGER DEFAULT 0,
    invalid_reason  BLOB DEFAULT '',
    html_file       TEXT,
    duration        INTEGER DEFAULT 0,
    category        TEXT DEFAULT NULL,
    purged          INTEGER DEFAULT 0,
    failed          INTEGER DEFAULT 0,
    CONSTRAINT 'fk_smoke_report_project' FOREIGN KEY ('project') REFERENCES 'project' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_smoke_report_developer' FOREIGN KEY ('developer') REFERENCES 'developer' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_smoke_report_project_category' FOREIGN KEY ('project', 'category') REFERENCES 'project_category' ('project', 'category')
);

CREATE INDEX i_project_smoke_report ON smoke_report (project);
CREATE INDEX i_developer_smoke_report ON smoke_report (developer);
CREATE INDEX i_category_smoke_report ON smoke_report (category);
CREATE INDEX i_project_category_smoke_report ON smoke_report (project, category);

