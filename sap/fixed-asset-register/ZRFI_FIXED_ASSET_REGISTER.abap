*&---------------------------------------------------------------------*
*& Report  ZFIXED_ASSET_REGISTER
*&---------------------------------------------------------------------*
*& Description : Fixed Asset Register Report - SAP FI-AA (S/4HANA)
*&               Displays consolidated asset-level financial data
*&               including procurement details, asset master info,
*&               GL account postings, and all asset movement values.
*& Output      : ALV Grid with subtotals by Asset Class & Company Code
*& Author      : EKX Deep Agent
*& Date        : 03.06.2026
*&---------------------------------------------------------------------*
*& COLUMN MAP (29 Output Columns):
*&  01-Company Code    02-Purchase Order  03-Vendor Name
*&  04-Profit Center   05-Original Asset  06-Asset (No+Sub)
*&  07-Movement        08-Qty             09-Useful Life
*&  10-Dep Start Date  11-Asset Desc      12-Currency
*&  13-Asset Class     14-Class Desc      15-GL Account
*&  16-GL Acct Desc    17-Opening         18-Addition
*&  19-Impairment      20-Retirement      21-Transferred
*&  22-In/Out          23-CIP Cost        24-Total Acq Cost
*&  25-Dep Beginning   26-Dep Period      27-Dep Retirement
*&  28-Dep End         29-Book Value
*&---------------------------------------------------------------------*
*& NOTE: Col 05 (Original Asset) uses ANLA-INVNR (standard SAP field,
*&       CHAR25). If a custom append field AIBN1 exists in your ANLA,
*&       replace INVNR with AIBN1 in the SELECT and structure.
*&---------------------------------------------------------------------*

REPORT zrfi_fixed_asset_register NO STANDARD PAGE HEADING LINE-SIZE 400.
INCLUDE zfi_fixed_asset_register_top.
INCLUDE zfi_fixed_asset_register_f01.

*----------------------------------------------------------------------*
* INITIALIZATION
*----------------------------------------------------------------------*
INITIALIZATION.
*  TEXT-B01 = 'Fixed Asset Register - Selection Parameters'.
  p_gjahr  = sy-datum(4).

*----------------------------------------------------------------------*
* AT SELECTION-SCREEN - Input Validation
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
  IF p_peraf > p_perat.
    MESSAGE 'Posting Period From must not exceed Posting Period To.' TYPE 'E'.
  ENDIF.
  IF p_afabe IS INITIAL.
    p_afabe = gc_afabe.
  ENDIF.

*----------------------------------------------------------------------*
* START-OF-SELECTION
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM f_get_data.

*----------------------------------------------------------------------*
* END-OF-SELECTION - ALV Display
*----------------------------------------------------------------------*
END-OF-SELECTION.
  PERFORM f_build_fieldcat.
  PERFORM f_build_sort.
  PERFORM f_display_alv.
