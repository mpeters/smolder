INSERT INTO db_version VALUES ("0.3");

INSERT INTO preference (id) VALUES (1);
INSERT INTO preference (id) VALUES (2);

INSERT INTO developer (id, username, fname, lname, email, password, admin, preference, guest) VALUES (1, 'admin', 'Joe', 'Admin', 'test@test.com', 'YhKDbhvT1LKkg', 1, 1, 0);
INSERT INTO developer (id, username, fname, lname, email, password, admin, preference, guest) VALUES (2, 'anonymous', '', '', '', '', 0, 2, 1);
