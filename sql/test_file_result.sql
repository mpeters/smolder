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
