*&---------------------------------------------------------------------*
*& Include          ZFI_FIXED_ASSET_REGISTER_F01
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* FORM: Build ALV Field Catalog (29 Columns)
*----------------------------------------------------------------------*
FORM f_build_fieldcat.

  DATA: ls_fcat TYPE lvc_s_fcat,
        lv_pos  TYPE i VALUE 0.

  DEFINE add_col.
    lv_pos = lv_pos + 1.
    CLEAR ls_fcat.
    ls_fcat-col_pos   = lv_pos.
    ls_fcat-fieldname = &1.
    ls_fcat-coltext   = &2.
    ls_fcat-seltext   = &2.
    ls_fcat-outputlen = &3.
    ls_fcat-just      = &4.
    APPEND ls_fcat TO gt_fieldcat.
  END-OF-DEFINITION.

  DEFINE add_curr.
    lv_pos = lv_pos + 1.
    CLEAR ls_fcat.
    ls_fcat-col_pos    = lv_pos.
    ls_fcat-fieldname  = &1.
    ls_fcat-coltext    = &2.
    ls_fcat-seltext    = &2.
    ls_fcat-outputlen  = 18.
    ls_fcat-just       = 'R'.
    ls_fcat-cfieldname = 'WAERS'.
    ls_fcat-do_sum     = 'X'.
    APPEND ls_fcat TO gt_fieldcat.
  END-OF-DEFINITION.

  add_col  'BUKRS'      'Company Code'          6    'L'.  " 01
  add_col  'EBELN'      'Purchase Order'        12   'L'.  " 02
  add_col  'NAME1'      'Vendor Name'           35   'L'.  " 03
  add_col  'PRCTR'      'Profit Center'         10   'L'.  " 04
  add_col  'AIBN1'      'Original Asset'        25   'L'.  " 05
  add_col  'ANLN1'      'Asset No.'             12   'L'.  " 06
  add_col  'ANLN2'      'Sub-Asset'             4    'L'.  " 06
  add_col  'BWASL'      'Movement'              6    'C'.  " 07
  add_col  'MENGE'      'Qty'                   10   'R'.  " 08
  add_col  'NDJAR'      'Useful Life Yr'        6    'R'.  " 09
  add_col  'NDPER'      'Useful Life Per'       6    'R'.  " 09
  add_col  'AFABG'      'Dep. Start Date'       10   'C'.  " 10
  add_col  'TXT50'      'Asset Description'     40   'L'.  " 11
  add_col  'WAERS'      'Currency'              5    'C'.  " 12
  add_col  'ANLKL'      'Asset Class'           8    'L'.  " 13
  add_col  'TXK50'      'Asset Class Desc'      30   'L'.  " 14
  add_col  'SAKNR'      'GL Account'            10   'L'.  " 15
  add_col  'TXT20'      'GL Acct Desc'          20   'L'.  " 16
  add_curr 'OPENING'    'Opening'.                        " 17
  add_curr 'ADDITION'   'Addition'.                       " 18
  add_curr 'IMPAIRMENT' 'Impairment'.                     " 19
  add_curr 'RETIREMENT' 'Asset Retirement'.               " 20
  add_curr 'TRANSFER'   'Transferred'.                    " 21
  add_curr 'INOUT'      'In/Out'.                         " 22
  add_curr 'CIP_COST'   'CIP Cost'.                       " 23
  add_curr 'TOT_ACQ'    'Total Acq. Cost'.                " 24
  add_curr 'DEP_BEG'    'Dep. Beginning'.                 " 25
  add_curr 'DEP_PER'    'Dep. Period'.                    " 26
  add_curr 'DEP_RET'    'Dep. Retirement'.                " 27
  add_curr 'DEP_END'    'Dep. End'.                       " 28
  add_curr 'BOOK_VAL'   'Book Value'.                     " 29

ENDFORM.

*----------------------------------------------------------------------*
* FORM: Build Sort Criteria with Subtotals
*----------------------------------------------------------------------*
FORM f_build_sort.

  DATA ls_sort TYPE lvc_s_sort.

  " Sort & Subtotal by Company Code
  CLEAR ls_sort.
  ls_sort-spos      = 1.
  ls_sort-fieldname = 'BUKRS'.
  ls_sort-up        = 'X'.
  ls_sort-subtot    = 'X'.
  APPEND ls_sort TO gt_sort.

  " Sort & Subtotal by Asset Class
  CLEAR ls_sort.
  ls_sort-spos      = 2.
  ls_sort-fieldname = 'ANLKL'.
  ls_sort-up        = 'X'.
  ls_sort-subtot    = 'X'.
  APPEND ls_sort TO gt_sort.

ENDFORM.

*----------------------------------------------------------------------*
* FORM: Display ALV Grid
*----------------------------------------------------------------------*
FORM f_display_alv.

  ls_layout-zebra      = 'X'.
  ls_layout-cwidth_opt = 'X'.
*  ls_layout-totals_aft = 'X'.


  ls_variant-report  = sy-repid.
  ls_variant-variant = '/DEFAULT'.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
      i_callback_program     = sy-repid
      i_callback_top_of_page = 'TOP_OF_PAGE'
      is_layout_lvc          = ls_layout
      it_fieldcat_lvc        = gt_fieldcat
      it_sort_lvc            = gt_sort
      is_variant             = ls_variant
      i_save                 = 'A'
      i_default              = 'X'
    TABLES
      t_outtab               = gt_output
    EXCEPTIONS
      program_error          = 1
      OTHERS                 = 2.

  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

ENDFORM.

*----------------------------------------------------------------------*
* FORM: Top of Page Header for ALV
*----------------------------------------------------------------------*
FORM top_of_page.

  DATA: lt_header TYPE slis_t_listheader,
        ls_header TYPE slis_listheader,
        lv_period TYPE string.

  CLEAR lt_header.

  " Title
  ls_header-typ  = 'H'.
  ls_header-info = 'Fixed Asset Register'.
  APPEND ls_header TO lt_header.

  " Fiscal Year
  CLEAR ls_header.
  ls_header-typ  = 'S'.
  ls_header-key  = 'Fiscal Year  :'.
  ls_header-info = p_gjahr.
  APPEND ls_header TO lt_header.

  " Posting Period Range
  CLEAR ls_header.
  ls_header-typ  = 'S'.
  ls_header-key  = 'Period       :'.
  CONCATENATE p_peraf ' - ' p_perat INTO lv_period.
  ls_header-info = lv_period.
  APPEND ls_header TO lt_header.

  " Depreciation Area
  CLEAR ls_header.
  ls_header-typ  = 'S'.
  ls_header-key  = 'Dep. Area    :'.
  ls_header-info = p_afabe.
  APPEND ls_header TO lt_header.

  " Run Date
  CLEAR ls_header.
  ls_header-typ  = 'S'.
  ls_header-key  = 'Run Date     :'.
  WRITE sy-datum TO ls_header-info DD/MM/YYYY.
  APPEND ls_header TO lt_header.

  CALL FUNCTION 'REUSE_ALV_COMMENTARY_WRITE'
    EXPORTING
      it_list_commentary = lt_header.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_get_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM f_get_data .

  DATA: lt_anlkl_range TYPE RANGE OF anlkl,
        ls_anlkl_range LIKE LINE OF lt_anlkl_range.
  " Compute previous fiscal year (for Dep. Beginning Col 25)
  gv_gjahr_py = p_gjahr - 1.

  " Read AUC Asset Class from setname ZFI_AUC_CLASS
  SELECT valsign, valoption,valfrom,valto
    FROM setleaf
    INTO TABLE @DATA(lt_setleaf)
    WHERE setname = 'ZFI_AUC_CLASS'.

  LOOP AT lt_setleaf INTO DATA(ls_setleaf).
    ls_anlkl_range-sign   = ls_setleaf-valsign.
    ls_anlkl_range-option = ls_setleaf-valoption.
    ls_anlkl_range-low    = ls_setleaf-valfrom.
    ls_anlkl_range-high   = ls_setleaf-valto.
    APPEND ls_anlkl_range TO lt_anlkl_range.
    CLEAR ls_anlkl_range.
  ENDLOOP.

  "----------------------------------------------------------------------
  " Group 1: T001 - Company Code, Currency, Chart of Accounts (Col 1, 12)
  "----------------------------------------------------------------------
  SELECT bukrs waers ktopl
    INTO TABLE gt_t001
    FROM t001
    WHERE bukrs IN s_bukrs.

  IF gt_t001 IS INITIAL.
    MESSAGE 'No company codes found for the given selection.' TYPE 'S'
            DISPLAY LIKE 'W'.
    STOP.
  ENDIF.

  " Derive KTOPL from first company code (used for SKAT lookup)
  READ TABLE gt_t001 INTO ls_t001 INDEX 1.
  gv_ktopl = ls_t001-ktopl.

  "----------------------------------------------------------------------
  " Group 2: ANLA - Asset Master (Cols 5, 6, 11, 13)
  "          ANLZ - Profit Center time-dependent (Col 4)
  "----------------------------------------------------------------------
  SELECT bukrs anln1 anln2 txt50 anlkl ktogr menge aibn1
    INTO TABLE gt_anla
    FROM anla
    WHERE bukrs IN s_bukrs
      AND anlkl IN s_anlkl
      AND anln1 IN s_anln1.

  IF gt_anla IS INITIAL.
    MESSAGE 'No assets found for the given selection.' TYPE 'S'
            DISPLAY LIKE 'W'.
    STOP.
  ENDIF.

  " ANLZ: Time-dependent - Profit Center (Col 4)
  " BDATU >= SY-DATUM ensures we get currently valid records
  SELECT bukrs anln1 anln2 bdatu prctr
    INTO TABLE gt_anlz
    FROM anlz
    WHERE bukrs IN s_bukrs
      AND bdatu  >= sy-datum.

  "----------------------------------------------------------------------
  " Group 3: ANKT - Asset Class Description (Col 14)
  "----------------------------------------------------------------------
  SELECT spras anlkl txk50
    INTO TABLE gt_ankt
    FROM ankt
    WHERE spras = sy-langu.

  "----------------------------------------------------------------------
  " Group 4: ANLB - Useful Life + Dep. Start Date (Cols 9, 10)
  "          Filter: AFABE = selected depreciation area (default 01)
  "----------------------------------------------------------------------
  SELECT bukrs anln1 anln2 afabe ndjar ndper afabg
    INTO TABLE gt_anlb
    FROM anlb
    WHERE bukrs IN s_bukrs
      AND afabe  = p_afabe.




  IF gt_anla IS NOT INITIAL.

    "----------------------------------------------------------------------
    " Group 5: ANLC - Annual Asset Values, Current Year (Cols 17-28)
    "----------------------------------------------------------------------

    SELECT bukrs anln1 anln2 gjahr afabe
           kansw kaufw knafa nafap nafav answl abgan
      INTO TABLE gt_anlc
      FROM anlc
      FOR ALL ENTRIES IN gt_anla
     WHERE bukrs IN s_bukrs
       AND anln1  = gt_anla-anln1
       AND anln2  = gt_anla-anln2
       AND gjahr  = p_gjahr
       AND afabe  = p_afabe.

    " ANLC Previous Year: for Col 25 Dep. Beginning (prev year KNAFA)
    SELECT bukrs anln1 anln2 gjahr afabe
           kansw kaufw knafa answl nafav
          INTO TABLE gt_anlc_py
          FROM anlc
          FOR ALL ENTRIES IN gt_anla
          WHERE bukrs IN s_bukrs
            AND anln1  = gt_anla-anln1
            AND anln2  = gt_anla-anln2
            AND gjahr  = gv_gjahr_py
            AND afabe  = p_afabe.

    SORT gt_anlc_py BY bukrs anln1 anln2 afabe gjahr.

    "----------------------------------------------------------------------
    " Group 6: ANEK/ANEP - Asset Transactions (Cols 7, 8, 19, 20, 21, 22)
    "----------------------------------------------------------------------
    SELECT bukrs anln1 anln2 gjahr belnr "bwasl
      INTO TABLE gt_anek
      FROM anek
       FOR ALL ENTRIES IN gt_anla
      WHERE bukrs IN s_bukrs
       AND anln1  = gt_anla-anln1.

    SELECT bukrs anln1 anln2 gjahr belnr lnran bwasl anbtr
      INTO TABLE gt_anep
      FROM anep
      FOR ALL ENTRIES IN gt_anla
      WHERE bukrs IN s_bukrs
        AND anln1  = gt_anla-anln1
        AND afabe  = p_afabe.
  ENDIF.


  "----------------------------------------------------------------------
  " Group 6 (cont): T095 - GL Account from Asset Account Determination
  "                 Pass ANLA-KTOGR -> T095 to get KTANSW (Col 15)
  "----------------------------------------------------------------------
  SELECT afabe ktogr ktansw
    INTO TABLE gt_t095
    FROM t095
    WHERE afabe  = p_afabe.

  "----------------------------------------------------------------------
  " Group 7: SKAT - GL Account Description (Col 16)
  "----------------------------------------------------------------------
  SELECT spras ktopl saknr txt20
    INTO TABLE gt_skat
    FROM skat
    WHERE spras = sy-langu
      AND ktopl = gv_ktopl.

  "----------------------------------------------------------------------
  " Group 8: ACDOCA - Universal Journal -> PO Number (Col 2)
  "          AWREF = ANEP-BELNR links asset doc to universal journal
  "----------------------------------------------------------------------
  LOOP AT gt_anek INTO ls_anek.
    ls_belnr_range-sign   = 'I'.
    ls_belnr_range-option = 'EQ'.
    ls_belnr_range-low    = ls_anek-belnr.
    APPEND ls_belnr_range TO gt_belnr_range.
  ENDLOOP.

  IF gt_belnr_range IS NOT INITIAL AND gt_anep IS NOT INITIAL.
    SELECT rbukrs gjahr belnr awref ebeln lifnr
      INTO TABLE gt_acdoca
      FROM acdoca
      FOR ALL ENTRIES IN gt_anep
      WHERE rldnr = '0L'
        AND rbukrs IN s_bukrs
        AND gjahr = gt_anep-gjahr
        AND awref   IN gt_belnr_range
        AND koart  =  'A'.
  ENDIF.

  "----------------------------------------------------------------------
  " Group 9: RBKP -> LFA1 - Vendor Name (Col 3)
  "          ANEP-BELNR -> RBKP-BELNR (MM invoice) -> LIFNR -> LFA1
  "----------------------------------------------------------------------
  LOOP AT gt_anep INTO ls_anep.
    ls_rbkp_belnr-sign   = 'I'.
    ls_rbkp_belnr-option = 'EQ'.
    ls_rbkp_belnr-low    = ls_anep-belnr.
    APPEND ls_rbkp_belnr TO gt_rbkp_belnr.
  ENDLOOP.

  IF gt_rbkp_belnr IS NOT INITIAL.
    SELECT bukrs gjahr belnr lifnr
      INTO TABLE gt_rbkp
      FROM rbkp
      WHERE bukrs IN s_bukrs
        AND gjahr  = p_gjahr
        AND belnr  IN gt_rbkp_belnr.
  ENDIF.

  " Collect LIFNRs from RBKP
  LOOP AT gt_rbkp INTO ls_rbkp.
    IF ls_rbkp-lifnr IS NOT INITIAL.
      ls_lifnr_range-sign   = 'I'.
      ls_lifnr_range-option = 'EQ'.
      ls_lifnr_range-low    = ls_rbkp-lifnr.
      APPEND ls_lifnr_range TO gt_lifnr_range.
    ENDIF.
  ENDLOOP.

  " Also collect LIFNRs from ACDOCA
  LOOP AT gt_acdoca INTO ls_acdoca.
    IF ls_acdoca-lifnr IS NOT INITIAL.
      ls_lifnr_range-sign   = 'I'.
      ls_lifnr_range-option = 'EQ'.
      ls_lifnr_range-low    = ls_acdoca-lifnr.
      APPEND ls_lifnr_range TO gt_lifnr_range.
    ENDIF.
  ENDLOOP.

  " Read LFA1 - Vendor Names
  IF gt_lifnr_range IS NOT INITIAL.
    SELECT lifnr name1
      INTO TABLE gt_lfa1
      FROM lfa1
      WHERE lifnr IN gt_lifnr_range.
  ENDIF.

  "----------------------------------------------------------------------
  " Build Impairment BWASL Range (Col 19)
  " BWASL: 800, 820, 891-898, R00, R01, R10, S01, S10
  "----------------------------------------------------------------------
  ls_imp_r-sign   = 'I'.
  ls_imp_r-option = 'EQ'.

  ls_imp_r-low = '800'. APPEND ls_imp_r TO gr_imp.
  ls_imp_r-low = '820'. APPEND ls_imp_r TO gr_imp.
  ls_imp_r-low = '891'. APPEND ls_imp_r TO gr_imp.
  ls_imp_r-low = '892'. APPEND ls_imp_r TO gr_imp.
  ls_imp_r-low = '893'. APPEND ls_imp_r TO gr_imp.
  ls_imp_r-low = '896'. APPEND ls_imp_r TO gr_imp.
  ls_imp_r-low = '897'. APPEND ls_imp_r TO gr_imp.
  ls_imp_r-low = '898'. APPEND ls_imp_r TO gr_imp.
  ls_imp_r-low = 'R00'. APPEND ls_imp_r TO gr_imp.
  ls_imp_r-low = 'R01'. APPEND ls_imp_r TO gr_imp.
  ls_imp_r-low = 'R10'. APPEND ls_imp_r TO gr_imp.
  ls_imp_r-low = 'S01'. APPEND ls_imp_r TO gr_imp.
  ls_imp_r-low = 'S10'. APPEND ls_imp_r TO gr_imp.

  "----------------------------------------------------------------------
  " Main Loop: Build Output (One Row Per Asset)
  "----------------------------------------------------------------------
  LOOP AT gt_anla INTO ls_anla.

    " Clear all work areas for this asset iteration
    CLEAR: ls_output, ls_anlz, ls_anlb, ls_anlc, ls_anc_py,
           ls_anek,   ls_t095, ls_ankt, ls_skat,
           ls_acdoca, ls_rbkp, ls_lfa1, gv_lifnr.
    CLEAR: lv_imp_amt, lv_ret_amt, lv_trf_amt,
           lv_in_amt,  lv_out_amt, lv_add_auc.

    "--- Col 01: Company Code ---
    ls_output-bukrs = ls_anla-bukrs.

    "--- Col 06: Asset Number + Sub-Asset ---
    ls_output-anln1 = ls_anla-anln1.
    ls_output-anln2 = ls_anla-anln2.

    " Col 08: Quantity (sum all line items)
    ls_output-menge = ls_anla-menge.

    "--- Col 11: Asset Description ---
    ls_output-txt50 = ls_anla-txt50.

    "--- Col 13: Asset Class ---
    ls_output-anlkl = ls_anla-anlkl.

    "--- Col 05: Original Asset (INVNR) ---
    ls_output-aibn1 = ls_anla-aibn1.

    "--- Col 12: Currency from T001 ---
    READ TABLE gt_t001 INTO ls_t001
      WITH KEY bukrs = ls_anla-bukrs.
    IF sy-subrc = 0.
      ls_output-waers = ls_t001-waers.
    ENDIF.


    "--- AUC Class Check ---
*    IF gv_auc_class IS NOT INITIAL AND ls_anla-anlkl = gv_auc_class.
*      gv_is_auc = abap_true.
*    ELSE.
*      gv_is_auc = abap_false.
*    ENDIF.
    READ TABLE lt_setleaf TRANSPORTING NO FIELDS WITH KEY valfrom = ls_anla-anlkl.
    IF sy-subrc = 0.
      gv_is_auc = abap_true.
    ELSE.
      gv_is_auc = abap_false.
    ENDIF.


    "--- Col 04: Profit Center from ANLZ (time-valid: BDATU >= SY-DATUM) ---
    LOOP AT gt_anlz INTO ls_anlz
      WHERE bukrs = ls_anla-bukrs
        AND anln1 = ls_anla-anln1
        AND anln2 = ls_anla-anln2.
      ls_output-prctr = ls_anlz-prctr.
      EXIT.
    ENDLOOP.

    "--- Profit Center selection filter ---
    IF s_prctr IS NOT INITIAL.
      CHECK ls_output-prctr IN s_prctr.
    ENDIF.

    "--- Col 09 + Col 10: Useful Life (Years/Periods) + Dep. Start Date ---
    READ TABLE gt_anlb INTO ls_anlb
      WITH KEY bukrs = ls_anla-bukrs
               anln1 = ls_anla-anln1
               anln2 = ls_anla-anln2
               afabe = p_afabe
      BINARY SEARCH.
    IF sy-subrc = 0.
      ls_output-ndjar = ls_anlb-ndjar.
      ls_output-ndper = ls_anlb-ndper.
      ls_output-afabg = ls_anlb-afabg.
    ENDIF.

    "--- Col 14: Asset Class Description from ANKT ---
    READ TABLE gt_ankt INTO ls_ankt
      WITH KEY spras = sy-langu
               anlkl = ls_anla-anlkl
      BINARY SEARCH.
    IF sy-subrc = 0.
      ls_output-txk50 = ls_ankt-txk50.
    ENDIF.

    "--- Col 15: GL Account - T095 keyed by BUKRS + AFABE + KTOGR ---
    READ TABLE gt_t095 INTO ls_t095
      WITH KEY "bukrs  = ls_anla-bukrs
               afabe  = p_afabe
               ktogr  = ls_anla-ktogr
      BINARY SEARCH.
    IF sy-subrc = 0.
      ls_output-saknr = ls_t095-ktansw.
    ENDIF.

    "--- Col 16: GL Account Description from SKAT ---
    IF ls_output-saknr IS NOT INITIAL.
      READ TABLE gt_skat INTO ls_skat
        WITH KEY spras = sy-langu
                 ktopl = gv_ktopl
                 saknr = ls_output-saknr
        BINARY SEARCH.
      IF sy-subrc = 0.
        ls_output-txt20 = ls_skat-txt20.
      ENDIF.
    ENDIF.

    "--- ANLC Current Year ---
    READ TABLE gt_anlc INTO ls_anlc
      WITH KEY bukrs = ls_anla-bukrs
               anln1 = ls_anla-anln1
               anln2 = ls_anla-anln2
               afabe = p_afabe.
*               gjahr = p_gjahr
*      BINARY SEARCH.

    "--- ANLC Previous Year (for Col 25: Dep. Beginning) ---
    READ TABLE gt_anlc_py INTO ls_anc_py
      WITH KEY bukrs = ls_anla-bukrs
               anln1 = ls_anla-anln1
               anln2 = ls_anla-anln2
               afabe = p_afabe.
*               gjahr = gv_gjahr_py
*      BINARY SEARCH.

    "--- Col 17: Opening = ANLC-ANSWT ---
    ls_output-opening = ls_anlc-kansw.

    "--- Col 23: CIP Cost = ANLC-KAUFW ---
*    ls_output-cip_cost = ls_anlc-kaufw.

    "--- Col 25: Dep. Beginning = Previous Year ANLC-KNAFA ---
    ls_output-dep_beg = ls_anlc-nafav.

    "    "--- Col 26: Dep. Period = ANLC-NAFAG (planned dep for fiscal year) ---
*    ls_output-dep_per = ls_anlc-knafa.
    ls_output-dep_per = ls_anlc-knafa + ls_anlc-nafap .

    "--- Col 27: Dep. Retirement = ANLC-ABGAF ---
*    ls_output-dep_ret = ls_anlc-abgaf.

    "--- Col 28: Dep. End = Current Year ANLC-KNAFA (cumulative) ---
*    ls_output-dep_end =  ls_anlc-nafap .
*    ls_output-dep_end = ls_anlc-nafav + ls_anlc-knafa + ls_anlc-abgan.
    ls_output-dep_end =  ls_output-dep_beg + ls_output-dep_per + ls_output-dep_ret .

    "--- Col 07: Primary Movement Type from ANEK (first doc this year) ---
    READ TABLE gt_anek INTO ls_anek
      WITH KEY bukrs = ls_anla-bukrs
               anln1 = ls_anla-anln1
               anln2 = ls_anla-anln2
*               gjahr = p_gjahr
      BINARY SEARCH.
    IF sy-subrc = 0.
      ls_output-bwasl = ls_anek-bwasl.
    ENDIF.

    "------------------------------------------------------------------
    " Loop ANEP for this asset - compute Cols 8, 18, 19, 20, 21, 22
    "------------------------------------------------------------------
    LOOP AT gt_anep INTO ls_anep
      WHERE bukrs = ls_anla-bukrs
        AND anln1 = ls_anla-anln1
        AND anln2 = ls_anla-anln2
        AND gjahr = p_gjahr.

      " Col 19: Impairment (BWASL in defined impairment range)
      IF ls_anep-bwasl IN gr_imp.
        lv_imp_amt = lv_imp_amt + ls_anep-anbtr.
      ENDIF.

      " Col 20: Asset Retirement (BWASL 200-299 = retirement types)
      IF ls_anep-bwasl >= '200' AND ls_anep-bwasl <= '299'.
        lv_ret_amt = lv_ret_amt + ls_anep-anbtr.
      ENDIF.

      " Col 22: In/Out - BWASL=100 is In, BWASL=105 is Out
      IF ls_anep-bwasl = gc_bwasl_100.
        lv_in_amt = lv_in_amt + ls_anep-anbtr.
      ELSEIF ls_anep-bwasl = gc_bwasl_105.
        lv_out_amt = lv_out_amt + ls_anep-anbtr.
      ENDIF.

      " Col 18 + 21: AUC Split Logic
      " For AUC assets: Addition = BWASL=100, Transferred = BWASL=310
      " ANLC-ANSWL = ANEP-ANBTR total (validation: ANSWL = add + transfer)
      IF gv_is_auc = abap_true.
        IF ls_anep-bwasl = gc_bwasl_100.
          lv_add_auc = lv_add_auc + ls_anep-anbtr.
        ELSEIF ls_anep-bwasl = gc_bwasl_310.
          lv_trf_amt = lv_trf_amt + ls_anep-anbtr.
        ENDIF.
      ENDIF.

    ENDLOOP.

    "--- Col 19: Impairment ---
    ls_output-impairment = lv_imp_amt.

    "--- Col 20: Retirement ---
    ls_output-retirement = lv_ret_amt.

    "--- Col 22: In/Out Net (In minus Out) ---
*    ls_output-inout = lv_in_amt - lv_out_amt.

    "--- Col 18: Addition ---
    " AUC: from ANEP BWASL=100 | Non-AUC: from ANLC-KANSW
    IF gv_is_auc = abap_true.
      ls_output-addition = lv_add_auc.

*    ELSE.
*      ls_output-addition = ls_anlc-answl.

    ELSEIF ls_anlc-answl > 0.
      ls_output-addition = ls_anlc-answl.
    ENDIF.

    "--- Col 21: Transferred ---
    " AUC: from ANEP BWASL=310 | Non-AUC: from ANLC-ANSWL
*    IF gv_is_auc = abap_true.
*      ls_output-transfer = lv_trf_amt.
*    ELSE.
*      ls_output-transfer = ls_anlc-answl.
*    ENDIF.

    "--- Col 24: Total Acquisition Cost = Opening + Addition ---
    ls_output-tot_acq = ls_output-opening + ls_output-addition + ls_output-impairment + ls_output-retirement + ls_output-transfer + ls_output-inout.

    "--- Col 29: Book Value = Total Acq. Cost - Dep. End ---
*    ls_output-book_val = ls_output-tot_acq - ls_output-dep_end.
    ls_output-book_val = ls_output-tot_acq + ls_output-dep_end.

    "------------------------------------------------------------------
    " PO + Vendor Derivation (Cols 02, 03)
    " Strategy 1: ACDOCA (AWREF = ANEP-BELNR) -> EBELN, LIFNR
    " Strategy 2: RBKP  (BELNR = ANEP-BELNR) -> LIFNR -> LFA1
    "------------------------------------------------------------------
    LOOP AT gt_anep INTO ls_anep
      WHERE bukrs = ls_anla-bukrs
        AND anln1 = ls_anla-anln1
        AND anln2 = ls_anla-anln2.
*        AND gjahr = p_gjahr.

      " Try ACDOCA first
      READ TABLE gt_acdoca INTO ls_acdoca
        WITH KEY rbukrs = ls_anla-bukrs
                 gjahr  = ls_anep-gjahr
                 awref  = ls_anep-belnr
        BINARY SEARCH.
      IF sy-subrc = 0.
        IF ls_output-ebeln IS INITIAL AND ls_acdoca-ebeln IS NOT INITIAL.
          ls_output-ebeln = ls_acdoca-ebeln.
        ENDIF.
        IF gv_lifnr IS INITIAL AND ls_acdoca-lifnr IS NOT INITIAL.
          gv_lifnr = ls_acdoca-lifnr.
        ENDIF.
      ENDIF.

      " Try RBKP for vendor if not yet found
      IF gv_lifnr IS INITIAL.
        READ TABLE gt_rbkp INTO ls_rbkp
          WITH KEY bukrs = ls_anla-bukrs
                   gjahr = p_gjahr
                   belnr = ls_anep-belnr
          BINARY SEARCH.
        IF sy-subrc = 0.
          gv_lifnr = ls_rbkp-lifnr.
        ENDIF.
      ENDIF.

      " Exit after finding PO and vendor from first document
      IF ls_output-ebeln IS NOT INITIAL AND gv_lifnr IS NOT INITIAL.
        EXIT.
      ENDIF.

    ENDLOOP.

    " Apply PO selection filter
    IF s_ebeln IS NOT INITIAL.
      CHECK ls_output-ebeln IN s_ebeln.
    ENDIF.

    "--- Col 03: Vendor Name from LFA1 ---
    IF gv_lifnr IS NOT INITIAL.
      READ TABLE gt_lfa1 INTO ls_lfa1
        WITH KEY lifnr = gv_lifnr
        BINARY SEARCH.
      IF sy-subrc = 0.
        ls_output-name1 = ls_lfa1-name1.
      ENDIF.
    ENDIF.

    " Apply Vendor selection filter
    IF s_lifnr IS NOT INITIAL.
      CHECK gv_lifnr IN s_lifnr.
    ENDIF.

    APPEND ls_output TO gt_output.

  ENDLOOP.

  " Check output
  IF gt_output IS INITIAL.
    MESSAGE 'No data found for the selected criteria.' TYPE 'S'
            DISPLAY LIKE 'W'.
    STOP.
  ENDIF.


ENDFORM.
