*&---------------------------------------------------------------------*
*& Report  ZADF_DEMO_AZURE_EVENTHUB
*&
*&---------------------------------------------------------------------*
*&
*&
*&---------------------------------------------------------------------*
REPORT zadf_demo_azure_eventhub.

CONSTANTS: gc_interface TYPE zinterface_id VALUE 'DEMO_EHUB'.

TYPES: BEGIN OF lty_data,
         carrid    TYPE     s_carr_id,
         connid    TYPE    s_conn_id,
         fldate    TYPE    s_date,
         planetype TYPE    s_planetye,
       END OF lty_data.

DATA:       it_headers     TYPE tihttpnvp,
            wa_headers     TYPE LINE OF tihttpnvp,
            lv_string      TYPE string,
            lv_response    TYPE string,
            cx_interface   TYPE REF TO zcx_interace_config_missing,
            cx_http        TYPE REF TO zcx_http_client_failed,
            cx_adf_service TYPE REF TO zcx_adf_service,
            oref_eventhub  TYPE REF TO zcl_adf_service_eventhub,
            oref           TYPE REF TO zcl_adf_service,
            filter         TYPE zbusinessid,
            lv_http_status TYPE i,
            lo_json        TYPE REF TO cl_trex_json_serializer,
            lv1_string     TYPE string,
            lv_xstring     TYPE xstring,
            it_data        TYPE STANDARD TABLE OF lty_data.


*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK bl WITH FRAME TITLE text-001.
PARAMETERS: rb_se RADIOBUTTON GROUP rad1 DEFAULT 'X',    " Send data to eventhub
            rb_cg RADIOBUTTON GROUP rad1,                " Create Consumer Group
            rb_dc RADIOBUTTON GROUP rad1,                " Delete Consumer Group
            rb_cd RADIOBUTTON GROUP rad1,                " Consumer group details
            rb_cl RADIOBUTTON GROUP rad1.                " Consumer list details
*            rb_sb RADIOBUTTON GROUP rad1.                " Send batch data
SELECTION-SCREEN END OF BLOCK bl.


TRY.
**Calling Factory method to instantiate eventhub client

    oref = zcl_adf_service_factory=>create( iv_interface_id = gc_interface
                                            iv_business_identifier = filter ).
    oref_eventhub ?= oref.

**Setting Expiry time
    CALL METHOD oref_eventhub->add_expiry_time
      EXPORTING
        iv_expiry_hour = 0
        iv_expiry_min  = 15
        iv_expiry_sec  = 0.


    IF NOT rb_se IS INITIAL.  " create consumer group.

*Sample data population for sending it to Azure eventhub
      SELECT  carrid connid fldate planetype
           FROM sflight UP TO 10 ROWS
           INTO TABLE it_data.
      IF sy-subrc EQ 0.
        CREATE OBJECT lo_json
          EXPORTING
            data = it_data.
        lo_json->serialize( ).
        lv1_string  = lo_json->get_data( ).


*Convert input string data to Xstring format
        CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
          EXPORTING
            text   = lv1_string
          IMPORTING
            buffer = lv_xstring
          EXCEPTIONS
            failed = 1
            OTHERS = 2.
        IF sy-subrc <> 0.
        ENDIF.

**Sending Converted SAP data to Azure Eventhub
        CALL METHOD oref_eventhub->send
          EXPORTING
            request        = lv_xstring  "Input XSTRING of SAP Business Event data
            it_headers     = it_headers  "Header attributes
          IMPORTING
            response       = lv_response       "Response from EventHub
            ev_http_status = lv_http_status.   "Status


        IF lv_http_status NE '201' AND
           lv_http_status NE '200'.
          MESSAGE 'SAP data not sent to Azure EventHub' TYPE 'E'.
        ELSE.
          MESSAGE 'SAP data sent to Azure EventHub' TYPE 'I'.
        ENDIF.
      ELSE.
        MESSAGE 'No data in SFLIFHT' TYPE 'E'.
      ENDIF.



    ELSEIF NOT rb_cg IS INITIAL.  " create consumer group.
      CALL METHOD oref_eventhub->create_consumer_group
        EXPORTING
          iv_consumer_group = 'TestKT'        "Input XSTRING of SAP Business Event data
        IMPORTING
          response          = lv_response       "Response from EventHub
          ev_http_status    = lv_http_status.   "Status


      IF lv_http_status NE '201' AND
         lv_http_status NE '200'.
        MESSAGE 'Consumer Group not created in Azure EventHub' TYPE 'E'.
      ELSE.
        MESSAGE 'Consumer Group created in Azure EventHub' TYPE 'I'.
      ENDIF.


    ELSEIF NOT rb_dc IS INITIAL.  " Delete consumer group
      CALL METHOD oref_eventhub->delete_consumer_group
        EXPORTING
          iv_consumer_group = 'TestKT'        "Input XSTRING of SAP Business Event data
        IMPORTING
          response          = lv_response       "Response from EventHub
          ev_http_status    = lv_http_status.   "Status


      IF lv_http_status NE '201' AND
         lv_http_status NE '200'.
        MESSAGE 'Consumer Group not eleted in Azure EventHub' TYPE 'E'.
      ELSE.
        MESSAGE 'Consumer Group deleted in Azure EventHub' TYPE 'I'.
      ENDIF.


    ELSEIF NOT rb_cd IS INITIAL.
      CALL METHOD oref_eventhub->get_consumer_group_details
        EXPORTING
          iv_consumer_group = 'TestKT'        "Input XSTRING of SAP Business Event data
        IMPORTING
          response          = lv_response       "Response from EventHub
          ev_http_status    = lv_http_status.   "Status


      IF lv_http_status NE '201' AND
         lv_http_status NE '200'.
        MESSAGE 'Consumer Group details are not received' TYPE 'E'.
      ELSE.
        MESSAGE 'Consumer Group details received from Azure EventHub' TYPE 'I'.
      ENDIF.


    ELSEIF NOT rb_cl IS INITIAL.  " Consmuer list
      CALL METHOD oref_eventhub->get_list_consumer_group
        IMPORTING
          response       = lv_response       "Response from EventHub
          ev_http_status = lv_http_status.   "Status

      IF lv_http_status NE '201' AND
         lv_http_status NE '200'.
        MESSAGE 'Consumer Group list are not received' TYPE 'E'.
      ELSE.
        MESSAGE 'Consumer Group list received from Azure EventHub' TYPE 'I'.
      ENDIF.
    ENDIF.
  CATCH zcx_interace_config_missing INTO cx_interface.
    lv_string = cx_interface->get_text( ).
    MESSAGE lv_string TYPE 'E'.
  CATCH zcx_http_client_failed INTO cx_http .
    lv_string = cx_http->get_text( ).
    MESSAGE lv_string TYPE 'E'.
  CATCH zcx_adf_service INTO cx_adf_service.
    lv_string = cx_adf_service->get_text( ).
    MESSAGE lv_string TYPE 'E'.

ENDTRY.
