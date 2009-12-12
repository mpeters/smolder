ALTER TABLE preference ADD COLUMN show_passing INT DEFAULT 1;

CREATE TABLE test_file  (
    id              INTEGER PRIMARY KEY AUTOINCREMENT, 
    project         INTEGER NOT NULL, 
    label           TEXT DEFAULT '',
    mute_until      INTEGER,
    CONSTRAINT 'fk_test_file_project' FOREIGN KEY ('project') REFERENCES 'project' ('id') ON DELETE CASCADE
);

CREATE INDEX i_test_file_project ON test_file (project);

CREATE TABLE test_file_comment  (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    project         INTEGER NOT NULL,
    test_file       INTEGER NOT NULL,
    developer       INTEGER NOT NULL,
    added           INTEGER NOT NULL,
    comment         TEXT DEFAULT '',
    CONSTRAINT 'fk_test_file_comment_project' FOREIGN KEY ('project') REFERENCES 'project' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_test_file_comment_test_file' FOREIGN KEY ('test_file') REFERENCES 'test_file' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_test_file_comment_developer' FOREIGN KEY ('developer') REFERENCES 'developer' ('id') ON DELETE CASCADE
);

CREATE INDEX i_test_file_comment_project ON test_file_comment (project);
CREATE INDEX i_test_file_comment_test_file ON test_file_comment (test_file);
CREATE INDEX i_test_file_comment_developer ON test_file_comment (developer);

CREATE TABLE test_file_result  (
    id              INTEGER PRIMARY KEY AUTOINCREMENT, 
    project         INTEGER NOT NULL, 
    test_file       INTEGER NOT NULL,
    smoke_report    INTEGER NOT NULL,
    file_index      INTEGER NOT NULL,
    total           INTEGER NOT NULL,
    failed          INTEGER NOT NULL,
    percent         INTEGER NOT NULL,
    added           INTEGER NOT NULL,
    CONSTRAINT 'fk_test_file_result_project' FOREIGN KEY ('project') REFERENCES 'project' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_test_file_result_test_file' FOREIGN KEY ('test_file') REFERENCES 'test_file' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_test_file_result_smoke_report' FOREIGN KEY ('smoke_report') REFERENCES 'smoke_report' ('id') ON DELETE CASCADE
);

CREATE INDEX i_test_file_result_project_test_file ON test_file_result (project, test_file);
CREATE INDEX i_test_file_result_test_file_smoke_report ON test_file_result (test_file, smoke_report);
CREATE INDEX i_test_file_result_smoke_report ON test_file_result (smoke_report);

