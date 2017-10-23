# ONLYOFFICE integration in Oracle APEX

![](https://github.com/Dani3lSun/apex-onlyoffice-integration/blob/master/preview_docx.png)
![](https://github.com/Dani3lSun/apex-onlyoffice-integration/blob/master/preview_xlsx.png)

[DEMO](https://orclapex.io/ords/f?p=170)


## Installation

1. table
```
@src/01_files_table.sql
```

2. sequence
```
@src/02_files_sequence.sql
```

3. trigger
```
@src/03_files_trigger.sql
```

4. package
```
@src/onlyoffice_pkg.pks
@src/onlyoffice_pkg.pkb
```

3. RESTful Service
```
@src/restful_service_onlyoffice_editor_callback.sql
```

OR

just import [apex/f170_onlyoffice_demo.sql](https://github.com/Dani3lSun/apex-onlyoffice-integration/blob/master/apex/f170_onlyoffice_demo.sql) into your APEX workspace. This will install all database objects into your parsing schema.


## License

[MIT License](https://github.com/Dani3lSun/apex-onlyoffice-integration/blob/master/LICENSE)
