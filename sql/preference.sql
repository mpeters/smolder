CREATE TABLE preference (
    id          INTEGER PRIMARY KEY AUTOINCREMENT, 
    email_type  TEXT DEFAULT 'full',
    email_freq  TEXT DEFAULT 'on_new',
    email_limit INT DEFAULT 0,
    email_sent  INT DEFAULT 0,
    email_sent_timestamp INTEGER,
    show_passing INT DEFAULT 1
);

INSERT INTO preference (id) VALUES (1);
INSERT INTO preference (id) VALUES (2);

