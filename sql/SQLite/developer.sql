CREATE TABLE developer (
  id INTEGER PRIMARY KEY NOT NULL,
  username VARCHAR(255) NOT NULL DEFAULT '',
  fname VARCHAR(255) NOT NULL DEFAULT '',
  lname VARCHAR(255) NOT NULL DEFAULT '',
  email VARCHAR(255) NOT NULL DEFAULT '',
  password VARCHAR(255) NOT NULL DEFAULT '',
  admin BOOL NOT NULL DEFAULT '0',
  preference int(11) NOT NULL
);

CREATE INDEX i_preference_developer on developer (preference);
CREATE UNIQUE INDEX unique_username_developer on developer (username);
