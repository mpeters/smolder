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
    todo_pass       INTEGER DEFAULT 0,
    test_files      INTEGER DEFAULT 0,
    total           INTEGER DEFAULT 0,
    comments        BLOB DEFAULT '',
    invalid         INTEGER DEFAULT 0,
    invalid_reason  BLOB DEFAULT '',
    duration        INTEGER DEFAULT 0,
    purged          INTEGER DEFAULT 0,
    failed          INTEGER DEFAULT 0,
    revision        TEXT DEFAULT '',
    CONSTRAINT 'fk_smoke_report_project' FOREIGN KEY ('project') REFERENCES 'project' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_smoke_report_developer' FOREIGN KEY ('developer') REFERENCES 'developer' ('id') ON DELETE CASCADE
);

CREATE INDEX i_project_smoke_report ON smoke_report (project);
CREATE INDEX i_developer_smoke_report ON smoke_report (developer);

CREATE TABLE smoke_report_tag  (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    smoke_report    INTEGER NOT NULL,
    tag             TEXT DEFAULT '',
    CONSTRAINT 'fk_smoke_report_tag_smoke_report' FOREIGN KEY ('smoke_report') REFERENCES 'smoke_report' ('id') ON DELETE CASCADE
);

CREATE INDEX i_project_smoke_tag_tag ON smoke_report_tag (tag);
CREATE INDEX i_report_smoke_report_tag ON smoke_report_tag (smoke_report, tag);
