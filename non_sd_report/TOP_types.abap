*&---------------------------------------------------------------------*
*& Include  ZIFI_NON_SD_PROJECT_REPORT_TOP  (changed types only)
*&---------------------------------------------------------------------*

*-- Bill bucket -------------------------------------------------------*
*  pc_or_io holds PRCTR (PC mode) or AUFNR (IO mode).
*  belnr is filled only for IO-mode MWS lines so m_build_output can
*  resolve their AUFNR via gt_doc_keys.
*---------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_bill_bucket,
    rbukrs   TYPE acdoca-rbukrs,
    kunnr    TYPE acdoca-kunnr,
    pc_or_io TYPE acdoca-aufnr,
    gjahr    TYPE acdoca-gjahr,
    poper    TYPE acdoca-poper,
    ktosl    TYPE acdoca-ktosl,
    category TYPE c LENGTH 4,
    hsl      TYPE acdoca-hsl,
    belnr    TYPE acdoca-belnr,       " NEW: blank for PC mode / revenue lines
  END OF ty_bill_bucket,
  tt_bill_bucket TYPE STANDARD TABLE OF ty_bill_bucket WITH EMPTY KEY.

*-- Final ALV output (master data + amounts) --------------------------*
TYPES:
  BEGIN OF ty_final,
*--- Master-data fields (1-12) ---------------------------------------*
    entity       TYPE t001-butxt,
    kunnr        TYPE acdoca-kunnr,   " NEW: customer number
    cust_name    TYPE kna1-name1,
    city         TYPE adrc-city1,
    country      TYPE t005t-landx50,
    research_ctr TYPE cepct-ltext,
    dof_flag     TYPE c LENGTH 20,
    prctr        TYPE acdoca-prctr,
    aufnr        TYPE acdoca-aufnr,
    rev_gl       TYPE acdoca-racct,
    rel_party    TYPE c LENGTH 3,
    pmt_terms    TYPE t052-ztag1,
*--- Bill NV ---------------------------------------------------------*
    bill_nv_op   TYPE acdoca-hsl,
    bill_nv_01   TYPE acdoca-hsl,
    bill_nv_02   TYPE acdoca-hsl,
    bill_nv_03   TYPE acdoca-hsl,
    bill_nv_04   TYPE acdoca-hsl,
    bill_nv_05   TYPE acdoca-hsl,
    bill_nv_06   TYPE acdoca-hsl,
    bill_nv_07   TYPE acdoca-hsl,
    bill_nv_08   TYPE acdoca-hsl,
    bill_nv_09   TYPE acdoca-hsl,
    bill_nv_10   TYPE acdoca-hsl,
    bill_nv_11   TYPE acdoca-hsl,
    bill_nv_12   TYPE acdoca-hsl,
    bill_nv_yr   TYPE acdoca-hsl,
*--- Bill VT ---------------------------------------------------------*
    bill_vt_op   TYPE acdoca-hsl,
    bill_vt_01   TYPE acdoca-hsl,
    bill_vt_02   TYPE acdoca-hsl,
    bill_vt_03   TYPE acdoca-hsl,
    bill_vt_04   TYPE acdoca-hsl,
    bill_vt_05   TYPE acdoca-hsl,
    bill_vt_06   TYPE acdoca-hsl,
    bill_vt_07   TYPE acdoca-hsl,
    bill_vt_08   TYPE acdoca-hsl,
    bill_vt_09   TYPE acdoca-hsl,
    bill_vt_10   TYPE acdoca-hsl,
    bill_vt_11   TYPE acdoca-hsl,
    bill_vt_12   TYPE acdoca-hsl,
    bill_vt_yr   TYPE acdoca-hsl,
*--- Collect VT ------------------------------------------------------*
    coll_vt_op   TYPE acdoca-hsl,
    coll_vt_01   TYPE acdoca-hsl,
    coll_vt_02   TYPE acdoca-hsl,
    coll_vt_03   TYPE acdoca-hsl,
    coll_vt_04   TYPE acdoca-hsl,
    coll_vt_05   TYPE acdoca-hsl,
    coll_vt_06   TYPE acdoca-hsl,
    coll_vt_07   TYPE acdoca-hsl,
    coll_vt_08   TYPE acdoca-hsl,
    coll_vt_09   TYPE acdoca-hsl,
    coll_vt_10   TYPE acdoca-hsl,
    coll_vt_11   TYPE acdoca-hsl,
    coll_vt_12   TYPE acdoca-hsl,
    coll_vt_yr   TYPE acdoca-hsl,
  END OF ty_final,
  tt_final TYPE STANDARD TABLE OF ty_final WITH EMPTY KEY.
