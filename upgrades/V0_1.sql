ALTER TABLE project ADD graph_start ENUM('project', 'year', 'month', 'week', 'day') NOT NULL DEFAULT 'project' AFTER default_arch;
