-- Create Before Insert Trigger
CREATE OR REPLACE TRIGGER files_bi_trg
  BEFORE INSERT ON files
  FOR EACH ROW
DECLARE
BEGIN
  IF :new.id IS NULL THEN
    :new.id := files_seq.nextval;
  END IF;
END;