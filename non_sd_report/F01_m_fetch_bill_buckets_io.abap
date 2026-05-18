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
