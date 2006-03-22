--
-- Which developers are assigned to which projects
-- and what are their project specific preferences
--
CREATE TABLE project_developer (
    project     INTEGER UNSIGNED NOT NULL, 
    developer   INTEGER UNSIGNED NOT NULL,
    preference  INTEGER UNSIGNED NOT NULL,
    admin       INTEGER NOT NULL DEFAULT 0,
    added       INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (project, developer),
    CONSTRAINT 'fk_project_developer_project' FOREIGN KEY ('project') REFERENCES 'project' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_project_developer_developer' FOREIGN KEY ('developer') REFERENCES 'developer' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_project_developer_preference' FOREIGN KEY ('preference') REFERENCES 'preference' ('id')
);

CREATE INDEX i_developer_project_developer on project_developer (developer);
CREATE INDEX i_project_project_developer on project_developer (project);
CREATE INDEX i_preference_project_developer on project_developer (preference);

