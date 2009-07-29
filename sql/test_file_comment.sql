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
