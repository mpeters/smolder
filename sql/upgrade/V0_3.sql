ALTER TABLE preference ADD COLUMN email_limit INTEGER DEFAULT 0;
ALTER TABLE preference ADD COLUMN email_sent INTEGER DEFAULT 0;
ALTER TABLE preference ADD COLUMN email_sent_timestamp INTEGER;

ALTER TABLE developer ADD COLUMN guest INTEGER DEFAULT 0;

ALTER TABLE smoke_report ADD COLUMN failed INTEGER DEFAULT 0;
UPDATE smoke_report SET failed = ( fail > 1);

