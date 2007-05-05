ALTER TABLE smoke_report DROP COLUMN format;
ALTER TABLE smoke_report DROP COLUMN html_file;
ALTER TABLE smoke_report ADD COLUMN todo_pass INTEGER DEFAULT 0;
