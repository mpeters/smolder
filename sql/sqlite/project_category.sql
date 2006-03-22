--
-- Project admin specified list of categories 
-- for a given project.
--
CREATE TABLE project_category (
    project             INT UNSIGNED NOT NULL PRIMARY KEY, 
    category            TEXT NOT NULL DEFAULT '',
    CONSTRAINT 'fk_project_category_project' FOREIGN KEY ('project') REFERENCES 'project' ('id') ON DELETE CASCADE
);
CREATE INDEX i_project_category_category_pr on project_category (category);

