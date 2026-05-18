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
