--
-- Projects being looked after in this installation
--
CREATE TABLE project (
    id                  INTEGER UNSIGNED NOT NULL PRIMARY KEY, 
    name                TEXT NOT NULL DEFAULT '',
    start_date          INTEGER NOT NULL DEFAULT 0,
    public              INTEGER NOT NULL DEFAULT 1,
    default_platform    TEXT NOT NULL DEFAULT '',
    default_arch        TEXT NOT NULL DEFAULT '',
    graph_start         TEXT NOT NULL DEFAULT 'project',
    allow_anon          INTEGER NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX i_project_name_project on project (name);

