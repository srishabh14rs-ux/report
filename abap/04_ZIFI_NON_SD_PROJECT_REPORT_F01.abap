*&---------------------------------------------------------------------*
*& Include          ZIFI_NON_SD_PROJECT_REPORT_F01
*&---------------------------------------------------------------------*
*& Class implementation
*&---------------------------------------------------------------------*

CLASS lcl_main IMPLEMENTATION.

*&---------------------------------------------------------------------*
*&  METHOD get_instance
*&  Singleton accessor
*&---------------------------------------------------------------------*
  METHOD get_instance.
    IF go_singleton IS INITIAL.
      go_singleton = NEW lcl_main( ).
    ENDIF.
    ro_instance = go_singleton.
  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD modify_screen
*&  Toggles PRCTR / AUFNR fields based on radio-button choice
*&---------------------------------------------------------------------*
  METHOD modify_screen.
    LOOP AT SCREEN INTO DATA(ls_screen).

      IF ls_screen-name CS gc_fld_prctr AND p_rdio = abap_true.
        ls_screen-input = 0.
        MODIFY SCREEN FROM ls_screen.
      ELSEIF ls_screen-name CS gc_fld_aufnr AND p_rdpc = abap_true.
        ls_screen-input = 0.
        MODIFY SCREEN FROM ls_screen.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD get_data
*&  Top-level data fetch: branches by radio button
*&---------------------------------------------------------------------*
  METHOD get_data.

    IF p_rdpc = abap_true.

      fetch_doc_keys( ).
      IF gt_doc_keys IS INITIAL.
        MESSAGE TEXT-i01 TYPE 'I'.
        LEAVE LIST-PROCESSING.
      ENDIF.
      fetch_bill_buckets( ).
      fetch_coll_buckets( ).

    ELSE.

      fetch_doc_keys_io( ).
      IF gt_doc_keys IS INITIAL.
        MESSAGE TEXT-i01 TYPE 'I'.
        LEAVE LIST-PROCESSING.
      ENDIF.
      fetch_bill_buckets_io( ).
      fetch_coll_buckets_io( ).

    ENDIF.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD fetch_doc_keys
*&  Step 1 (PC mode) - qualifying ACDOCA document keys
*&---------------------------------------------------------------------*
  METHOD fetch_doc_keys.

    SELECT rbukrs,
           belnr,
           gjahr,
           poper,
           kunnr,
           prctr,
           aufnr,
           blart
      FROM acdoca
      WHERE rbukrs IN @s_bukrs
        AND kunnr  IN @s_kunnr
        AND prctr  IN @s_prctr
        AND rldnr  =  @gc_leading_ledger
        AND (    blart = @gc_blart_invoice
              OR blart = @gc_blart_credit_memo
              OR blart = @gc_blart_billing_doc
              OR blart = @gc_blart_payment
              OR blart = @gc_blart_pay_offset )
        AND (   ( gjahr = @p_gjahr AND poper IN @s_perio )
             OR ( gjahr < @p_gjahr ) )
      INTO TABLE @gt_doc_keys.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD fetch_bill_buckets
*&  Step 2 (PC mode) - sum revenue + VAT lines on billing docs
*&---------------------------------------------------------------------*
  METHOD fetch_bill_buckets.

*-- Restrict doc keys to billing documents ---------------------------*
    DATA(lt_bill_docs) = gt_doc_keys.

    DELETE lt_bill_docs WHERE blart <> gc_blart_invoice
                          AND blart <> gc_blart_credit_memo
                          AND blart <> gc_blart_billing_doc.

    IF lt_bill_docs IS INITIAL.
      RETURN.
    ENDIF.

*-- Customer line (KUNNR + PRCTR filled) wins on dedup ---------------*
    SORT lt_bill_docs BY rbukrs belnr gjahr kunnr DESCENDING prctr DESCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_bill_docs COMPARING rbukrs belnr gjahr.

*-- Pull revenue + VAT lines (KUNNR blank lines) ---------------------*
    SELECT d~rbukrs,
           d~kunnr,
           d~prctr AS pc_or_io,
           a~gjahr,
           a~poper,
           a~ktosl,
           CASE WHEN a~ktosl = @gc_vat_ktosl
                THEN @gc_cat_bill_with_vat
                ELSE @gc_cat_bill_no_vat
           END AS category,
           SUM( a~hsl ) AS hsl
      FROM @lt_bill_docs AS d
           INNER JOIN acdoca AS a
                ON  a~rbukrs = d~rbukrs
                AND a~belnr  = d~belnr
                AND a~gjahr  = d~gjahr
      WHERE a~rldnr = @gc_leading_ledger
        AND a~kunnr = @space
        AND ( a~ktosl = @space OR a~ktosl = @gc_vat_ktosl )
      GROUP BY d~rbukrs, d~kunnr, d~prctr, a~gjahr, a~poper, a~ktosl
      HAVING SUM( a~hsl ) <> 0
      INTO TABLE @gt_bill.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD fetch_coll_buckets
*&  Step 3 (PC mode) - sum debit lines on collection documents
*&---------------------------------------------------------------------*
  METHOD fetch_coll_buckets.

*-- Restrict doc keys to collection documents ------------------------*
    DATA(lt_coll_docs) = gt_doc_keys.

    DELETE lt_coll_docs WHERE blart <> gc_blart_payment
                          AND blart <> gc_blart_pay_offset.

    IF lt_coll_docs IS INITIAL.
      RETURN.
    ENDIF.

*-- Customer line wins on dedup --------------------------------------*
    SORT lt_coll_docs BY rbukrs belnr gjahr kunnr DESCENDING prctr DESCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_coll_docs COMPARING rbukrs belnr gjahr.

*-- Pull debit lines (DRCRK = 'S') -----------------------------------*
    SELECT d~rbukrs,
           d~kunnr,
           d~prctr AS pc_or_io,
           a~gjahr,
           a~poper,
           @gc_cat_coll_with_vat AS category,
           SUM( a~hsl ) AS hsl
      FROM @lt_coll_docs AS d
           INNER JOIN acdoca AS a
                ON  a~rbukrs = d~rbukrs
                AND a~belnr  = d~belnr
                AND a~gjahr  = d~gjahr
      WHERE a~rldnr = @gc_leading_ledger
        AND a~drcrk = @gc_debit
      GROUP BY d~rbukrs, d~kunnr, d~prctr, a~gjahr, a~poper
      HAVING SUM( a~hsl ) <> 0
      INTO TABLE @gt_coll.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD fetch_doc_keys_io
*&  Step 1 (IO mode) - qualifying ACDOCA document keys
*&---------------------------------------------------------------------*
  METHOD fetch_doc_keys_io.

    SELECT rbukrs,
           belnr,
           gjahr,
           poper,
           kunnr,
           prctr,
           aufnr,
           blart
      FROM acdoca
      WHERE rbukrs IN @s_bukrs
        AND aufnr  IN @s_aufnr
        AND aufnr  <> @space
        AND rldnr  =  @gc_leading_ledger
        AND (    blart = @gc_blart_invoice
              OR blart = @gc_blart_credit_memo
              OR blart = @gc_blart_billing_doc
              OR blart = @gc_blart_payment
              OR blart = @gc_blart_pay_offset )
        AND (   ( gjahr = @p_gjahr AND poper IN @s_perio )
             OR ( gjahr < @p_gjahr ) )
      INTO TABLE @gt_doc_keys.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD fetch_bill_buckets_io
*&  Step 2 (IO mode) - sum revenue + VAT lines on billing docs
*&  Revenue identified by 3-series RACCT instead of KUNNR=blank
*&---------------------------------------------------------------------*
  METHOD fetch_bill_buckets_io.

*-- Restrict doc keys to billing documents ---------------------------*
    DATA(lt_bill_docs) = gt_doc_keys.

    DELETE lt_bill_docs WHERE blart <> gc_blart_invoice
                          AND blart <> gc_blart_credit_memo
                          AND blart <> gc_blart_billing_doc.

    IF lt_bill_docs IS INITIAL.
      RETURN.
    ENDIF.

*-- Dedup at document level ------------------------------------------*
    SORT lt_bill_docs BY rbukrs belnr gjahr aufnr DESCENDING kunnr DESCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_bill_docs COMPARING rbukrs belnr gjahr.

*-- Pull revenue + VAT lines (3-series GLs only) ---------------------*
    SELECT a~rbukrs,
           a~kunnr,
           a~aufnr AS pc_or_io,
           a~gjahr,
           a~poper,
           a~ktosl,
           CASE WHEN a~ktosl = @gc_vat_ktosl
                THEN @gc_cat_bill_with_vat
                ELSE @gc_cat_bill_no_vat
           END AS category,
           SUM( a~hsl ) AS hsl
      FROM @lt_bill_docs AS d
           INNER JOIN acdoca AS a
                ON  a~rbukrs = d~rbukrs
                AND a~belnr  = d~belnr
                AND a~gjahr  = d~gjahr
      WHERE a~rldnr =  @gc_leading_ledger
        AND a~aufnr IN @s_aufnr
        AND a~aufnr <> @space
        AND ( a~racct LIKE @gc_rev_gl_pattern )
      GROUP BY a~rbukrs, a~kunnr, a~aufnr, a~gjahr, a~poper, a~ktosl
      HAVING SUM( a~hsl ) <> 0
      INTO TABLE @gt_bill.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD fetch_coll_buckets_io
*&  Step 3 (IO mode) - clearing-chain collection lookup
*&  Payment -> AUGBL/AUGDT -> cleared invoice line -> sum by AUFNR
*&---------------------------------------------------------------------*
  METHOD fetch_coll_buckets_io.

*-- A) Find DZ/Z4 collection docs in the period ----------------------*
    SELECT DISTINCT rbukrs, belnr, budat, gjahr, poper
      FROM acdoca
      WHERE rbukrs IN @s_bukrs
        AND rldnr  =  @gc_leading_ledger
        AND ( blart = @gc_blart_payment OR blart = @gc_blart_pay_offset )
        AND (   ( gjahr = @p_gjahr AND poper IN @s_perio )
             OR ( gjahr < @p_gjahr ) )
      INTO TABLE @DATA(lt_pay_docs).

    IF lt_pay_docs IS INITIAL.
      RETURN.
    ENDIF.

*-- B + C) Join payments to cleared invoice lines, sum by AUFNR ------*
*   Match: payment's BELNR/BUDAT -> cleared invoice's AUGBL/AUGDT     *
*   Keep only the cleared lines (BELNR <> AUGBL)                      *
*   Filter by AUFNR-in-scope, DRCRK='S', RACCT <> excluded GL         *
*   Period (gjahr, poper) is taken from the PAYMENT, not the invoice  *
*---------------------------------------------------------------------*
    SELECT a~rbukrs,
           a~kunnr,
           a~aufnr AS pc_or_io,
           p~gjahr,
           p~poper,
           @gc_cat_coll_with_vat AS category,
           SUM( a~hsl ) AS hsl
      FROM @lt_pay_docs AS p
           INNER JOIN acdoca AS a
                ON  a~rbukrs = p~rbukrs
                AND a~augbl  = p~belnr
                AND a~augdt  = p~budat
      WHERE a~rldnr =  @gc_leading_ledger
        AND a~belnr <> a~augbl
        AND a~aufnr IN @s_aufnr
        AND a~aufnr <> @space
        AND a~drcrk =  @gc_debit
        AND a~racct <> @gc_excl_coll_racct
      GROUP BY a~rbukrs, a~kunnr, a~aufnr, p~gjahr, p~poper
      HAVING SUM( a~hsl ) <> 0
      INTO TABLE @gt_coll.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD process_data
*&  Top-level processing: pivot -> master-data enrichment
*&---------------------------------------------------------------------*
  METHOD process_data.

    build_output( ).
    enrich_with_master_data( ).

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD build_output
*&  Pivot bill + collection buckets into wide-format output table
*&  Mode-blind - operates on pc_or_io regardless of which value it holds
*&---------------------------------------------------------------------*
  METHOD build_output.

    FIELD-SYMBOLS: <fs_row> TYPE ty_output.

    DATA: lv_last_bukrs    TYPE acdoca-rbukrs,
          lv_last_kunnr    TYPE acdoca-kunnr,
          lv_last_pc_or_io TYPE acdoca-aufnr.

    CLEAR gt_output.

*======================================================================*
*  PASS 1 - billing rows
*======================================================================*
    SORT gt_bill BY rbukrs kunnr pc_or_io.

    LOOP AT gt_bill ASSIGNING FIELD-SYMBOL(<ls_bill>).

*-- get-or-create row, only re-read when key changes -----------------*
      IF    <ls_bill>-rbukrs   <> lv_last_bukrs
         OR <ls_bill>-kunnr    <> lv_last_kunnr
         OR <ls_bill>-pc_or_io <> lv_last_pc_or_io.

        READ TABLE gt_output ASSIGNING <fs_row>
             WITH KEY bukrs    = <ls_bill>-rbukrs
                      kunnr    = <ls_bill>-kunnr
                      pc_or_io = <ls_bill>-pc_or_io
             BINARY SEARCH.

        IF sy-subrc <> 0.
          INSERT VALUE #( bukrs    = <ls_bill>-rbukrs
                          kunnr    = <ls_bill>-kunnr
                          pc_or_io = <ls_bill>-pc_or_io )
                 INTO gt_output INDEX sy-tabix ASSIGNING <fs_row>.
        ENDIF.

        lv_last_bukrs    = <ls_bill>-rbukrs.
        lv_last_kunnr    = <ls_bill>-kunnr.
        lv_last_pc_or_io = <ls_bill>-pc_or_io.
      ENDIF.

*-- BLNV (revenue) -> bill_nv_XX AND bill_vt_XX                      *
*-- BLVT (VAT)     -> bill_vt_XX only                                *
      IF <ls_bill>-category = gc_cat_bill_no_vat.

        add_to_field(
          EXPORTING iv_gjahr  = <ls_bill>-gjahr
                    iv_poper  = <ls_bill>-poper
                    iv_prefix = gc_prefix_bill_nv
                    iv_hsl    = <ls_bill>-hsl
          CHANGING  cs_row    = <fs_row> ).

        add_to_field(
          EXPORTING iv_gjahr  = <ls_bill>-gjahr
                    iv_poper  = <ls_bill>-poper
                    iv_prefix = gc_prefix_bill_vt
                    iv_hsl    = <ls_bill>-hsl
          CHANGING  cs_row    = <fs_row> ).

      ELSEIF <ls_bill>-category = gc_cat_bill_with_vat.

        add_to_field(
          EXPORTING iv_gjahr  = <ls_bill>-gjahr
                    iv_poper  = <ls_bill>-poper
                    iv_prefix = gc_prefix_bill_vt
                    iv_hsl    = <ls_bill>-hsl
          CHANGING  cs_row    = <fs_row> ).

      ENDIF.

    ENDLOOP.

*======================================================================*
*  PASS 2 - collection rows
*======================================================================*
    SORT gt_coll BY rbukrs kunnr pc_or_io.

    CLEAR: lv_last_bukrs, lv_last_kunnr, lv_last_pc_or_io.

    LOOP AT gt_coll ASSIGNING FIELD-SYMBOL(<ls_coll>).

      IF    <ls_coll>-rbukrs   <> lv_last_bukrs
         OR <ls_coll>-kunnr    <> lv_last_kunnr
         OR <ls_coll>-pc_or_io <> lv_last_pc_or_io.

        READ TABLE gt_output ASSIGNING <fs_row>
             WITH KEY bukrs    = <ls_coll>-rbukrs
                      kunnr    = <ls_coll>-kunnr
                      pc_or_io = <ls_coll>-pc_or_io
             BINARY SEARCH.

        IF sy-subrc <> 0.
          INSERT VALUE #( bukrs    = <ls_coll>-rbukrs
                          kunnr    = <ls_coll>-kunnr
                          pc_or_io = <ls_coll>-pc_or_io )
                 INTO gt_output INDEX sy-tabix ASSIGNING <fs_row>.
        ENDIF.

        lv_last_bukrs    = <ls_coll>-rbukrs.
        lv_last_kunnr    = <ls_coll>-kunnr.
        lv_last_pc_or_io = <ls_coll>-pc_or_io.
      ENDIF.

      add_to_field(
        EXPORTING iv_gjahr  = <ls_coll>-gjahr
                  iv_poper  = <ls_coll>-poper
                  iv_prefix = gc_prefix_coll_vt
                  iv_hsl    = <ls_coll>-hsl
        CHANGING  cs_row    = <fs_row> ).

    ENDLOOP.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD add_to_field
*&  Resolves target column from (gjahr, poper, prefix) and accumulates
*&  the amount.  Also updates _YR for current-year amounts.
*&---------------------------------------------------------------------*
  METHOD add_to_field.

    DATA: lv_field     TYPE fieldname,
          lv_yearly    TYPE fieldname,
          lv_period_n2 TYPE n LENGTH 2.

    FIELD-SYMBOLS: <fs_amount> TYPE acdoca-hsl,
                   <fs_yearly> TYPE acdoca-hsl.

*-- monthly bucket: opening for prior years, _POPER for current year --*
    IF iv_gjahr < p_gjahr.
      lv_field = |{ iv_prefix }{ gc_suffix_opening }|.
    ELSE.
      lv_period_n2 = iv_poper.
      lv_field     = |{ iv_prefix }{ lv_period_n2 }|.
    ENDIF.

    ASSIGN COMPONENT lv_field OF STRUCTURE cs_row TO <fs_amount>.
    IF <fs_amount> IS ASSIGNED.
      <fs_amount> = <fs_amount> + iv_hsl.
    ENDIF.

*-- current-year amounts also feed the yearly total ------------------*
    IF iv_gjahr = p_gjahr.
      lv_yearly = |{ iv_prefix }{ gc_suffix_yearly }|.
      ASSIGN COMPONENT lv_yearly OF STRUCTURE cs_row TO <fs_yearly>.
      IF <fs_yearly> IS ASSIGNED.
        <fs_yearly> = <fs_yearly> + iv_hsl.
      ENDIF.
    ENDIF.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD enrich_with_master_data
*&  Joins T001 + KNA1/ADRC/T005T + CEPCT + KNB1/T052 + lookup map
*&  Mode-aware: resolves PRCTR/KUNNR/AUFNR per row based on radio button
*&---------------------------------------------------------------------*
  METHOD enrich_with_master_data.

    IF gt_output IS INITIAL.
      RETURN.
    ENDIF.

*======================================================================*
*  Build doc-key lookup keyed at gt_output's grain
*  PC mode: key = (bukrs, kunnr, pc_or_io=prctr), value = aufnr (first non-blank)
*  IO mode: key = (bukrs, kunnr, pc_or_io=aufnr), value = prctr (first non-blank)
*======================================================================*
    TYPES: BEGIN OF ty_lookup,
             bukrs    TYPE acdoca-rbukrs,
             pc_or_io TYPE acdoca-aufnr,
             kunnr    TYPE acdoca-kunnr,
             prctr    TYPE acdoca-prctr,
             aufnr    TYPE acdoca-aufnr,
           END OF ty_lookup,
           tt_lookup TYPE STANDARD TABLE OF ty_lookup
                      WITH NON-UNIQUE SORTED KEY bk_p
                      COMPONENTS bukrs pc_or_io.

    DATA: lt_lookup TYPE tt_lookup.

    DATA(lt_doc_keys_sorted) = gt_doc_keys.

    IF p_rdpc = abap_true.
*--- PC mode: sort so non-blank AUFNR wins per (bukrs, kunnr, prctr)
      SORT lt_doc_keys_sorted BY rbukrs kunnr prctr aufnr DESCENDING.
    ELSE.
*--- IO mode: sort so non-blank PRCTR/KUNNR win per (bukrs, aufnr)
      SORT lt_doc_keys_sorted BY rbukrs aufnr prctr DESCENDING kunnr DESCENDING.
    ENDIF.

    LOOP AT lt_doc_keys_sorted ASSIGNING FIELD-SYMBOL(<ls_dk>).
      IF p_rdpc = abap_true.
        APPEND VALUE #( bukrs    = <ls_dk>-rbukrs
                        pc_or_io = <ls_dk>-prctr
                        kunnr    = <ls_dk>-kunnr
                        prctr    = <ls_dk>-prctr
                        aufnr    = <ls_dk>-aufnr )
               TO lt_lookup.
      ELSE.
        APPEND VALUE #( bukrs    = <ls_dk>-rbukrs
                        pc_or_io = <ls_dk>-aufnr
                        kunnr    = <ls_dk>-kunnr
                        prctr    = <ls_dk>-prctr
                        aufnr    = <ls_dk>-aufnr )
               TO lt_lookup.
      ENDIF.
    ENDLOOP.

*======================================================================*
*  Driver tables for master-data SELECTs
*======================================================================*
    DATA: lt_bk_keys TYPE tt_bk,
          lt_bukrs   TYPE tt_bukrs,
          lt_prctr   TYPE tt_prctr.

    LOOP AT lt_lookup ASSIGNING FIELD-SYMBOL(<ls_lk>).
      IF <ls_lk>-kunnr IS NOT INITIAL.
        INSERT VALUE #( bukrs = <ls_lk>-bukrs kunnr = <ls_lk>-kunnr )
               INTO TABLE lt_bk_keys.
      ENDIF.
      INSERT VALUE #( bukrs = <ls_lk>-bukrs ) INTO TABLE lt_bukrs.
      IF <ls_lk>-prctr IS NOT INITIAL.
        INSERT VALUE #( prctr = <ls_lk>-prctr ) INTO TABLE lt_prctr.
      ENDIF.
    ENDLOOP.

*======================================================================*
*  SELECT 1 - Entity (T001)
*======================================================================*
    DATA: lt_t001 TYPE STANDARD TABLE OF ty_t001_lookup.
    IF lt_bukrs IS NOT INITIAL.
      SELECT t~bukrs, t~butxt
        FROM @lt_bukrs AS d
             INNER JOIN t001 AS t ON t~bukrs = d~bukrs
        INTO CORRESPONDING FIELDS OF TABLE @lt_t001.
    ENDIF.

*======================================================================*
*  SELECT 2 - Customer + Address + Country (KNA1 + ADRC + T005T)
*======================================================================*
    DATA: lt_cust TYPE STANDARD TABLE OF ty_cust_lookup.
    IF lt_bk_keys IS NOT INITIAL.
      SELECT k~kunnr,
             k~name1,
             k~ktokd,
             a~city1,
             t~landx50
        FROM @lt_bk_keys AS d
             INNER JOIN kna1  AS k ON k~kunnr = d~kunnr
             LEFT OUTER JOIN adrc  AS a ON  a~addrnumber = k~adrnr
                                        AND a~nation     = @space
             LEFT OUTER JOIN t005t AS t ON  t~spras = @sy-langu
                                        AND t~land1 = a~country
        INTO CORRESPONDING FIELDS OF TABLE @lt_cust.
    ENDIF.

*======================================================================*
*  SELECT 3 - Profit-Centre text (CEPCT)
*======================================================================*
    DATA: lt_cepct TYPE STANDARD TABLE OF ty_cepct_lookup.
    IF lt_prctr IS NOT INITIAL.
      SELECT c~prctr, c~ltext
        FROM @lt_prctr AS d
             INNER JOIN cepct AS c ON  c~prctr = d~prctr
                                  AND c~spras = @sy-langu
                                  AND c~datbi >= @sy-datum
        INTO CORRESPONDING FIELDS OF TABLE @lt_cepct.
    ENDIF.

*======================================================================*
*  SELECT 4 - Payment terms chain (KNB1 + T052)
*======================================================================*
    DATA: lt_pmt TYPE STANDARD TABLE OF ty_pmt_lookup.
    IF lt_bk_keys IS NOT INITIAL.
      SELECT k~bukrs, k~kunnr, t~ztag1
        FROM @lt_bk_keys AS d
             INNER JOIN knb1 AS k ON  k~bukrs = d~bukrs
                                  AND k~kunnr = d~kunnr
             LEFT OUTER JOIN t052 AS t ON t~zterm = k~zterm
        INTO CORRESPONDING FIELDS OF TABLE @lt_pmt.
    ENDIF.

*======================================================================*
*  Merge - one pass over gt_output, build gt_final
*======================================================================*
    CLEAR gt_final.

    LOOP AT gt_output ASSIGNING FIELD-SYMBOL(<ls_out>).
      DATA(ls_final) = VALUE ty_final( ).

*-- amount fields ----------------------------------------------------*
      MOVE-CORRESPONDING <ls_out> TO ls_final.

*-- Resolve effective KUNNR / PRCTR / AUFNR from lookup --------------*
      DATA: lv_eff_kunnr TYPE acdoca-kunnr,
            lv_eff_prctr TYPE acdoca-prctr,
            lv_eff_aufnr TYPE acdoca-aufnr.

      CLEAR: lv_eff_kunnr, lv_eff_prctr, lv_eff_aufnr.

      LOOP AT lt_lookup ASSIGNING <ls_lk>
           USING KEY bk_p
           WHERE bukrs    = <ls_out>-bukrs
             AND pc_or_io = <ls_out>-pc_or_io.

        IF p_rdpc = abap_true.
*--- PC mode: row driven by (kunnr, prctr); pull aufnr from lookup ---*
          IF <ls_lk>-kunnr = <ls_out>-kunnr.
            lv_eff_kunnr = <ls_out>-kunnr.
            lv_eff_prctr = <ls_out>-pc_or_io.
            lv_eff_aufnr = <ls_lk>-aufnr.
            EXIT.
          ENDIF.
        ELSE.
*--- IO mode: row driven by aufnr; pull kunnr + prctr from lookup ----*
          lv_eff_aufnr = <ls_out>-pc_or_io.
          IF lv_eff_kunnr IS INITIAL AND <ls_lk>-kunnr IS NOT INITIAL.
            lv_eff_kunnr = <ls_lk>-kunnr.
          ENDIF.
          IF lv_eff_prctr IS INITIAL AND <ls_lk>-prctr IS NOT INITIAL.
            lv_eff_prctr = <ls_lk>-prctr.
          ENDIF.
          IF lv_eff_kunnr IS NOT INITIAL AND lv_eff_prctr IS NOT INITIAL.
            EXIT.
          ENDIF.
        ENDIF.
      ENDLOOP.

      ls_final-prctr = lv_eff_prctr.
      ls_final-aufnr = lv_eff_aufnr.

*-- DoF flag (PRCTR starts with N -> Non-DoF) -----------------------*
      IF lv_eff_prctr IS NOT INITIAL.
        ls_final-dof_flag = COND #(
          WHEN lv_eff_prctr(1) = gc_non_dof_prefix THEN TEXT-t01
          ELSE                                          TEXT-t02 ).
      ENDIF.

*-- Entity (T001 lookup) --------------------------------------------*
      READ TABLE lt_t001 INTO DATA(ls_t001)
           WITH KEY bukrs = <ls_out>-bukrs.
      IF sy-subrc = 0.
        ls_final-entity = ls_t001-butxt.
      ENDIF.

*-- Customer chain ---------------------------------------------------*
      IF lv_eff_kunnr IS NOT INITIAL.
        READ TABLE lt_cust INTO DATA(ls_cust)
             WITH KEY kunnr = lv_eff_kunnr.
        IF sy-subrc = 0.
          ls_final-cust_name = ls_cust-name1.
          ls_final-city      = ls_cust-city1.
          ls_final-country   = ls_cust-landx50.
          ls_final-rel_party = COND #(
            WHEN ls_cust-ktokd = gc_related_party THEN TEXT-t03
            ELSE                                       TEXT-t04 ).
        ENDIF.
      ENDIF.

*-- Profit Centre text -----------------------------------------------*
      IF lv_eff_prctr IS NOT INITIAL.
        READ TABLE lt_cepct INTO DATA(ls_cepct)
             WITH KEY prctr = lv_eff_prctr.
        IF sy-subrc = 0.
          ls_final-research_ctr = ls_cepct-ltext.
        ENDIF.
      ENDIF.

*-- Payment Terms ----------------------------------------------------*
      IF lv_eff_kunnr IS NOT INITIAL.
        READ TABLE lt_pmt INTO DATA(ls_pmt)
             WITH KEY bukrs = <ls_out>-bukrs kunnr = lv_eff_kunnr.
        IF sy-subrc = 0.
          ls_final-pmt_terms = ls_pmt-ztag1.
        ENDIF.
      ENDIF.

      APPEND ls_final TO gt_final.

    ENDLOOP.

*-- final sort for stable ALV display --------------------------------*
    SORT gt_final BY entity cust_name prctr aufnr.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD display_report
*&  CL_SALV_TABLE with dynamic year-based column captions
*&---------------------------------------------------------------------*
  METHOD display_report.

    IF gt_final IS INITIAL.
      MESSAGE TEXT-i02 TYPE 'I'.
      LEAVE LIST-PROCESSING.
    ENDIF.

    DATA: lo_alv TYPE REF TO cl_salv_table.

*-- Instantiate ALV --------------------------------------------------*
    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = lo_alv
          CHANGING  t_table      = gt_final ).

      CATCH cx_salv_msg INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'E'.
        RETURN.
    ENDTRY.

*-- Standard toolbar (export, print, sort, filter, totals) -----------*
    DATA(lo_funcs) = lo_alv->get_functions( ).
    lo_funcs->set_all( abap_true ).

*-- Striped rows + list header ---------------------------------------*
    DATA(lo_disp) = lo_alv->get_display_settings( ).
    lo_disp->set_striped_pattern( abap_true ).
    lo_disp->set_list_header( |{ TEXT-h01 } - { p_gjahr }| ).

*-- Layout (save/load variants) --------------------------------------*
    DATA(lo_layout) = lo_alv->get_layout( ).
    lo_layout->set_key( VALUE #( report = sy-repid ) ).
    lo_layout->set_default( abap_true ).
    lo_layout->set_save_restriction( cl_salv_layout=>restrict_none ).

*-- Configure columns ------------------------------------------------*
    DATA(lo_cols) = lo_alv->get_columns( ).
    lo_cols->set_optimize( abap_true ).

    set_column_captions( io_cols = lo_cols ).
    set_aggregations( io_alv = lo_alv ).

*-- Display ----------------------------------------------------------*
    lo_alv->display( ).

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD set_column_captions
*&  Sets static + dynamic (year-based) column headers
*&---------------------------------------------------------------------*
  METHOD set_column_captions.

    DATA: lv_yy_curr TYPE n LENGTH 2,
          lv_yy_prev TYPE n LENGTH 2,
          lv_text    TYPE string.

    lv_yy_curr = p_gjahr+2(2).
    lv_yy_prev = ( p_gjahr - 1 ) MOD 100.

*-- Static columns ---------------------------------------------------*
    set_col( io_cols = io_cols iv_field = 'ENTITY'       iv_text = TEXT-c01 ).
    set_col( io_cols = io_cols iv_field = 'CUST_NAME'    iv_text = TEXT-c02 ).
    set_col( io_cols = io_cols iv_field = 'CITY'         iv_text = TEXT-c03 ).
    set_col( io_cols = io_cols iv_field = 'COUNTRY'      iv_text = TEXT-c04 ).
    set_col( io_cols = io_cols iv_field = 'RESEARCH_CTR' iv_text = TEXT-c05 ).
    set_col( io_cols = io_cols iv_field = 'DOF_FLAG'     iv_text = TEXT-c06 ).
    set_col( io_cols = io_cols iv_field = 'PRCTR'        iv_text = TEXT-c07 ).
    set_col( io_cols = io_cols iv_field = 'AUFNR'        iv_text = TEXT-c08 ).
    set_col( io_cols = io_cols iv_field = 'REV_GL'       iv_text = TEXT-c09 ).
    set_col( io_cols = io_cols iv_field = 'REL_PARTY'    iv_text = TEXT-c10 ).
    set_col( io_cols = io_cols iv_field = 'PMT_TERMS'    iv_text = TEXT-c11 ).

*-- Bill NV ----------------------------------------------------------*
    lv_text = |{ TEXT-c16 } { TEXT-c12 }{ lv_yy_prev } { TEXT-c14 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_NV_OP' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m01 }-{ lv_yy_curr } { TEXT-c14 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_NV_01' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m02 }-{ lv_yy_curr } { TEXT-c14 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_NV_02' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m03 }-{ lv_yy_curr } { TEXT-c14 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_NV_03' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m04 }-{ lv_yy_curr } { TEXT-c14 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_NV_04' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m05 }-{ lv_yy_curr } { TEXT-c14 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_NV_05' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m06 }-{ lv_yy_curr } { TEXT-c14 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_NV_06' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m07 }-{ lv_yy_curr } { TEXT-c14 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_NV_07' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m08 }-{ lv_yy_curr } { TEXT-c14 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_NV_08' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m09 }-{ lv_yy_curr } { TEXT-c14 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_NV_09' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m10 }-{ lv_yy_curr } { TEXT-c14 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_NV_10' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m11 }-{ lv_yy_curr } { TEXT-c14 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_NV_11' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m12 }-{ lv_yy_curr } { TEXT-c14 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_NV_12' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { p_gjahr } { TEXT-c14 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_NV_YR' iv_text = lv_text ).

*-- Bill VT ----------------------------------------------------------*
    lv_text = |{ TEXT-c16 } { TEXT-c12 }{ lv_yy_prev } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_VT_OP' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m01 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_VT_01' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m02 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_VT_02' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m03 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_VT_03' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m04 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_VT_04' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m05 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_VT_05' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m06 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_VT_06' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m07 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_VT_07' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m08 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_VT_08' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m09 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_VT_09' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m10 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_VT_10' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m11 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_VT_11' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { TEXT-m12 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_VT_12' iv_text = lv_text ).

    lv_text = |{ TEXT-c16 } { p_gjahr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'BILL_VT_YR' iv_text = lv_text ).

*-- Collect VT -------------------------------------------------------*
    lv_text = |{ TEXT-c17 } { TEXT-c12 }{ lv_yy_prev } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'COLL_VT_OP' iv_text = lv_text ).

    lv_text = |{ TEXT-c17 } { TEXT-m01 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'COLL_VT_01' iv_text = lv_text ).

    lv_text = |{ TEXT-c17 } { TEXT-m02 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'COLL_VT_02' iv_text = lv_text ).

    lv_text = |{ TEXT-c17 } { TEXT-m03 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'COLL_VT_03' iv_text = lv_text ).

    lv_text = |{ TEXT-c17 } { TEXT-m04 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'COLL_VT_04' iv_text = lv_text ).

    lv_text = |{ TEXT-c17 } { TEXT-m05 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'COLL_VT_05' iv_text = lv_text ).

    lv_text = |{ TEXT-c17 } { TEXT-m06 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'COLL_VT_06' iv_text = lv_text ).

    lv_text = |{ TEXT-c17 } { TEXT-m07 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'COLL_VT_07' iv_text = lv_text ).

    lv_text = |{ TEXT-c17 } { TEXT-m08 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'COLL_VT_08' iv_text = lv_text ).

    lv_text = |{ TEXT-c17 } { TEXT-m09 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'COLL_VT_09' iv_text = lv_text ).

    lv_text = |{ TEXT-c17 } { TEXT-m10 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'COLL_VT_10' iv_text = lv_text ).

    lv_text = |{ TEXT-c17 } { TEXT-m11 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'COLL_VT_11' iv_text = lv_text ).

    lv_text = |{ TEXT-c17 } { TEXT-m12 }-{ lv_yy_curr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'COLL_VT_12' iv_text = lv_text ).

    lv_text = |{ TEXT-c17 } { p_gjahr } { TEXT-c15 }|.
    set_col( io_cols = io_cols iv_field = 'COLL_VT_YR' iv_text = lv_text ).

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD set_col
*&  Helper - sets long/medium/short text on one column
*&---------------------------------------------------------------------*
  METHOD set_col.
    TRY.
        DATA(lo_col) = io_cols->get_column( CONV lvc_fname( iv_field ) ).
        lo_col->set_long_text(   CONV scrtext_l( iv_text ) ).
        lo_col->set_medium_text( CONV scrtext_m( iv_text ) ).
        lo_col->set_short_text(  CONV scrtext_s( iv_text ) ).
      CATCH cx_salv_not_found.
*       column doesn't exist - ignore silently
    ENDTRY.
  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD set_aggregations
*&  Enable totals on all amount columns
*&---------------------------------------------------------------------*
  METHOD set_aggregations.

    DATA(lo_aggs) = io_alv->get_aggregations( ).

    DATA(lt_amount_cols) = VALUE STANDARD TABLE OF lvc_fname(
      ( 'BILL_NV_OP' ) ( 'BILL_NV_01' ) ( 'BILL_NV_02' ) ( 'BILL_NV_03' )
      ( 'BILL_NV_04' ) ( 'BILL_NV_05' ) ( 'BILL_NV_06' ) ( 'BILL_NV_07' )
      ( 'BILL_NV_08' ) ( 'BILL_NV_09' ) ( 'BILL_NV_10' ) ( 'BILL_NV_11' )
      ( 'BILL_NV_12' ) ( 'BILL_NV_YR' )

      ( 'BILL_VT_OP' ) ( 'BILL_VT_01' ) ( 'BILL_VT_02' ) ( 'BILL_VT_03' )
      ( 'BILL_VT_04' ) ( 'BILL_VT_05' ) ( 'BILL_VT_06' ) ( 'BILL_VT_07' )
      ( 'BILL_VT_08' ) ( 'BILL_VT_09' ) ( 'BILL_VT_10' ) ( 'BILL_VT_11' )
      ( 'BILL_VT_12' ) ( 'BILL_VT_YR' )

      ( 'COLL_VT_OP' ) ( 'COLL_VT_01' ) ( 'COLL_VT_02' ) ( 'COLL_VT_03' )
      ( 'COLL_VT_04' ) ( 'COLL_VT_05' ) ( 'COLL_VT_06' ) ( 'COLL_VT_07' )
      ( 'COLL_VT_08' ) ( 'COLL_VT_09' ) ( 'COLL_VT_10' ) ( 'COLL_VT_11' )
      ( 'COLL_VT_12' ) ( 'COLL_VT_YR' ) ).

    LOOP AT lt_amount_cols INTO DATA(lv_col).
      TRY.
          lo_aggs->add_aggregation( lv_col ).
        CATCH cx_salv_data_error cx_salv_not_found cx_salv_existing.
*         silent
      ENDTRY.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
