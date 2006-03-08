CREATE TABLE project_category (
  project int(11) NOT NULL,
  category VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (project, category)
);

CREATE INDEX i_project_category_category_pr on project_category (category);
