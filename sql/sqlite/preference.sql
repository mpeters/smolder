--
-- Developer's preferences. Linked to by the developer and
-- project_developer tables
--
CREATE TABLE preference (
    id          INTEGER UNSIGNED NOT NULL PRIMARY KEY, 
    email_type  TEXT NOT NULL DEFAULT 'full',
    email_freq  TEXT NOT NULL DEFAULT 'on_new'
);

