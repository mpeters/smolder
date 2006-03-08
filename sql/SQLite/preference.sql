CREATE TABLE preference (
  id INTEGER PRIMARY KEY NOT NULL,
  email_type ENUM(7) NOT NULL DEFAULT 'full',
  email_freq ENUM(7) NOT NULL DEFAULT 'on_new'
);
