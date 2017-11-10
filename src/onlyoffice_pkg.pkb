CREATE OR REPLACE PACKAGE BODY onlyoffice_pkg IS
  --
  /*************************************************************************
  * Purpose:  Save uploaded dropzone files in "files" table
  * Author:   Daniel Hochleitner
  * Created:  19.10.2017
  * Changed:
  *************************************************************************/
  PROCEDURE save_dropzone_files(p_collection_name IN VARCHAR2 := 'DROPZONE_UPLOAD') IS
    -- get files data from saved apex_collection
    CURSOR l_cur_files IS
      SELECT c001    AS filename,
             c002    AS mime_type,
             d001    AS date_created,
             n001    AS file_id,
             blob001 AS file_content
        FROM apex_collections
       WHERE collection_name = p_collection_name;
    --
  BEGIN
    -- loop over files cursor
    FOR l_rec_files IN l_cur_files LOOP
      -- do whatever processing is required prior to the insert into your own table
      INSERT INTO files
        (id,
         filename,
         mime_type,
         date_changed,
         file_content)
      VALUES
        (files_seq.nextval,
         l_rec_files.filename,
         l_rec_files.mime_type,
         l_rec_files.date_created,
         l_rec_files.file_content);
    END LOOP;
    -- clear original apex collection (only if exist)
    IF apex_collection.collection_exists(p_collection_name => p_collection_name) THEN
      apex_collection.delete_collection(p_collection_name => p_collection_name);
    END IF;
  END save_dropzone_files;
  --
  /*************************************************************************
  * Purpose:  Get Editor Config as JSON in HTP
  * Author:   Daniel Hochleitner
  * Created:  19.10.2017
  * Changed:
  *************************************************************************/
  PROCEDURE get_editor_config_json(p_id            IN files.id%TYPE,
                                   p_editor_width  IN VARCHAR2,
                                   p_editor_height IN VARCHAR2,
                                   p_file_author   IN VARCHAR2,
                                   p_file_url      IN VARCHAR2,
                                   p_callback_url  IN VARCHAR2,
                                   p_folder_name   IN VARCHAR2,
                                   p_header_link   IN VARCHAR2,
                                   p_about_name    IN VARCHAR2,
                                   p_about_mail    IN VARCHAR2,
                                   p_about_url     IN VARCHAR2,
                                   p_about_address IN VARCHAR2,
                                   p_about_info    IN VARCHAR2) IS
    --
    CURSOR l_cur_files IS
      SELECT files_iv.id,
             files_iv.filename,
             files_iv.mime_type,
             files_iv.date_changed,
             files_iv.file_ending,
             CASE
               WHEN files_iv.file_ending IN ('docx',
                                             'doc',
                                             'odt',
                                             'txt',
                                             'rtf',
                                             'html',
                                             'htm',
                                             'mht',
                                             'epub',
                                             'pdf',
                                             'djvu',
                                             'xps') THEN
                'text'
               WHEN files_iv.file_ending IN ('xlsx',
                                             'xls',
                                             'ods',
                                             'csv') THEN
                'spreadsheet'
               WHEN files_iv.file_ending IN ('pptx',
                                             'ppt',
                                             'odp',
                                             'ppsx',
                                             'pps') THEN
                'presentation'
               ELSE
                'text'
             END AS editor_type
        FROM (SELECT files.id,
                     files.filename,
                     files.mime_type,
                     files.date_changed,
                     substr(files.filename,
                            instr(files.filename,
                                  '.',
                                  -1) + 1,
                            length(files.filename)) AS file_ending
                FROM files
               WHERE files.id = p_id) files_iv;
    --
    CURSOR l_cur_app IS
      SELECT aa.application_primary_language
        FROM apex_applications aa
       WHERE aa.application_id = v('APP_ID');
    --
    CURSOR l_cur_header_logo IS
      SELECT aaf.mime_type,
             aaf.blob_content
        FROM apex_application_files aaf
       WHERE aaf.filename = 'header_logo.png'
         AND aaf.flow_id = nvl(wwv_flow.g_flow_id,
                               v('APP_ID'));
    --
    CURSOR l_cur_about_logo IS
      SELECT aaf.mime_type,
             aaf.blob_content
        FROM apex_application_files aaf
       WHERE aaf.filename = 'about_logo.png'
         AND aaf.flow_id = nvl(wwv_flow.g_flow_id,
                               v('APP_ID'));
    --
    l_rec_files       l_cur_files%ROWTYPE;
    l_rec_app         l_cur_app%ROWTYPE;
    l_rec_header_logo l_cur_header_logo%ROWTYPE;
    l_rec_about_logo  l_cur_about_logo%ROWTYPE;
    --
    l_header_logo_data_url CLOB := empty_clob();
    l_about_logo_data_url  CLOB := empty_clob();
    --
  BEGIN
    --
    OPEN l_cur_files;
    FETCH l_cur_files
      INTO l_rec_files;
    CLOSE l_cur_files;
    --
    OPEN l_cur_app;
    FETCH l_cur_app
      INTO l_rec_app;
    CLOSE l_cur_app;
    --
    OPEN l_cur_header_logo;
    FETCH l_cur_header_logo
      INTO l_rec_header_logo;
    CLOSE l_cur_header_logo;
    --
    OPEN l_cur_about_logo;
    FETCH l_cur_about_logo
      INTO l_rec_about_logo;
    CLOSE l_cur_about_logo;
    --
    IF dbms_lob.getlength(lob_loc => l_rec_header_logo.blob_content) > 0 THEN
      l_header_logo_data_url := 'data:' || l_rec_header_logo.mime_type ||
                                ';base64,' ||
                                apex_web_service.blob2clobbase64(p_blob => l_rec_header_logo.blob_content);
    END IF;
    IF dbms_lob.getlength(lob_loc => l_rec_about_logo.blob_content) > 0 THEN
      l_about_logo_data_url := 'data:' || l_rec_about_logo.mime_type ||
                               ';base64,' ||
                               apex_web_service.blob2clobbase64(p_blob => l_rec_about_logo.blob_content);
    END IF;
    --
    apex_json.open_object;
    apex_json.write('fileType',
                    l_rec_files.file_ending);
    apex_json.write('fileAuthor',
                    apex_escape.json(nvl(p_file_author,
                                         v('APP_USER'))));
    apex_json.write('fileDate',
                    to_char(l_rec_files.date_changed,
                            'YYYY-MM-DD HH24:MI'));
    apex_json.write('fileId',
                    l_rec_files.id);
    apex_json.write('fileName',
                    apex_escape.json(l_rec_files.filename));
    apex_json.write('fileUrl',
                    p_file_url);
    apex_json.write('callbackUrl',
                    p_callback_url);
    apex_json.write('editorType',
                    l_rec_files.editor_type);
    apex_json.write('editorLanguage',
                    nvl(l_rec_app.application_primary_language,
                        'en-US'));
    apex_json.write('width',
                    apex_escape.json(p_editor_width));
    apex_json.write('height',
                    apex_escape.json(p_editor_height));
    apex_json.write('folderName',
                    apex_escape.json(p_folder_name));
    --
    apex_json.write('headerLink',
                    p_header_link);
    apex_json.write('headerLogo',
                    l_header_logo_data_url);
    --
    apex_json.write('aboutName',
                    apex_escape.json(p_about_name));
    apex_json.write('aboutMail',
                    apex_escape.json(p_about_mail));
    apex_json.write('aboutUrl',
                    p_about_url);
    apex_json.write('aboutAddress',
                    apex_escape.json(p_about_address));
    apex_json.write('aboutInfo',
                    apex_escape.json(p_about_info));
    apex_json.write('aboutLogo',
                    l_about_logo_data_url);
    --
    apex_json.close_object;
    --
  END get_editor_config_json;
  --
  /*************************************************************************
  * Purpose:  Download a file from "files" table
  * Author:   Daniel Hochleitner
  * Created:  19.10.2017
  * Changed:
  *************************************************************************/
  PROCEDURE download_file(p_id                  IN files.id%TYPE,
                          p_content_disposition IN VARCHAR2 := 'attachment') IS
    --
    l_blob      BLOB;
    l_file_name VARCHAR2(400);
    l_mime_type VARCHAR2(500);
    --
  BEGIN
    --
    SELECT files.filename,
           files.mime_type,
           files.file_content
      INTO l_file_name,
           l_mime_type,
           l_blob
      FROM files
     WHERE files.id = p_id;
    --
    owa_util.mime_header(l_mime_type,
                         FALSE);
    htp.p('Content-length: ' || dbms_lob.getlength(l_blob));
    htp.p('Content-Disposition: ' || p_content_disposition ||
          '; filename="' || l_file_name || '"');
    owa_util.http_header_close;
    wpg_docload.download_file(l_blob);
    --
  END download_file;
  --
  /*************************************************************************
  * Purpose:  Download converted PDF file from "files" table
  * Author:   Daniel Hochleitner
  * Created:  09.11.2017
  * Changed:
  *************************************************************************/
  PROCEDURE download_file_pdf(p_id                  IN files.id%TYPE,
                              p_content_disposition IN VARCHAR2 := 'attachment',
                              p_file_url            IN VARCHAR2) IS
    --
    l_blob          BLOB;
    l_file_name     VARCHAR2(400);
    l_file_ending   VARCHAR2(400);
    l_new_file_name VARCHAR2(400);
    --
  BEGIN
    --
    SELECT files.filename,
           substr(files.filename,
                  instr(files.filename,
                        '.',
                        -1) + 1,
                  length(files.filename)) AS file_ending
      INTO l_file_name,
           l_file_ending
      FROM files
     WHERE files.id = p_id;
    --
    l_new_file_name := REPLACE(l_file_name,
                               l_file_ending,
                               'pdf');
    l_blob          := onlyoffice_pkg.convert_file(p_file_url        => p_file_url,
                                                   p_file_type       => l_file_ending,
                                                   p_output_type     => 'pdf',
                                                   p_output_filename => l_new_file_name,
                                                   p_thumbnail       => NULL);
    --
    owa_util.mime_header('application/pdf',
                         FALSE);
    htp.p('Content-length: ' || dbms_lob.getlength(l_blob));
    htp.p('Content-Disposition: ' || p_content_disposition ||
          '; filename="' || l_new_file_name || '"');
    owa_util.http_header_close;
    wpg_docload.download_file(l_blob);
    --
  END download_file_pdf;
  --
  /*************************************************************************
  * Purpose:  Download converted file from "files" table with specified output type
  * Author:   Daniel Hochleitner
  * Created:  10.11.2017
  * Changed:
  *************************************************************************/
  PROCEDURE download_converted_file(p_id                  IN files.id%TYPE,
                                    p_content_disposition IN VARCHAR2 := 'attachment',
                                    p_file_url            IN VARCHAR2,
                                    p_output_type         IN VARCHAR2,
                                    p_thumbnail           IN VARCHAR2 := NULL) IS
    --
    l_blob          BLOB;
    l_file_name     VARCHAR2(400);
    l_file_ending   VARCHAR2(400);
    l_new_file_name VARCHAR2(400);
    l_mime_type     VARCHAR2(500);
    --
  BEGIN
    --
    SELECT files.filename,
           substr(files.filename,
                  instr(files.filename,
                        '.',
                        -1) + 1,
                  length(files.filename)) AS file_ending
      INTO l_file_name,
           l_file_ending
      FROM files
     WHERE files.id = p_id;
    --
    l_mime_type     := onlyoffice_pkg.get_mime_type(p_file_extension => p_output_type);
    l_new_file_name := REPLACE(l_file_name,
                               l_file_ending,
                               p_output_type);
    l_blob          := onlyoffice_pkg.convert_file(p_file_url        => p_file_url,
                                                   p_file_type       => l_file_ending,
                                                   p_output_type     => p_output_type,
                                                   p_output_filename => l_new_file_name,
                                                   p_thumbnail       => p_thumbnail);
    --
    owa_util.mime_header(l_mime_type,
                         FALSE);
    htp.p('Content-length: ' || dbms_lob.getlength(l_blob));
    htp.p('Content-Disposition: ' || p_content_disposition ||
          '; filename="' || l_new_file_name || '"');
    owa_util.http_header_close;
    wpg_docload.download_file(l_blob);
    --
  END download_converted_file;
  --
  /*************************************************************************
  * Purpose:  Download converted thumbnail image of file from "files" table
  * Author:   Daniel Hochleitner
  * Created:  09.11.2017
  * Changed:
  *************************************************************************/
  PROCEDURE download_file_thumbnail(p_id                  IN files.id%TYPE,
                                    p_content_disposition IN VARCHAR2 := 'attachment',
                                    p_file_url            IN VARCHAR2,
                                    p_thumbnail_aspect    IN NUMBER := 0,
                                    p_thumbnail_width     IN NUMBER := 100,
                                    p_thumbnail_height    IN NUMBER := 100) IS
    --
    l_blob          BLOB;
    l_file_name     VARCHAR2(400);
    l_file_ending   VARCHAR2(400);
    l_new_file_name VARCHAR2(400);
    --
  BEGIN
    --
    SELECT files.filename,
           substr(files.filename,
                  instr(files.filename,
                        '.',
                        -1) + 1,
                  length(files.filename)) AS file_ending
      INTO l_file_name,
           l_file_ending
      FROM files
     WHERE files.id = p_id;
    --
    l_new_file_name := REPLACE(l_file_name,
                               l_file_ending,
                               'png');
    l_blob          := onlyoffice_pkg.convert_file(p_file_url        => p_file_url,
                                                   p_file_type       => l_file_ending,
                                                   p_output_type     => 'png',
                                                   p_output_filename => l_new_file_name,
                                                   p_thumbnail       => p_thumbnail_aspect || ':' ||
                                                                        p_thumbnail_width || ':' ||
                                                                        p_thumbnail_height);
    --
    owa_util.mime_header('image/png',
                         FALSE);
    htp.p('Content-length: ' || dbms_lob.getlength(l_blob));
    htp.p('Content-Disposition: ' || p_content_disposition ||
          '; filename="' || l_new_file_name || '"');
    owa_util.http_header_close;
    wpg_docload.download_file(l_blob);
    --
  END download_file_thumbnail;
  --
  /*************************************************************************
  * Purpose:  Check if access for particular IP (onlyoffice_pkg.g_allowed_ip) is allowed
  * Author:   Daniel Hochleitner
  * Created:  19.10.2017
  * Changed:
  *************************************************************************/
  FUNCTION is_access_allowed RETURN BOOLEAN IS
    --
    l_is_allowed     BOOLEAN := FALSE;
    l_remote_address VARCHAR2(200);
    --
  BEGIN
    --
    l_remote_address := owa_util.get_cgi_env('REMOTE_ADDR');
    --
    IF l_remote_address = onlyoffice_pkg.g_allowed_ip THEN
      l_is_allowed := TRUE;
    ELSE
      l_is_allowed := FALSE;
    END IF;
    --
    RETURN l_is_allowed;
    --
  END is_access_allowed;
  --
  /*************************************************************************
  * Purpose:  ONLYOFFICE Editor Webservice POST Callback (RESTful service) 
  * Author:   Daniel Hochleitner
  * Created:  19.10.2017
  * Changed:
  *************************************************************************/
  PROCEDURE onlyoffice_editor_callback(p_body BLOB) IS
    --
    l_blob          BLOB;
    l_clob          CLOB;
    l_dest_offset   INTEGER := 1;
    l_src_offset    INTEGER := 1;
    l_lang_context  INTEGER := dbms_lob.default_lang_ctx;
    l_warning       INTEGER := dbms_lob.warn_inconvertible_char;
    l_values        apex_json.t_values;
    l_editor_status NUMBER := 0;
    l_file_url      VARCHAR2(2000);
    l_file_blob     BLOB;
    l_file_key      VARCHAR2(200);
    l_file_id       NUMBER;
    l_file_key_arr2 apex_t_varchar2;
    --
  BEGIN
    -- check required parameter
    IF dbms_lob.getlength(p_body) > 0 THEN
      -- check if access allowed
      IF onlyoffice_pkg.is_access_allowed THEN
        -- get HTTP Body
        l_blob := p_body;
        -- convert to CLOB
        dbms_lob.createtemporary(l_clob,
                                 FALSE);
        dbms_lob.converttoclob(dest_lob     => l_clob,
                               src_blob     => l_blob,
                               amount       => dbms_lob.lobmaxsize,
                               dest_offset  => l_dest_offset,
                               src_offset   => l_src_offset,
                               blob_csid    => dbms_lob.default_csid,
                               lang_context => l_lang_context,
                               warning      => l_warning);
        -- Parse JSON
        apex_json.parse(p_values => l_values,
                        p_source => l_clob);
        l_editor_status := apex_json.get_number(p_values => l_values,
                                                p_path   => 'status');
        l_file_key      := apex_json.get_varchar2(p_values => l_values,
                                                  p_path   => 'key');
        l_file_key_arr2 := apex_string.split(p_str => l_file_key,
                                             p_sep => '-');
        l_file_id       := to_number(l_file_key_arr2(2));
        -- Editor Status 2,6 --> successfully saved file
        IF l_editor_status = 6 AND l_file_id IS NOT NULL THEN
          -- grab finished file from file URL 
          l_file_url := apex_json.get_varchar2(p_values => l_values,
                                               p_path   => 'url');
          IF onlyoffice_pkg.g_override_server_base_url IS NOT NULL THEN
            l_file_url := REPLACE(l_file_url,
                                  onlyoffice_pkg.g_server_base_url,
                                  onlyoffice_pkg.g_override_server_base_url);
          END IF;
          --
          IF l_file_url IS NOT NULL THEN
            apex_web_service.g_request_headers(1).name := 'User-Agent';
            apex_web_service.g_request_headers(1).value := 'APEX Editor Callback';
            --
            l_file_blob := apex_web_service.make_rest_request_b(p_url         => l_file_url,
                                                                p_http_method => 'GET',
                                                                p_wallet_path => onlyoffice_pkg.g_ssl_wallet_path,
                                                                p_wallet_pwd  => onlyoffice_pkg.g_ssl_wallet_pwd);
            -- update files table with new file
            IF dbms_lob.getlength(l_file_blob) > 0 THEN
              UPDATE files
                 SET files.file_content = l_file_blob,
                     files.date_changed = SYSDATE
               WHERE files.id = l_file_id;
              --
              COMMIT;
            END IF;
            --
          END IF;
        END IF;
        -- write success JSON to HTP
        apex_json.open_object;
        apex_json.write('error',
                        0);
        apex_json.close_object;
      ELSE
        -- write error JSON to HTP
        apex_json.open_object;
        apex_json.write('error',
                        1);
        apex_json.close_object;
      END IF;
    ELSE
      -- write error JSON to HTP
      apex_json.open_object;
      apex_json.write('error',
                      1);
      apex_json.close_object;
    END IF;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- write error JSON to HTP
      apex_json.open_object;
      apex_json.write('error',
                      1);
      apex_json.close_object;
  END onlyoffice_editor_callback;
  /****************************************************************************
  * Purpose: Check Server response HTTP error (2XX Status codes)
  * Author:  Daniel Hochleitner
  * Created: 09.11.2017
  * Changed:
  ****************************************************************************/
  PROCEDURE check_error_http_status IS
    --
    l_status_code VARCHAR2(100);
    l_name        VARCHAR2(200);
    l_value       VARCHAR2(200);
    l_error_msg   CLOB;
    --
  BEGIN
    --
    -- get http headers from response
    l_status_code := apex_web_service.g_status_code;
    --
    FOR i IN 1 .. apex_web_service.g_headers.count LOOP
      l_name  := apex_web_service.g_headers(i).name;
      l_value := apex_web_service.g_headers(i).value;
      -- If not successful throw error
      IF l_status_code NOT LIKE '2%' THEN
        l_error_msg := 'Response HTTP Status NOT OK' || chr(10) || 'Name: ' ||
                       l_name || chr(10) || 'Value: ' || l_value || chr(10) ||
                       'Status Code: ' || l_status_code;
        raise_application_error(error_http_status_code,
                                l_error_msg);
      END IF;
    END LOOP;
  END check_error_http_status;
  --
  /****************************************************************************
  * Purpose: Check Conversion API Server response for error
  * Author:  Daniel Hochleitner
  * Created: 09.11.2017
  * Changed:
  ****************************************************************************/
  PROCEDURE check_convert_error(p_response_clob IN OUT NOCOPY CLOB) IS
    --
    l_err_text     VARCHAR2(500);
    l_error_msg    VARCHAR2(1000);
    l_response_xml xmltype;
    -- cursor xmltable auf json
    CURSOR l_cur_error IS
      SELECT err_code
        FROM xmltable('/FileResult' passing l_response_xml columns err_code path
                      'Error');
    --
    l_rec_error l_cur_error%ROWTYPE;
    --
  BEGIN
    -- check response clob for error and code string
    IF p_response_clob LIKE '%<Error>%' THEN
      -- json to xml
      l_response_xml := sys.xmltype.createxml(p_response_clob);
      -- open xml cursor
      OPEN l_cur_error;
      FETCH l_cur_error
        INTO l_rec_error;
      CLOSE l_cur_error;
      -- build error message (from ONLYOFFICE Docs: https://api.onlyoffice.com/editors/conversionapi)
      IF l_rec_error.err_code = '-1' THEN
        l_err_text := 'Unknown error';
      ELSIF l_rec_error.err_code = '-2' THEN
        l_err_text := 'Timeout conversion error';
      ELSIF l_rec_error.err_code = '-3' THEN
        l_err_text := 'Conversion error';
      ELSIF l_rec_error.err_code = '-4' THEN
        l_err_text := 'Error while downloading the document file to be converted';
      ELSIF l_rec_error.err_code = '-6' THEN
        l_err_text := 'Error while accessing the conversion result database';
      ELSIF l_rec_error.err_code = '-8' THEN
        l_err_text := 'Invalid token';
        -- Unknown error
      ELSE
        l_err_text := 'Unknown Conversion API error';
      END IF;
      --
      l_error_msg := 'Error-Code: ' || l_rec_error.err_code || chr(10) ||
                     'Error-Description: ' || l_err_text;
      -- Throw error
      IF l_rec_error.err_code IS NOT NULL THEN
        raise_application_error(error_onlyoffice_convert_api,
                                l_error_msg);
      END IF;
    END IF;
    --
  END check_convert_error;
  --
  /*************************************************************************
  * Purpose:  Converts a file to another file format, eg. docx --> pdf
  *           https://api.onlyoffice.com/editors/conversionapi
  * Author:   Daniel Hochleitner
  * Created:  19.10.2017
  * Changed:
  *************************************************************************/
  FUNCTION convert_file(p_file_url        IN VARCHAR2,
                        p_file_type       IN VARCHAR2,
                        p_output_type     IN VARCHAR2,
                        p_output_filename IN VARCHAR2 := NULL,
                        p_thumbnail       IN VARCHAR2 := NULL) RETURN BLOB AS
    --
    l_request_json     CLOB;
    l_response_xml     CLOB;
    l_response_xmltype xmltype;
    l_blob             BLOB;
    l_thumbnail_arr2   apex_t_varchar2;
    l_thumbnail_aspect NUMBER;
    l_thumbnail_width  NUMBER;
    l_thumbnail_height NUMBER;
    l_server_url       VARCHAR2(1000);
    l_file_url         VARCHAR2(1000);
    -- cursor for convert response in xml
    CURSOR l_cur_convert_response IS
      SELECT file_url,
             percentage,
             end_convert
        FROM xmltable('/FileResult' passing l_response_xmltype columns
                      file_url path 'FileUrl',
                      percentage path 'Percent',
                      end_convert path 'EndConvert');
    l_rec_convert_response l_cur_convert_response%ROWTYPE;
    --
  BEGIN
    --
    -- build request JSON
    apex_json.initialize_clob_output;
    --
    apex_json.open_object;
    apex_json.write('async',
                    FALSE);
    apex_json.write('key',
                    to_char(systimestamp,
                            'YYYYMMDDHH24MISSFF'));
    apex_json.write('url',
                    '##FILE_URL##');
    apex_json.write('filetype',
                    p_file_type);
    apex_json.write('outputtype',
                    p_output_type);
    IF p_output_filename IS NOT NULL THEN
      apex_json.write('title',
                      p_output_filename);
    END IF;
    -- thumbnail
    IF p_thumbnail IS NOT NULL THEN
      l_thumbnail_arr2   := apex_string.split(p_str => p_thumbnail,
                                              p_sep => ':');
      l_thumbnail_aspect := to_number(l_thumbnail_arr2(1));
      l_thumbnail_width  := to_number(l_thumbnail_arr2(2));
      l_thumbnail_height := to_number(l_thumbnail_arr2(3));
      --
      apex_json.open_object('thumbnail');
      apex_json.write('aspect',
                      l_thumbnail_aspect);
      apex_json.write('first',
                      TRUE);
      apex_json.write('width',
                      l_thumbnail_width);
      apex_json.write('height',
                      l_thumbnail_height);
      apex_json.close_object;
    END IF;
    --
    apex_json.close_object;
    --
    l_request_json := apex_json.get_clob_output;
    apex_json.free_output;
    --
    l_request_json := REPLACE(l_request_json,
                              '##FILE_URL##',
                              p_file_url);
    --
    -- REST call: start conversion task
    apex_web_service.g_request_headers(1).name := 'User-Agent';
    apex_web_service.g_request_headers(1).value := 'APEX Convert File';
    apex_web_service.g_request_headers(2).name := 'Accept';
    apex_web_service.g_request_headers(2).value := '*/*';
    apex_web_service.g_request_headers(3).name := 'Content-Type';
    apex_web_service.g_request_headers(3).value := 'application/json';
    --
    l_server_url := nvl(onlyoffice_pkg.g_override_server_base_url,
                        onlyoffice_pkg.g_server_base_url) ||
                    '/ConvertService.ashx';
    --
    l_response_xml := apex_web_service.make_rest_request(p_url         => l_server_url,
                                                         p_http_method => 'POST',
                                                         p_body        => l_request_json,
                                                         p_wallet_path => onlyoffice_pkg.g_ssl_wallet_path,
                                                         p_wallet_pwd  => onlyoffice_pkg.g_ssl_wallet_pwd);
    -- check for http error
    check_error_http_status;
    -- check for convert error
    check_convert_error(p_response_clob => l_response_xml);
    --
    l_response_xmltype := sys.xmltype.createxml(l_response_xml);
    --
    OPEN l_cur_convert_response;
    FETCH l_cur_convert_response
      INTO l_rec_convert_response;
    CLOSE l_cur_convert_response;
    --
    IF l_rec_convert_response.percentage = 100 AND
       l_rec_convert_response.end_convert = 'True' THEN
      --
      l_file_url := l_rec_convert_response.file_url;
      IF onlyoffice_pkg.g_override_server_base_url IS NOT NULL THEN
        l_file_url := REPLACE(l_file_url,
                              onlyoffice_pkg.g_server_base_url,
                              onlyoffice_pkg.g_override_server_base_url);
      END IF;
      --
      l_blob := apex_web_service.make_rest_request_b(p_url         => l_file_url,
                                                     p_http_method => 'GET',
                                                     p_wallet_path => onlyoffice_pkg.g_ssl_wallet_path,
                                                     p_wallet_pwd  => onlyoffice_pkg.g_ssl_wallet_pwd);
      -- check for http error
      check_error_http_status;
    END IF;
    --
    RETURN l_blob;
    --
  END convert_file;
  --
  /****************************************************************************
  * Purpose: Get mime type depending on file extension
  * Author:  Daniel Hochleitner
  * Created: 10.11.2017
  * Changed:
  ****************************************************************************/
  FUNCTION get_mime_type(p_file_extension IN VARCHAR2) RETURN VARCHAR2 IS
    -- 
    l_mime_type      VARCHAR2(500);
    l_file_extension VARCHAR2(100);
  BEGIN
    l_mime_type := NULL;
    --
    l_file_extension := upper(p_file_extension);
    --
    CASE l_file_extension
      WHEN 'PDF' THEN
        l_mime_type := 'application/pdf';
      WHEN 'TXT' THEN
        l_mime_type := 'text/plain';
      WHEN 'XLS' THEN
        l_mime_type := 'application/vnd.ms-excel';
      WHEN 'XLSX' THEN
        l_mime_type := 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      WHEN 'XLT' THEN
        l_mime_type := 'application/vnd.ms-excel';
      WHEN 'XLTX' THEN
        l_mime_type := 'application/vnd.openxmlformats-officedocument.spreadsheetml.template';
      WHEN 'DOC' THEN
        l_mime_type := 'application/msword';
      WHEN 'DOCX' THEN
        l_mime_type := 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      WHEN 'DOT' THEN
        l_mime_type := 'application/msword';
      WHEN 'DOTX' THEN
        l_mime_type := 'application/vnd.openxmlformats-officedocument.wordprocessingml.template';
      WHEN 'PPT' THEN
        l_mime_type := 'application/vnd.ms-powerpoint';
      WHEN 'PPTX' THEN
        l_mime_type := 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      WHEN 'MPP' THEN
        l_mime_type := 'application/vnd.ms-project';
      WHEN 'WPS' THEN
        l_mime_type := 'application/vnd.ms-works';
      WHEN 'RTF' THEN
        l_mime_type := 'application/rtf';
      WHEN 'ODT' THEN
        l_mime_type := 'application/vnd.oasis.opendocument.text';
      WHEN 'OTT' THEN
        l_mime_type := 'application/vnd.oasis.opendocument.text-template';
      WHEN 'OTH' THEN
        l_mime_type := 'application/vnd.oasis.opendocument.text-web';
      WHEN 'ODM' THEN
        l_mime_type := 'application/vnd.oasis.opendocument.text-master';
      WHEN 'ODG' THEN
        l_mime_type := 'application/vnd.oasis.opendocument.graphics';
      WHEN 'OTG' THEN
        l_mime_type := 'application/vnd.oasis.opendocument.graphics-template';
      WHEN 'ODP' THEN
        l_mime_type := 'application/vnd.oasis.opendocument.presentation';
      WHEN 'OTP' THEN
        l_mime_type := 'application/vnd.oasis.opendocument.presentation-template';
      WHEN 'ODS' THEN
        l_mime_type := 'application/vnd.oasis.opendocument.spreadsheet';
      WHEN 'OTS' THEN
        l_mime_type := 'application/vnd.oasis.opendocument.spreadsheet-template';
      WHEN 'ODC' THEN
        l_mime_type := 'application/vnd.oasis.opendocument.chart';
      WHEN 'ODF' THEN
        l_mime_type := 'application/vnd.oasis.opendocument.formula';
      WHEN 'ODB' THEN
        l_mime_type := 'application/vnd.oasis.opendocument.database';
      WHEN 'ODI' THEN
        l_mime_type := 'application/vnd.oasis.opendocument.image';
      WHEN 'OXT' THEN
        l_mime_type := 'application/vnd.openofficeorg.extension';
      WHEN 'LATEX' THEN
        l_mime_type := 'application/x-latex';
      WHEN 'SWF' THEN
        l_mime_type := 'application/x-shockwave-flash';
      WHEN 'TEX' THEN
        l_mime_type := 'application/x-tex';
      WHEN 'ZIP' THEN
        l_mime_type := 'application/zip';
      WHEN 'MP3' THEN
        l_mime_type := 'audio/mpeg';
      WHEN 'BMP' THEN
        l_mime_type := 'image/bmp';
      WHEN 'PNG' THEN
        l_mime_type := 'image/png';
      WHEN 'GIF' THEN
        l_mime_type := 'image/gif';
      WHEN 'JPG' THEN
        l_mime_type := 'image/jpeg';
      WHEN 'JPEG' THEN
        l_mime_type := 'image/jpeg';
      WHEN 'TIF' THEN
        l_mime_type := 'image/tiff';
      WHEN 'TIFF' THEN
        l_mime_type := 'image/tiff';
      WHEN 'ICO' THEN
        l_mime_type := 'image/x-icon';
      WHEN 'CSS' THEN
        l_mime_type := 'text/css';
      WHEN 'HTML' THEN
        l_mime_type := 'text/html';
      WHEN 'HTM' THEN
        l_mime_type := 'text/html';
      WHEN 'TXT' THEN
        l_mime_type := 'text/plain';
      WHEN 'MPG' THEN
        l_mime_type := 'video/mpeg';
      WHEN 'MOV' THEN
        l_mime_type := 'video/quicktime';
      WHEN 'EML' THEN
        l_mime_type := 'message/rfc822';
      ELSE
        l_mime_type := 'application/octet-stream';
    END CASE;
    --
    RETURN l_mime_type;
    --
  END get_mime_type;
  --
  /****************************************************************************
  * Purpose: Set all global package variables
  * Author:  Daniel Hochleitner
  * Created: 09.11.2017
  * Changed:
  ****************************************************************************/
  PROCEDURE set_global_pkg_vars(p_server_base_url          IN VARCHAR2,
                                p_override_server_base_url IN VARCHAR2 := NULL,
                                p_allowed_ip               IN VARCHAR2,
                                p_ssl_wallet_path          IN VARCHAR2 := NULL,
                                p_ssl_wallet_pwd           IN VARCHAR2 := NULL) IS
    --
  BEGIN
    -- set global package vars
    onlyoffice_pkg.g_server_base_url          := p_server_base_url;
    onlyoffice_pkg.g_override_server_base_url := p_override_server_base_url;
    onlyoffice_pkg.g_allowed_ip               := p_allowed_ip;
    onlyoffice_pkg.g_ssl_wallet_path          := p_ssl_wallet_path;
    onlyoffice_pkg.g_ssl_wallet_pwd           := p_ssl_wallet_pwd;
    --
  END set_global_pkg_vars;
  --
END onlyoffice_pkg;
/
