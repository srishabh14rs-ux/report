*&---------------------------------------------------------------------*
*& Include          ZIFI_NON_SD_PROJECT_REPORT_F01
*&---------------------------------------------------------------------*
*& Class implementation
*&---------------------------------------------------------------------*

CLASS lcl_main IMPLEMENTATION.

*&---------------------------------------------------------------------*
*&  METHOD m_get_instance
*&  Singleton accessor
*&---------------------------------------------------------------------*
  METHOD m_get_instance.
    IF go_singleton IS INITIAL.
      go_singleton = NEW lcl_main( ).
    ENDIF.
    ro_instance = go_singleton.
  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD m_validate_bukrs
*&  Restrict s_bukrs to allowed company codes per radio mode.
*&  Allowed values are maintained in TVARVC (transaction STVARV).
*&---------------------------------------------------------------------*
  METHOD m_validate_bukrs.

    DATA: lv_name TYPE rvari_vnam.

*-- pick the right TVARVC entry based on radio button -----------------*
    IF p_rdpc = abap_true.
      lv_name = gc_tvarv_pc_bukrs.
    ELSE.
      lv_name = gc_tvarv_io_bukrs.
    ENDIF.

*-- read allowed company codes from TVARVC ---------------------------*
    SELECT low
      FROM tvarvc
      WHERE name = @lv_name
        AND type = 'S'
        AND sign = 'I'
        AND opti = 'EQ'
      INTO TABLE @DATA(lt_allowed).

    IF lt_allowed IS INITIAL.
      MESSAGE TEXT-e03 TYPE 'E'.
    ENDIF.

*-- validate every entry in s_bukrs ----------------------------------*
    LOOP AT s_bukrs ASSIGNING FIELD-SYMBOL(<ls_bukrs>).

*-- check low side ---------------------------------------------------*
      READ TABLE lt_allowed
           WITH KEY low = <ls_bukrs>-low
           TRANSPORTING NO FIELDS.

      IF sy-subrc <> 0.
        IF p_rdpc = abap_true.
          MESSAGE TEXT-e01 TYPE 'E'.
          LEAVE LIST-PROCESSING.
        ELSE.
          MESSAGE TEXT-e02 TYPE 'E'.
          LEAVE LIST-PROCESSING.
        ENDIF.
      ENDIF.

*-- check high side if a range was entered ---------------------------*
      IF <ls_bukrs>-high IS NOT INITIAL.
        READ TABLE lt_allowed
             WITH KEY low = <ls_bukrs>-high
             TRANSPORTING NO FIELDS.

        IF sy-subrc <> 0.
          IF p_rdpc = abap_true.
            MESSAGE TEXT-e01 TYPE 'E'.
          LEAVE LIST-PROCESSING.
          ELSE.
            MESSAGE TEXT-e02 TYPE 'E'.
          LEAVE LIST-PROCESSING.
          ENDIF.
        ENDIF.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD m_modify_screen
*&  Toggles PRCTR / AUFNR fields based on radio-button choice
*&---------------------------------------------------------------------*
  METHOD m_modify_screen.
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
*&  METHOD m_get_data
*&  Top-level data fetch: branches by radio button
*&---------------------------------------------------------------------*
  METHOD m_get_data.

    IF p_rdpc = abap_true.

      m_fetch_doc_keys( ).
      IF gt_doc_keys IS INITIAL.
        MESSAGE TEXT-i01 TYPE 'I'.
        LEAVE LIST-PROCESSING.
      ENDIF.
      m_fetch_bill_buckets( ).
      m_fetch_coll_buckets( ).

    ELSE.

      m_fetch_doc_keys_io( ).
      IF gt_doc_keys IS INITIAL.
        MESSAGE TEXT-i01 TYPE 'I'.
        LEAVE LIST-PROCESSING.
      ENDIF.
      m_fetch_bill_buckets_io( ).
      m_fetch_coll_buckets_io( ).

    ENDIF.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD m_fetch_doc_keys
*&  Step 1 (PC mode) - qualifying ACDOCA document keys
*&---------------------------------------------------------------------*
  METHOD m_fetch_doc_keys.

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
*&  METHOD m_fetch_bill_buckets
*&  Step 2 (PC mode) - sum revenue + VAT lines on billing docs
*&
*&  Change: KUNNR patch added after dedup.
*&  When s_prctr filters to specific profit centres the AR line
*&  (prctr = space) is excluded from gt_doc_keys, so the dedup winner
*&  is a revenue line with kunnr = space.  A supplementary SELECT
*&  finds the actual customer from ACDOCA and patches it in place
*&  before the main aggregation query runs.
*&---------------------------------------------------------------------*
  METHOD m_fetch_bill_buckets.

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

*-- Patch missing KUNNR: look up customer directly from ACDOCA -------*
    SELECT a~rbukrs, a~belnr, a~gjahr, MAX( a~kunnr ) AS kunnr
      FROM @lt_bill_docs AS d
           INNER JOIN acdoca AS a
                ON  a~rbukrs = d~rbukrs
                AND a~belnr  = d~belnr
                AND a~gjahr  = d~gjahr
      WHERE a~rldnr = @gc_leading_ledger
        AND a~kunnr <> @space
      GROUP BY a~rbukrs, a~belnr, a~gjahr
      INTO TABLE @DATA(lt_doc_kunnr).

    LOOP AT lt_bill_docs ASSIGNING FIELD-SYMBOL(<ls_bd>) WHERE kunnr IS INITIAL.
      READ TABLE lt_doc_kunnr ASSIGNING FIELD-SYMBOL(<ls_dkn>)
           WITH KEY rbukrs = <ls_bd>-rbukrs
                    belnr  = <ls_bd>-belnr
                    gjahr  = <ls_bd>-gjahr.
      IF sy-subrc = 0.
        <ls_bd>-kunnr = <ls_dkn>-kunnr.
      ENDIF.
    ENDLOOP.

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
*&  METHOD m_fetch_coll_buckets
*&  Step 3 (PC mode) - sum debit lines on collection documents
*&
*&  Change: same KUNNR patch as m_fetch_bill_buckets applied here so
*&  collection rows carry the correct customer number and merge into
*&  the same (bukrs, kunnr, prctr) output row as billing rows.
*&---------------------------------------------------------------------*
  METHOD m_fetch_coll_buckets.

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

*-- Patch missing KUNNR: look up customer directly from ACDOCA -------*
    SELECT a~rbukrs, a~belnr, a~gjahr, MAX( a~kunnr ) AS kunnr
      FROM @lt_coll_docs AS d
           INNER JOIN acdoca AS a
                ON  a~rbukrs = d~rbukrs
                AND a~belnr  = d~belnr
                AND a~gjahr  = d~gjahr
      WHERE a~rldnr = @gc_leading_ledger
        AND a~kunnr <> @space
      GROUP BY a~rbukrs, a~belnr, a~gjahr
      INTO TABLE @DATA(lt_doc_kunnr).

    LOOP AT lt_coll_docs ASSIGNING FIELD-SYMBOL(<ls_cd>) WHERE kunnr IS INITIAL.
      READ TABLE lt_doc_kunnr ASSIGNING FIELD-SYMBOL(<ls_dkn>)
           WITH KEY rbukrs = <ls_cd>-rbukrs
                    belnr  = <ls_cd>-belnr
                    gjahr  = <ls_cd>-gjahr.
      IF sy-subrc = 0.
        <ls_cd>-kunnr = <ls_dkn>-kunnr.
      ENDIF.
    ENDLOOP.

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
*&  METHOD m_fetch_doc_keys_io
*&  Step 1 (IO mode) - qualifying ACDOCA document keys
*&---------------------------------------------------------------------*
  METHOD m_fetch_doc_keys_io.

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
*&  METHOD m_fetch_bill_buckets_io
*&  Step 2 (IO mode) - sum revenue + VAT lines on billing docs
*&
*&  Change: replaced two separate SELECTs with one merged query.
*&  Revenue lines  : ktosl <> MWS, aufnr <> space, 3-series RACCT
*&                   -> category = BLNV, pc_or_io = aufnr, belnr filled
*&  VAT (MWS) lines: ktosl = MWS, aufnr may be space
*&                   -> category = BLVT, pc_or_io = space, belnr filled
*&  belnr is included in GROUP BY so m_build_output can resolve the
*&  correct AUFNR for MWS lines via gt_doc_keys.
*&  Dead code (gt_bill1 SELECT) removed.
*&---------------------------------------------------------------------*
  METHOD m_fetch_bill_buckets_io.

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

*-- Single query: revenue lines + MWS lines --------------------------*
*  Revenue : aufnr IN s_aufnr AND aufnr <> space AND racct LIKE '003%'*
*  MWS/VAT : ktosl = gc_vat_ktosl (aufnr may be space)               *
*  belnr kept in GROUP BY so MWS rows can be mapped to aufnr later   *
    SELECT a~rbukrs,
           CAST( @space AS CHAR( 10 ) ) AS kunnr,
           a~aufnr AS pc_or_io,
           a~gjahr,
           a~poper,
           a~ktosl,
           CASE WHEN a~ktosl = @gc_vat_ktosl
                THEN @gc_cat_bill_with_vat
                ELSE @gc_cat_bill_no_vat
           END AS category,
           SUM( a~hsl ) AS hsl,
           a~belnr
      FROM @lt_bill_docs AS d
           INNER JOIN acdoca AS a
                ON  a~rbukrs = d~rbukrs
                AND a~belnr  = d~belnr
                AND a~gjahr  = d~gjahr
      WHERE a~rldnr =  @gc_leading_ledger
        AND a~aufnr IN @s_aufnr
        AND (    ( a~ktosl =  @gc_vat_ktosl )
              OR ( a~ktosl <> @gc_vat_ktosl AND a~aufnr <> @space AND a~racct LIKE @gc_rev_gl_pattern ) )
      GROUP BY a~rbukrs, a~aufnr, a~gjahr, a~poper, a~ktosl, a~belnr
      HAVING SUM( a~hsl ) <> 0
      INTO TABLE @gt_bill.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD m_fetch_coll_buckets_io
*&  Step 3 (IO mode) - clearing-chain collection lookup
*&  Payment -> AUGBL/AUGDT -> cleared invoice line -> sum by AUFNR
*&---------------------------------------------------------------------*
  METHOD m_fetch_coll_buckets_io.

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
           CAST( @space AS CHAR( 10 ) ) AS kunnr,
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
      GROUP BY a~rbukrs, a~aufnr, p~gjahr, p~poper
      HAVING SUM( a~hsl ) <> 0
      INTO TABLE @gt_coll.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD m_process_data
*&  Top-level processing: pivot -> master-data enrichment
*&---------------------------------------------------------------------*
  METHOD m_process_data.

    m_build_output( ).
    m_enrich_with_master_data( ).

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD m_build_output
*&  Pivot bill + collection buckets into wide-format output table
*&  Mode-blind - operates on pc_or_io regardless of which value it holds
*&
*&  Change: for IO-mode MWS lines (pc_or_io=space, belnr filled) the
*&  AUFNR is resolved via a belnr->aufnr map built from gt_doc_keys.
*&---------------------------------------------------------------------*
  METHOD m_build_output.

    FIELD-SYMBOLS: <fs_row> TYPE ty_output.

    DATA: lv_last_bukrs    TYPE acdoca-rbukrs,
          lv_last_kunnr    TYPE acdoca-kunnr,
          lv_last_pc_or_io TYPE acdoca-aufnr,
          lv_eff_pc_or_io  TYPE acdoca-aufnr.

    CLEAR gt_output.

*-- belnr -> aufnr lookup for IO-mode MWS resolution -----------------*
    DATA(lt_belnr_map) = gt_doc_keys.
    SORT lt_belnr_map BY rbukrs belnr gjahr aufnr DESCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_belnr_map COMPARING rbukrs belnr gjahr.

*======================================================================*
*  PASS 1 - billing rows
*======================================================================*
    SORT gt_bill BY rbukrs kunnr pc_or_io.

    LOOP AT gt_bill ASSIGNING FIELD-SYMBOL(<ls_bill>).

*-- Resolve effective pc_or_io (handles MWS lines with aufnr=space) --*
      IF <ls_bill>-pc_or_io IS NOT INITIAL.
        lv_eff_pc_or_io = <ls_bill>-pc_or_io.
      ELSEIF <ls_bill>-belnr IS NOT INITIAL.
        READ TABLE lt_belnr_map ASSIGNING FIELD-SYMBOL(<ls_bm>)
             WITH KEY rbukrs = <ls_bill>-rbukrs
                      belnr  = <ls_bill>-belnr
                      gjahr  = <ls_bill>-gjahr
             BINARY SEARCH.
        IF sy-subrc = 0 AND <ls_bm>-aufnr IS NOT INITIAL.
          lv_eff_pc_or_io = <ls_bm>-aufnr.
        ELSE.
          CONTINUE.
        ENDIF.
      ELSE.
        CONTINUE.
      ENDIF.

*-- get-or-create row, only re-read when key changes -----------------*
      IF    <ls_bill>-rbukrs <> lv_last_bukrs
         OR <ls_bill>-kunnr  <> lv_last_kunnr
         OR lv_eff_pc_or_io  <> lv_last_pc_or_io.

        READ TABLE gt_output ASSIGNING <fs_row>
             WITH KEY bukrs    = <ls_bill>-rbukrs
                      kunnr    = <ls_bill>-kunnr
                      pc_or_io = lv_eff_pc_or_io
             BINARY SEARCH.

        IF sy-subrc <> 0.
          INSERT VALUE #( bukrs    = <ls_bill>-rbukrs
                          kunnr    = <ls_bill>-kunnr
                          pc_or_io = lv_eff_pc_or_io )
                 INTO gt_output INDEX sy-tabix ASSIGNING <fs_row>.
        ENDIF.

        lv_last_bukrs    = <ls_bill>-rbukrs.
        lv_last_kunnr    = <ls_bill>-kunnr.
        lv_last_pc_or_io = lv_eff_pc_or_io.
      ENDIF.

*-- BLNV (revenue) -> bill_nv_XX AND bill_vt_XX                      *
*-- BLVT (VAT)     -> bill_vt_XX only                                *
      IF <ls_bill>-category = gc_cat_bill_no_vat.

        m_add_to_field(
          EXPORTING iv_gjahr  = <ls_bill>-gjahr
                    iv_poper  = <ls_bill>-poper
                    iv_prefix = gc_prefix_bill_nv
                    iv_hsl    = <ls_bill>-hsl
          CHANGING  cs_row    = <fs_row> ).

        m_add_to_field(
          EXPORTING iv_gjahr  = <ls_bill>-gjahr
                    iv_poper  = <ls_bill>-poper
                    iv_prefix = gc_prefix_bill_vt
                    iv_hsl    = <ls_bill>-hsl
          CHANGING  cs_row    = <fs_row> ).

      ELSEIF <ls_bill>-category = gc_cat_bill_with_vat.

        m_add_to_field(
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

      m_add_to_field(
        EXPORTING iv_gjahr  = <ls_coll>-gjahr
                  iv_poper  = <ls_coll>-poper
                  iv_prefix = gc_prefix_coll_vt
                  iv_hsl    = <ls_coll>-hsl
        CHANGING  cs_row    = <fs_row> ).

    ENDLOOP.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD m_add_to_field
*&  Resolves target column from (gjahr, poper, prefix) and accumulates
*&  the amount.  Also updates _YR for current-year amounts.
*&---------------------------------------------------------------------*
  METHOD m_add_to_field.

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
*&  METHOD m_enrich_with_master_data
*&  Joins T001 + KNA1/ADRC/T005T + CEPCT + KNB1/T052 + lookup map
*&
*&  Performance improvements applied:
*&  1. lt_resolved: HASHED pre-resolved map replaces nested LOOP.
*&     IF p_rdpc outside loop; VALUE # FOR fills table in one shot.
*&     gt_doc_keys sorted + deduplicated in-place (no copy).
*&  2. Driver tables built in a single pass over gt_doc_keys.
*&  3. Master-data lookups use BINARY SEARCH (O log n vs O n).
*&  4. ls_final-kunnr populated (new ty_final field).
*&---------------------------------------------------------------------*
  METHOD m_enrich_with_master_data.

    IF gt_output IS INITIAL.
      RETURN.
    ENDIF.

*-- Local type for the pre-resolved one-row-per-key lookup -----------*
    TYPES: BEGIN OF ty_resolved,
             bukrs    TYPE acdoca-rbukrs,
             pc_or_io TYPE acdoca-aufnr,
             kunnr    TYPE acdoca-kunnr,
             prctr    TYPE acdoca-prctr,
             aufnr    TYPE acdoca-aufnr,
           END OF ty_resolved.

    DATA: lt_resolved TYPE HASHED TABLE OF ty_resolved
                      WITH UNIQUE KEY bukrs pc_or_io,
          lt_bk_keys  TYPE tt_bk,
          lt_bukrs    TYPE tt_bukrs,
          lt_prctr    TYPE tt_prctr,
          lt_t001     TYPE STANDARD TABLE OF ty_t001_lookup,
          lt_cust     TYPE STANDARD TABLE OF ty_cust_lookup,
          lt_cepct    TYPE STANDARD TABLE OF ty_cepct_lookup,
          lt_pmt      TYPE STANDARD TABLE OF ty_pmt_lookup,
          lv_eff_kunnr TYPE acdoca-kunnr,
          lv_eff_prctr TYPE acdoca-prctr,
          lv_eff_aufnr TYPE acdoca-aufnr.

*======================================================================*
*  STEP 1 - Driver tables for master-data SELECTs
*  Single pass over gt_doc_keys (all rows needed before dedup).
*  PC mode: supplement lt_bk_keys from gt_output (AR-line kunnr).
*======================================================================*
    LOOP AT gt_doc_keys ASSIGNING FIELD-SYMBOL(<ls_dk>).
      INSERT VALUE #( bukrs = <ls_dk>-rbukrs ) INTO TABLE lt_bukrs.
      IF <ls_dk>-kunnr IS NOT INITIAL.
        INSERT VALUE #( bukrs = <ls_dk>-rbukrs kunnr = <ls_dk>-kunnr )
               INTO TABLE lt_bk_keys.
      ENDIF.
      IF <ls_dk>-prctr IS NOT INITIAL.
        INSERT VALUE #( prctr = <ls_dk>-prctr ) INTO TABLE lt_prctr.
      ENDIF.
    ENDLOOP.

    IF p_rdpc = abap_true.
      LOOP AT gt_output ASSIGNING FIELD-SYMBOL(<ls_od>).
        IF <ls_od>-kunnr IS NOT INITIAL.
          INSERT VALUE #( bukrs = <ls_od>-bukrs kunnr = <ls_od>-kunnr )
                 INTO TABLE lt_bk_keys.
        ENDIF.
      ENDLOOP.
    ENDIF.

*======================================================================*
*  STEP 2 - Build pre-resolved lookup (one row per output key)
*  IF is outside the loop (p_rdpc is constant - no need to re-check).
*  gt_doc_keys sorted + deduplicated in-place: best row wins (sorted
*  DESCENDING so non-blank aufnr/prctr/kunnr ranks first).
*  VALUE # FOR fills the HASHED table in a single expression - safe
*  because DELETE ADJACENT DUPLICATES guarantees no key collisions.
*======================================================================*
    IF p_rdpc = abap_true.
      SORT gt_doc_keys BY rbukrs prctr aufnr DESCENDING kunnr DESCENDING.
      DELETE ADJACENT DUPLICATES FROM gt_doc_keys COMPARING rbukrs prctr.
      lt_resolved = VALUE #( FOR <ls_r> IN gt_doc_keys
                              ( bukrs    = <ls_r>-rbukrs
                                pc_or_io = <ls_r>-prctr
                                kunnr    = <ls_r>-kunnr
                                prctr    = <ls_r>-prctr
                                aufnr    = <ls_r>-aufnr ) ).
    ELSE.
      SORT gt_doc_keys BY rbukrs aufnr prctr DESCENDING kunnr DESCENDING.
      DELETE ADJACENT DUPLICATES FROM gt_doc_keys COMPARING rbukrs aufnr.
      lt_resolved = VALUE #( FOR <ls_r> IN gt_doc_keys
                              ( bukrs    = <ls_r>-rbukrs
                                pc_or_io = <ls_r>-aufnr
                                kunnr    = <ls_r>-kunnr
                                prctr    = <ls_r>-prctr
                                aufnr    = <ls_r>-aufnr ) ).
    ENDIF.

*======================================================================*
*  STEP 3 - Master-data SELECTs
*======================================================================*
    IF lt_bukrs IS NOT INITIAL.
      SELECT t~bukrs, t~butxt
        FROM @lt_bukrs AS d
             INNER JOIN t001 AS t ON t~bukrs = d~bukrs
        INTO CORRESPONDING FIELDS OF TABLE @lt_t001.
    ENDIF.

    IF lt_bk_keys IS NOT INITIAL.
      SELECT k~kunnr, k~name1, k~ktokd, a~city1, t~landx50
        FROM @lt_bk_keys AS d
             INNER JOIN kna1  AS k ON k~kunnr = d~kunnr
             LEFT OUTER JOIN adrc  AS a ON  a~addrnumber = k~adrnr
                                        AND a~nation     = @space
             LEFT OUTER JOIN t005t AS t ON  t~spras = @sy-langu
                                        AND t~land1 = a~country
        INTO CORRESPONDING FIELDS OF TABLE @lt_cust.
    ENDIF.

    IF lt_prctr IS NOT INITIAL.
      SELECT c~prctr, c~ltext
        FROM @lt_prctr AS d
             INNER JOIN cepct AS c ON  c~prctr = d~prctr
                                  AND c~spras = @sy-langu
                                  AND c~datbi >= @sy-datum
        INTO CORRESPONDING FIELDS OF TABLE @lt_cepct.
    ENDIF.

    IF lt_bk_keys IS NOT INITIAL.
      SELECT k~bukrs, k~kunnr, t~ztag1
        FROM @lt_bk_keys AS d
             INNER JOIN knb1 AS k ON  k~bukrs = d~bukrs
                                  AND k~kunnr = d~kunnr
             LEFT OUTER JOIN t052 AS t ON t~zterm = k~zterm
        INTO CORRESPONDING FIELDS OF TABLE @lt_pmt.
    ENDIF.

*-- Sort all lookup tables once so BINARY SEARCH is valid -------------*
    SORT lt_t001  BY bukrs.
    SORT lt_cust  BY kunnr.
    SORT lt_cepct BY prctr.
    SORT lt_pmt   BY bukrs kunnr.

*======================================================================*
*  STEP 4 - Merge: one pass over gt_output -> gt_final
*  Single O(1) hash read replaces the old O(K) inner LOOP.
*  All master-data reads use BINARY SEARCH (O log L vs O L).
*======================================================================*
    CLEAR gt_final.

    LOOP AT gt_output ASSIGNING FIELD-SYMBOL(<ls_out>).
      DATA(ls_final) = VALUE ty_final( ).
      MOVE-CORRESPONDING <ls_out> TO ls_final.

      CLEAR: lv_eff_kunnr, lv_eff_prctr, lv_eff_aufnr.

*-- O(1) hash lookup - replaces nested LOOP AT lt_lookup -------------*
      READ TABLE lt_resolved INTO DATA(ls_res)
           WITH TABLE KEY bukrs    = <ls_out>-bukrs
                          pc_or_io = <ls_out>-pc_or_io.
      IF sy-subrc = 0.
        IF p_rdpc = abap_true.
          lv_eff_kunnr = <ls_out>-kunnr.
          lv_eff_prctr = <ls_out>-pc_or_io.
          lv_eff_aufnr = ls_res-aufnr.
        ELSE.
          lv_eff_aufnr = <ls_out>-pc_or_io.
          lv_eff_kunnr = ls_res-kunnr.
          lv_eff_prctr = ls_res-prctr.
        ENDIF.
      ELSE.
        IF p_rdpc = abap_true.           " fallback: kunnr/prctr from row directly
          lv_eff_kunnr = <ls_out>-kunnr.
          lv_eff_prctr = <ls_out>-pc_or_io.
        ENDIF.
      ENDIF.

      ls_final-kunnr = lv_eff_kunnr.
      ls_final-prctr = lv_eff_prctr.
      ls_final-aufnr = lv_eff_aufnr.

*-- DoF flag ---------------------------------------------------------*
      IF lv_eff_prctr IS NOT INITIAL.
        ls_final-dof_flag = COND #(
          WHEN lv_eff_prctr(1) = gc_non_dof_prefix THEN TEXT-t01
          ELSE                                          TEXT-t02 ).
      ENDIF.

*-- Entity -----------------------------------------------------------*
      READ TABLE lt_t001 INTO DATA(ls_t001)
           WITH KEY bukrs = <ls_out>-bukrs BINARY SEARCH.
      IF sy-subrc = 0.
        ls_final-entity = ls_t001-butxt.
      ENDIF.

*-- Customer chain ---------------------------------------------------*
      IF lv_eff_kunnr IS NOT INITIAL.
        READ TABLE lt_cust INTO DATA(ls_cust)
             WITH KEY kunnr = lv_eff_kunnr BINARY SEARCH.
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
             WITH KEY prctr = lv_eff_prctr BINARY SEARCH.
        IF sy-subrc = 0.
          ls_final-research_ctr = ls_cepct-ltext.
        ENDIF.
      ENDIF.

*-- Payment Terms ----------------------------------------------------*
      IF lv_eff_kunnr IS NOT INITIAL.
        READ TABLE lt_pmt INTO DATA(ls_pmt)
             WITH KEY bukrs = <ls_out>-bukrs
                      kunnr = lv_eff_kunnr BINARY SEARCH.
        IF sy-subrc = 0.
          ls_final-pmt_terms = ls_pmt-ztag1.
        ENDIF.
      ENDIF.

      APPEND ls_final TO gt_final.
    ENDLOOP.

    SORT gt_final BY entity cust_name prctr aufnr.

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD m_display_report
*&  CL_SALV_TABLE with dynamic year-based column captions
*&---------------------------------------------------------------------*
  METHOD m_display_report.

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

    m_set_column_captions( io_cols = lo_cols ).
    m_set_aggregations( io_alv = lo_alv ).

*-- Display ----------------------------------------------------------*
    lo_alv->display( ).

  ENDMETHOD.

*&---------------------------------------------------------------------*
*&  METHOD m_set_column_captions
*&  Sets static + dynamic (year-based) column headers
*&
*&  Change: added set_col for KUNNR field (TEXT-c13).
*&  Create text symbol TEXT-c13 = 'Customer' in SE32.
*&---------------------------------------------------------------------*
  METHOD m_set_column_captions.

    DATA: lv_yy_curr TYPE n LENGTH 2,
          lv_yy_prev TYPE n LENGTH 2,
          lv_text    TYPE string.

    lv_yy_curr = p_gjahr+2(2).
    lv_yy_prev = ( p_gjahr - 1 ) MOD 100.

*-- Static columns ---------------------------------------------------*
    set_col( io_cols = io_cols iv_field = 'ENTITY'       iv_text = TEXT-c01 ).
    set_col( io_cols = io_cols iv_field = 'KUNNR'        iv_text = TEXT-c13 ).
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
*&  METHOD m_set_aggregations
*&  Enable totals on all amount columns
*&---------------------------------------------------------------------*
  METHOD m_set_aggregations.

    DATA: lt_amount_cols TYPE TABLE OF lvc_fname.
    DATA(lo_aggs) = io_alv->get_aggregations( ).

    lt_amount_cols = VALUE #(
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
