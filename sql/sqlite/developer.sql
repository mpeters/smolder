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

