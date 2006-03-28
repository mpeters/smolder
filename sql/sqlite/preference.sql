CREATE TABLE preference (
    id          INTEGER PRIMARY KEY AUTOINCREMENT, 
    email_type  TEXT DEFAULT 'full',
    email_freq  TEXT DEFAULT 'on_new'
);

