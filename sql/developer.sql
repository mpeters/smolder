CREATE TABLE developer (
    id          INTEGER PRIMARY KEY AUTOINCREMENT, 
    username    TEXT DEFAULT '', 
    fname       TEXT DEFAULT '',
    lname       TEXT DEFAULT '',
    email       TEXT DEFAULT '',
    password    TEXT DEFAULT '',
    admin       INTEGER DEFAULT 0,
    preference  INTEGER NOT NULL, 
    guest       INTEGER DEFAULT 0,
    CONSTRAINT 'fk_developer_preference' FOREIGN KEY ('preference') REFERENCES 'preference' ('id')
);

CREATE INDEX i_preference_developer on developer (preference);
CREATE UNIQUE INDEX unique_username_developer on developer (username);

INSERT INTO developer (id, username, fname, lname, email, password, admin, preference, guest) VALUES (1, 'admin', 'Joe', 'Admin', 'test@test.com', 'YhKDbhvT1LKkg', 1, 1, 0);
INSERT INTO developer (id, username, fname, lname, email, password, admin, preference, guest) VALUES (2, 'anonymous', '', '', '', '', 0, 2, 1);
