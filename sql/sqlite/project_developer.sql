CREATE TABLE project_developer (
    project     INTEGER NOT NULL, 
    developer   INTEGER NOT NULL,
    preference  INTEGER,
    admin       INTEGER DEFAULT 0,
    added       INTEGER DEFAULT 0,
    PRIMARY KEY (project, developer),
    CONSTRAINT 'fk_project_developer_project' FOREIGN KEY ('project') REFERENCES 'project' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_project_developer_developer' FOREIGN KEY ('developer') REFERENCES 'developer' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_project_developer_preference' FOREIGN KEY ('preference') REFERENCES 'preference' ('id')
);

CREATE INDEX i_developer_project_developer on project_developer (developer);
CREATE INDEX i_project_project_developer on project_developer (project);
CREATE INDEX i_preference_project_developer on project_developer (preference);

