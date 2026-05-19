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
