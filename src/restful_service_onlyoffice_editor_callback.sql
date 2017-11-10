set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- ORACLE Application Express (APEX) export file
--
-- You should run the script connected to SQL*Plus as the Oracle user
-- APEX_050100 or as the owner (parsing schema) of the application.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------
begin
wwv_flow_api.import_begin (
 p_version_yyyy_mm_dd=>'2016.08.24'
,p_default_workspace_id=>18494746576769720
);
end;
/
begin
wwv_flow_api.remove_restful_service(
 p_id=>wwv_flow_api.id(18601071144148066)
,p_name=>'ONLYOFFICE_EDITOR_CALLBACK'
);
 
end;
/
prompt --application/restful_services/onlyoffice_editor_callback
begin
wwv_flow_api.create_restful_module(
 p_id=>wwv_flow_api.id(18601071144148066)
,p_name=>'ONLYOFFICE_EDITOR_CALLBACK'
,p_uri_prefix=>'post/'
,p_parsing_schema=>'ONLYOFFICE'
,p_items_per_page=>25
,p_status=>'PUBLISHED'
,p_row_version_number=>17
);
wwv_flow_api.create_restful_template(
 p_id=>wwv_flow_api.id(18601183359148068)
,p_module_id=>wwv_flow_api.id(18601071144148066)
,p_uri_template=>'editorCallback/'
,p_priority=>0
,p_etag_type=>'HASH'
);
wwv_flow_api.create_restful_handler(
 p_id=>wwv_flow_api.id(18601279010148069)
,p_template_id=>wwv_flow_api.id(18601183359148068)
,p_source_type=>'PLSQL'
,p_format=>'DEFAULT'
,p_method=>'POST'
,p_require_https=>'YES'
,p_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'BEGIN',
'  onlyoffice_pkg.onlyoffice_editor_callback(p_body => :body);',
'END;'))
);
end;
/
begin
wwv_flow_api.import_end(p_auto_install_sup_obj => nvl(wwv_flow_application_install.get_auto_install_sup_obj, false));
commit;
end;
/
set verify on feedback on define on
prompt  ...done
