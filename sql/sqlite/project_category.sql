CREATE TABLE project_category (
    project             INTEGER NOT NULL, 
    category            TEXT NOT NULL,
    PRIMARY KEY (project, category),
    CONSTRAINT 'fk_project_category_project' FOREIGN KEY ('project') REFERENCES 'project' ('id') ON DELETE CASCADE
);
CREATE INDEX i_project_category_category_pr on project_category (category);

