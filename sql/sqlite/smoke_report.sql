--
-- Individual smoke report uploaded for a project. Contains
-- summary information (pass, fail, skip, todo, test_files, total, etc)
-- even though they are contained in the actual XMl files stored for
-- each report. This allows for faster access to this summary info
--
CREATE TABLE smoke_report  (
    id              INTEGER UNSIGNED NOT NULL PRIMARY KEY, 
    project         INTEGER UNSIGNED NOT NULL, 
    developer       INTEGER UNSIGNED NOT NULL, 
    added           INTEGER NOT NULL DEFAULT 0,
    architecture    TEXT NOT NULL DEFAULT '',
    platform        TEXT NOT NULL DEFAULT '',
    pass            INTEGER UNSIGNED NOT NULL DEFAULT 0,
    fail            INTEGER UNSIGNED NOT NULL DEFAULT 0,
    skip            INTEGER UNSIGNED NOT NULL DEFAULT 0,
    todo            INTEGER UNSIGNED NOT NULL DEFAULT 0,
    test_files      INTEGER UNSIGNED NOT NULL DEFAULT 0,
    total           INTEGER UNSIGNED NOT NULL DEFAULT 0,
    format          TEXT NOT NULL DEFAULT 'XML',
    comments        BLOB NOT NULL DEFAULT '',
    invalid         INTEGER NOT NULL DEFAULT 0,
    invalid_reason  BLOB NOT NULL DEFAULT '',
    html_file       TEXT,
    duration        INTEGER UNSIGNED NOT NULL DEFAULT 0,
    category        TEXT DEFAULT NULL,
    CONSTRAINT 'fk_smoke_report_project' FOREIGN KEY ('project') REFERENCES 'project' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_smoke_report_developer' FOREIGN KEY ('developer') REFERENCES 'developer' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_smoke_report_project_category' FOREIGN KEY ('project', 'category') REFERENCES 'project_category' ('project', 'category')
);

CREATE INDEX i_project_smoke_report ON smoke_report (project);
CREATE INDEX i_developer_smoke_report ON smoke_report (developer);
CREATE INDEX i_category_smoke_report ON smoke_report (category);
CREATE INDEX i_project_category_smoke_report ON smoke_report (project, category);

