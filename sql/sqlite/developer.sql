--
-- The list of registered developers (or users) or Smolder.
-- They have a default 'preference' but are also associated
-- with a project and a project specific preference via the
-- project_developer table
--
CREATE TABLE developer (
    id          INTEGER NOT NULL PRIMARY KEY, 
    username    TEXT NOT NULL DEFAULT '', 
    fname       TEXT NOT NULL DEFAULT '',
    lname       TEXT NOT NULL DEFAULT '',
    email       TEXT NOT NULL DEFAULT '',
    password    TEXT NOT NULL DEFAULT '',
    admin       INTEGER NOT NULL DEFAULT 0,
    preference  INT UNSIGNED NOT NULL, 
    CONSTRAINT 'fk_developer_preference' FOREIGN KEY ('preference') REFERENCES 'preference' ('id')
);

CREATE INDEX i_preference_developer on developer (preference);
CREATE UNIQUE INDEX unique_username_developer on developer (username);

