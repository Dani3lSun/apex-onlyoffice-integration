CREATE OR REPLACE PACKAGE onlyoffice_pkg IS
  --
  -- Package for ONLYOFFICE Functions
  --

  --
  -- Save uploaded dropzone files in "files" table
  -- #param p_collection_name
  PROCEDURE save_dropzone_files(p_collection_name IN VARCHAR2 := 'DROPZONE_UPLOAD');
  --
  -- Get Editor Config as JSON in HTP
  -- #param p_id
  -- #param p_editor_width
  -- #param p_editor_height
  -- #param p_file_author
  -- #param p_file_url
  -- #param p_callback_url
  PROCEDURE get_editor_config_json(p_id            IN files.id%TYPE,
                                   p_editor_width  IN VARCHAR2,
                                   p_editor_height IN VARCHAR2,
                                   p_file_author   IN VARCHAR2,
                                   p_file_url      IN VARCHAR2,
                                   p_callback_url  IN VARCHAR2);
  --
  -- Download a file from "files" table
  -- #param p_id
  -- #param p_content_disposition
  PROCEDURE download_file(p_id                  IN files.id%TYPE,
                          p_content_disposition IN VARCHAR2 := 'attachment');
  --
  -- Check if access for particular IP is allowed
  -- #param p_allowed_ip
  -- #return BOOLEAN
  FUNCTION is_access_allowed(p_allowed_ip IN VARCHAR2) RETURN BOOLEAN;
  --
  -- ONLYOFFICE Editor Webservice POST Callback (RESTful service) 
  -- #param p_app_id
  -- #param p_app_session
  -- #param p_body
  -- #param p_wallet_path
  -- #param p_wallet_pwd
  PROCEDURE onlyoffice_editor_callback(p_app_id      IN NUMBER,
                                       p_app_session IN NUMBER,
                                       p_body        BLOB,
                                       p_wallet_path IN VARCHAR2,
                                       p_wallet_pwd  IN VARCHAR2);
  --
  -- Creates a new APEX session 
  -- #param p_app_id
  -- #param p_user_name
  -- #param p_page_id
  -- #param p_session_id
  PROCEDURE create_apex_session(p_app_id     IN apex_applications.application_id%TYPE,
                                p_user_name  IN apex_workspace_sessions.user_name%TYPE,
                                p_page_id    IN apex_application_pages.page_id%TYPE DEFAULT NULL,
                                p_session_id IN apex_workspace_sessions.apex_session_id%TYPE DEFAULT NULL);
  --
  -- Joins an existing APEX session
  -- #param p_session_id
  -- #param p_app_id
  PROCEDURE join_apex_session(p_session_id IN apex_workspace_sessions.apex_session_id%TYPE,
                              p_app_id     IN apex_applications.application_id%TYPE DEFAULT NULL);
  --
END onlyoffice_pkg;
/
