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
                                   p_callback_url  IN VARCHAR2) IS
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
    l_rec_files l_cur_files%ROWTYPE;
    l_rec_app   l_cur_app%ROWTYPE;
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
    --
  BEGIN
    --
    SELECT files.filename,
           files.file_content
      INTO l_file_name,
           l_blob
      FROM files
     WHERE files.id = p_id;
    --
    owa_util.mime_header('application/json',
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
  * Purpose:  Check if access for particular IP is allowed
  * Author:   Daniel Hochleitner
  * Created:  19.10.2017
  * Changed:
  *************************************************************************/
  FUNCTION is_access_allowed(p_allowed_ip IN VARCHAR2) RETURN BOOLEAN IS
    --
    l_is_allowed     BOOLEAN := FALSE;
    l_remote_address VARCHAR2(200);
    --
  BEGIN
    --
    l_remote_address := owa_util.get_cgi_env('REMOTE_ADDR');
    --
    IF l_remote_address = p_allowed_ip THEN
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
  PROCEDURE onlyoffice_editor_callback(p_app_id      IN NUMBER,
                                       p_app_session IN NUMBER,
                                       p_body        BLOB,
                                       p_wallet_path IN VARCHAR2,
                                       p_wallet_pwd  IN VARCHAR2) IS
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
    --
  BEGIN
    -- check required parameter
    IF p_app_id IS NOT NULL AND p_app_session IS NOT NULL AND
       dbms_lob.getlength(p_body) > 0 THEN
      -- join APEX session
      onlyoffice_pkg.join_apex_session(p_session_id => p_app_session,
                                       p_app_id     => p_app_id);
      -- check if access allowed
      IF onlyoffice_pkg.is_access_allowed(p_allowed_ip => apex_util.get_session_state('ALLOWED_IP')) THEN
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
        l_file_id       := to_number(substr(l_file_key,
                                            instr(l_file_key,
                                                  '-') + 1,
                                            length(l_file_key)));
        -- Editor Status 2,6 --> successfully saved file
        IF l_editor_status = 6 AND l_file_id IS NOT NULL THEN
          -- grab finished file from file URL 
          l_file_url := apex_json.get_varchar2(p_values => l_values,
                                               p_path   => 'url');
          l_file_url := REPLACE(l_file_url,
                                apex_util.get_session_state('ONLYOFFICE_SERVER_BASE_URL'),
                                'http://localhost:8181');
          --
          IF l_file_url IS NOT NULL THEN
            l_file_blob := apex_web_service.make_rest_request_b(p_url         => l_file_url,
                                                                p_http_method => 'GET',
                                                                p_wallet_path => p_wallet_path,
                                                                p_wallet_pwd  => p_wallet_pwd);
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
  --
  /*************************************************************************
  * Purpose:  Creates a new APEX session 
  *           https://github.com/OraOpenSource/oos-utils/blob/master/source/packages/oos_util_apex.pkb
  * Author:   Daniel Hochleitner
  * Created:  19.10.2017
  * Changed:
  *************************************************************************/
  PROCEDURE create_apex_session(p_app_id     IN apex_applications.application_id%TYPE,
                                p_user_name  IN apex_workspace_sessions.user_name%TYPE,
                                p_page_id    IN apex_application_pages.page_id%TYPE DEFAULT NULL,
                                p_session_id IN apex_workspace_sessions.apex_session_id%TYPE DEFAULT NULL) AS
    l_workspace_id apex_applications.workspace_id%TYPE;
    l_cgivar_name  sys.owa.vc_arr;
    l_cgivar_val   sys.owa.vc_arr;
  
    l_page_id   apex_application_pages.page_id%TYPE := p_page_id;
    l_home_link apex_applications.home_link%TYPE;
    l_url_arr   apex_application_global.vc_arr2;
  
    l_count PLS_INTEGER;
  BEGIN
    -- create CGI ENV if not already present
    IF owa_util.get_cgi_env('HTTP_HOST') IS NULL THEN
      sys.htp.init;
    
      l_cgivar_name(1) := 'REQUEST_PROTOCOL';
      l_cgivar_val(1) := 'HTTP';
    
      sys.owa.init_cgi_env(num_params => 1,
                           param_name => l_cgivar_name,
                           param_val  => l_cgivar_val);
    END IF;
    --
    SELECT workspace_id
      INTO l_workspace_id
      FROM apex_applications
     WHERE application_id = p_app_id;
  
    wwv_flow_api.set_security_group_id(l_workspace_id);
  
    IF l_page_id IS NULL THEN
      -- Try to get the page_id from home link
      SELECT aa.home_link
        INTO l_home_link
        FROM apex_applications aa
       WHERE 1 = 1
         AND aa.application_id = p_app_id;
    
      IF l_home_link IS NOT NULL THEN
        l_url_arr := apex_util.string_to_table(l_home_link,
                                               ':');
      
        IF l_url_arr.count >= 2 THEN
          l_page_id := l_url_arr(2);
        END IF;
      END IF;
    
      IF l_page_id IS NULL THEN
        l_page_id := 101;
      END IF;
    
    END IF; -- l_page_id is null
  
    -- #49 Ensure that page exists
    SELECT COUNT(1)
      INTO l_count
      FROM apex_application_pages aap
     WHERE 1 = 1
       AND aap.application_id = p_app_id
       AND aap.page_id = l_page_id
       AND l_page_id IS NOT NULL;
  
    apex_application.g_instance     := 1;
    apex_application.g_flow_id      := p_app_id;
    apex_application.g_flow_step_id := l_page_id;
  
    apex_custom_auth.post_login(p_uname      => p_user_name,
                                p_session_id => NULL, -- could use APEX_CUSTOM_AUTH.GET_NEXT_SESSION_ID
                                p_app_page   => apex_application.g_flow_id || ':' ||
                                                l_page_id);
  
    -- Rejoin session
    IF p_session_id IS NOT NULL THEN
      -- This will only set the session but doesn't register the items
      -- apex_custom_auth.set_session_id(p_session_id => p_session_id);
      -- #42 Seems a second login is required to fully join session
      apex_custom_auth.post_login(p_uname      => p_user_name,
                                  p_session_id => p_session_id);
    END IF;
  
  END create_apex_session;
  --
  /*************************************************************************
  * Purpose:  Joins an existing APEX session
  *           https://github.com/OraOpenSource/oos-utils/blob/master/source/packages/oos_util_apex.pkb
  * Author:   Daniel Hochleitner
  * Created:  19.10.2017
  * Changed:
  *************************************************************************/
  PROCEDURE join_apex_session(p_session_id IN apex_workspace_sessions.apex_session_id%TYPE,
                              p_app_id     IN apex_applications.application_id%TYPE DEFAULT NULL) AS
    --
    l_app_id    apex_applications.application_id%TYPE := p_app_id;
    l_user_name apex_workspace_sessions.user_name%TYPE;
    --
  BEGIN
    --
    IF l_app_id IS NULL THEN
      SELECT MAX(application_id)
        INTO l_app_id
        FROM (SELECT application_id,
                     row_number() over(ORDER BY view_date DESC) rn
                FROM apex_workspace_activity_log
               WHERE apex_session_id = p_session_id)
       WHERE rn = 1;
    END IF;
    --
    SELECT user_name
      INTO l_user_name
      FROM apex_workspace_sessions
     WHERE apex_session_id = p_session_id;
    --
    onlyoffice_pkg.create_apex_session(p_app_id     => l_app_id,
                                       p_user_name  => l_user_name,
                                       p_session_id => p_session_id);
    --
  END join_apex_session;
  --
END onlyoffice_pkg;
/
