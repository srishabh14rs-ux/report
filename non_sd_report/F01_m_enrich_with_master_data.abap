*&---------------------------------------------------------------------*
*&  METHOD m_enrich_with_master_data
*&  Joins T001 + KNA1/ADRC/T005T + CEPCT + KNB1/T052 + lookup map
*&
*&  Changes:
*&  1. PC mode: lv_eff_kunnr and lv_eff_prctr set directly from the
*&     output row BEFORE the lookup loop.  The AR line (kunnr filled,
*&     prctr = space) sits under pc_or_io = space in lt_lookup, so
*&     the old in-loop match never fired; kunnr/cust_name were blank.
*&  2. PC mode loop now only searches for aufnr (first non-blank).
*&  3. lt_bk_keys also populated from gt_output kunnr so KNA1/KNB1
*&     SELECTs cover customers whose kunnr came from the output row.
*&  4. ls_final-kunnr populated (new ty_final field).
*&---------------------------------------------------------------------*
  METHOD m_enrich_with_master_data.

    IF gt_output IS INITIAL.
      RETURN.
    ENDIF.

*======================================================================*
*  Build doc-key lookup keyed at gt_output grain
*  PC mode: key = (bukrs, pc_or_io=prctr) -> aufnr
*  IO mode: key = (bukrs, pc_or_io=aufnr) -> kunnr + prctr
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
      SORT lt_doc_keys_sorted BY rbukrs kunnr prctr aufnr DESCENDING.
    ELSE.
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

*-- PC mode: kunnr comes from gt_output (bill bucket), not lookup ----*
*   Ensure KNA1/KNB1 are fetched for those customers too             *
    IF p_rdpc = abap_true.
      LOOP AT gt_output ASSIGNING FIELD-SYMBOL(<ls_out_drv>).
        IF <ls_out_drv>-kunnr IS NOT INITIAL.
          INSERT VALUE #( bukrs = <ls_out_drv>-bukrs kunnr = <ls_out_drv>-kunnr )
                 INTO TABLE lt_bk_keys.
        ENDIF.
      ENDLOOP.
    ENDIF.

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

*-- Resolve effective KUNNR / PRCTR / AUFNR --------------------------*
      DATA: lv_eff_kunnr TYPE acdoca-kunnr,
            lv_eff_prctr TYPE acdoca-prctr,
            lv_eff_aufnr TYPE acdoca-aufnr.

      CLEAR: lv_eff_kunnr, lv_eff_prctr, lv_eff_aufnr.

*-- PC mode: kunnr and prctr are already on the output row ----------*
*   The lookup loop only resolves aufnr.                             *
      IF p_rdpc = abap_true.
        lv_eff_kunnr = <ls_out>-kunnr.
        lv_eff_prctr = <ls_out>-pc_or_io.
      ENDIF.

      LOOP AT lt_lookup ASSIGNING <ls_lk>
           USING KEY bk_p
           WHERE bukrs    = <ls_out>-bukrs
             AND pc_or_io = <ls_out>-pc_or_io.

        IF p_rdpc = abap_true.
*--- PC mode: find first non-blank aufnr for this prctr --------------*
          IF <ls_lk>-aufnr IS NOT INITIAL.
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

      ls_final-kunnr = lv_eff_kunnr.
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
