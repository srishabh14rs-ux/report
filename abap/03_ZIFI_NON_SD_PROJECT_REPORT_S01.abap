*&---------------------------------------------------------------------*
*& Include          ZIFI_NON_SD_PROJECT_REPORT_S01
*&---------------------------------------------------------------------*
*& Selection screen
*&---------------------------------------------------------------------*

*--- Block 1 : Selection criteria -------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.

SELECT-OPTIONS:
  s_bukrs FOR acdoca-rbukrs OBLIGATORY,                " Company Code
  s_kunnr FOR acdoca-kunnr,                            " Customer
  s_prctr FOR acdoca-prctr,                            " Profit Centre
  s_aufnr FOR acdoca-aufnr,                            " Internal Order
  s_perio FOR acdoca-poper OBLIGATORY.                 " Period

PARAMETERS:
  p_gjahr TYPE acdoca-gjahr OBLIGATORY                 " Fiscal Year
          DEFAULT sy-datum(4).

SELECTION-SCREEN SKIP 1.
SELECTION-SCREEN END OF BLOCK b1.

*--- Block 2 : Report mode (radio buttons) ----------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.

PARAMETERS:
  p_rdpc RADIOBUTTON GROUP rg1 DEFAULT 'X'             " Profit Centre Based
         USER-COMMAND ucrad,
  p_rdio RADIOBUTTON GROUP rg1.                        " Internal Order Based

SELECTION-SCREEN END OF BLOCK b2.
