-- Create table
create table FILES
(
  id           number not null,
  filename     varchar2(500) not null,
  mime_type    varchar2(500),
  date_changed date,
  file_content blob
);
-- Create/Recreate indexes 
create index FILES_DATE_CHANGED_I on FILES (date_changed);
-- Create/Recreate primary, unique and foreign key constraints 
alter table FILES
  add constraint FILES_PK primary key (ID);