CREATE OR REPLACE PACKAGE onlyoffice_pkg IS
  --
  -- Package for ONLYOFFICE Functions
  --

  --
  -- Global Variables
  --
  g_server_base_url          VARCHAR2(500) := 'https://onlyoffice.orclapex.io'; -- ONLYOFFICE Server Base URL
  g_override_server_base_url VARCHAR2(500) := 'http://localhost:8181'; -- Override Base URL for PL/SQL calls
  g_allowed_ip               VARCHAR2(100) := '192.168.8.1'; -- IP that is allowed to access files to download and REST callback interface
  g_ssl_wallet_path          VARCHAR2(500) := NULL; -- SSL Wallet Path, if ONLYOFFICE Server is accessible via HTTPS
  g_ssl_wallet_pwd           VARCHAR2(100) := NULL; -- SSL Wallet Password, if ONLYOFFICE Server is accessible via HTTPS

  --
  -- Exceptions Error Codes
  --
  error_http_status_code       CONSTANT NUMBER := -20002;
  error_onlyoffice_convert_api CONSTANT NUMBER := -20003;

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
  -- #param p_folder_name
  -- #param p_header_link
  -- #param p_about_name
  -- #param p_about_mail
  -- #param p_about_url
  -- #param p_about_address
  -- #param p_about_info
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
                                   p_about_info    IN VARCHAR2);
  --
  -- Download a file from "files" table
  -- #param p_id
  -- #param p_content_disposition
  PROCEDURE download_file(p_id                  IN files.id%TYPE,
                          p_content_disposition IN VARCHAR2 := 'attachment');
  --
  -- Download converted PDF file from "files" table
  -- #param p_id
  -- #param p_content_disposition
  -- #param p_file_url
  PROCEDURE download_file_pdf(p_id                  IN files.id%TYPE,
                              p_content_disposition IN VARCHAR2 := 'attachment',
                              p_file_url            IN VARCHAR2);
  --
  -- Download converted file from "files" table with specified output type
  -- #param p_id
  -- #param p_content_disposition
  -- #param p_file_url
  -- #param p_output_type
  -- #param p_thumbnail aspect:width:height, e.g 0:100:100
  PROCEDURE download_converted_file(p_id                  IN files.id%TYPE,
                                    p_content_disposition IN VARCHAR2 := 'attachment',
                                    p_file_url            IN VARCHAR2,
                                    p_output_type         IN VARCHAR2,
                                    p_thumbnail           IN VARCHAR2 := NULL);
  --
  -- Download converted thumbnail image of file from "files" table
  -- #param p_id
  -- #param p_content_disposition
  -- #param p_file_url
  -- #param p_thumbnail_aspect
  -- #param p_thumbnail_width
  -- #param p_thumbnail_height
  PROCEDURE download_file_thumbnail(p_id                  IN files.id%TYPE,
                                    p_content_disposition IN VARCHAR2 := 'attachment',
                                    p_file_url            IN VARCHAR2,
                                    p_thumbnail_aspect    IN NUMBER := 0,
                                    p_thumbnail_width     IN NUMBER := 100,
                                    p_thumbnail_height    IN NUMBER := 100);
  --
  -- Check if access for particular IP (g_allowed_ip) is allowed
  -- #return BOOLEAN
  FUNCTION is_access_allowed RETURN BOOLEAN;
  --
  -- ONLYOFFICE Editor Webservice POST Callback (RESTful service) 
  -- #param p_body
  PROCEDURE onlyoffice_editor_callback(p_body BLOB);
  --
  -- Converts a file to another file format, eg. docx --> pdf
  -- #param p_file_url
  -- #param p_output_type
  -- #param p_output_filename
  -- #param p_thumbnail aspect:width:height, e.g 0:100:100
  -- #return BLOB
  FUNCTION convert_file(p_file_url        IN VARCHAR2,
                        p_file_type       IN VARCHAR2,
                        p_output_type     IN VARCHAR2,
                        p_output_filename IN VARCHAR2 := NULL,
                        p_thumbnail       IN VARCHAR2 := NULL) RETURN BLOB;
  --
  -- Get mime type depending on file extension
  -- #param p_file_extension
  -- #return VARCHAR2
  FUNCTION get_mime_type(p_file_extension IN VARCHAR2) RETURN VARCHAR2;
  --
  -- Set all global package variables
  -- #param p_server_base_url
  -- #param p_override_server_base_url
  -- #param p_allowed_ip
  -- #param p_ssl_wallet_path
  -- #param p_ssl_wallet_path
  PROCEDURE set_global_pkg_vars(p_server_base_url          IN VARCHAR2,
                                p_override_server_base_url IN VARCHAR2 := NULL,
                                p_allowed_ip               IN VARCHAR2,
                                p_ssl_wallet_path          IN VARCHAR2 := NULL,
                                p_ssl_wallet_pwd           IN VARCHAR2 := NULL);
  --
END onlyoffice_pkg;
/
