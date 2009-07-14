CREATE TABLE test_file  (
    id              INTEGER PRIMARY KEY AUTOINCREMENT, 
    project         INTEGER NOT NULL, 
    label           TEXT DEFAULT '',
    mute_until      INTEGER,
    CONSTRAINT 'fk_smoke_report_project' FOREIGN KEY ('project') REFERENCES 'project' ('id') ON DELETE CASCADE
);

CREATE INDEX i_test_file_project ON test_file (project);
