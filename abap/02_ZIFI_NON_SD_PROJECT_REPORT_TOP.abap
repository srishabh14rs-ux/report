*&---------------------------------------------------------------------*
*& Include          ZIFI_NON_SD_PROJECT_REPORT_TOP
*&---------------------------------------------------------------------*
*& Global types, data and class definition
*&  - Public types are program-global (needed for selection screen
*&    and class signatures).
*&  - Constants are private to lcl_main (not used outside the class).
*&  - All class state (tables, work areas) lives as private attributes.
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*&  TABLES (for selection screen reference)
*&---------------------------------------------------------------------*
TABLES: acdoca.

*&---------------------------------------------------------------------*
*&  TYPES
*&---------------------------------------------------------------------*

*-- Document-key table (output of fetch_doc_keys) ---------------------*
TYPES:
  BEGIN OF ty_doc_key,
    rbukrs TYPE acdoca-rbukrs,
    belnr  TYPE acdoca-belnr,
    gjahr  TYPE acdoca-gjahr,
    poper  TYPE acdoca-poper,
    kunnr  TYPE acdoca-kunnr,
    prctr  TYPE acdoca-prctr,
    aufnr  TYPE acdoca-aufnr,
    blart  TYPE acdoca-blart,
  END OF ty_doc_key,
  tt_doc_key TYPE STANDARD TABLE OF ty_doc_key WITH EMPTY KEY.

*-- Bill bucket -------------------------------------------------------*
*  pc_or_io holds PRCTR (PC mode) or AUFNR (IO mode)
*  Type is acdoca-aufnr (12 chars) so both fit cleanly.
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
  END OF ty_bill_bucket,
  tt_bill_bucket TYPE STANDARD TABLE OF ty_bill_bucket WITH EMPTY KEY.

*-- Collection bucket -------------------------------------------------*
TYPES:
  BEGIN OF ty_coll_bucket,
    rbukrs   TYPE acdoca-rbukrs,
    kunnr    TYPE acdoca-kunnr,
    pc_or_io TYPE acdoca-aufnr,
    gjahr    TYPE acdoca-gjahr,
    poper    TYPE acdoca-poper,
    category TYPE c LENGTH 4,
    hsl      TYPE acdoca-hsl,
  END OF ty_coll_bucket,
  tt_coll_bucket TYPE STANDARD TABLE OF ty_coll_bucket WITH EMPTY KEY.

*-- Wide-format intermediate (amounts, keyed by bukrs/kunnr/pc_or_io) -*
TYPES:
  BEGIN OF ty_output,
    bukrs      TYPE acdoca-rbukrs,
    kunnr      TYPE acdoca-kunnr,
    pc_or_io   TYPE acdoca-aufnr,
    bill_nv_op TYPE acdoca-hsl,
    bill_nv_01 TYPE acdoca-hsl,
    bill_nv_02 TYPE acdoca-hsl,
    bill_nv_03 TYPE acdoca-hsl,
    bill_nv_04 TYPE acdoca-hsl,
    bill_nv_05 TYPE acdoca-hsl,
    bill_nv_06 TYPE acdoca-hsl,
    bill_nv_07 TYPE acdoca-hsl,
    bill_nv_08 TYPE acdoca-hsl,
    bill_nv_09 TYPE acdoca-hsl,
    bill_nv_10 TYPE acdoca-hsl,
    bill_nv_11 TYPE acdoca-hsl,
    bill_nv_12 TYPE acdoca-hsl,
    bill_nv_yr TYPE acdoca-hsl,
    bill_vt_op TYPE acdoca-hsl,
    bill_vt_01 TYPE acdoca-hsl,
    bill_vt_02 TYPE acdoca-hsl,
    bill_vt_03 TYPE acdoca-hsl,
    bill_vt_04 TYPE acdoca-hsl,
    bill_vt_05 TYPE acdoca-hsl,
    bill_vt_06 TYPE acdoca-hsl,
    bill_vt_07 TYPE acdoca-hsl,
    bill_vt_08 TYPE acdoca-hsl,
    bill_vt_09 TYPE acdoca-hsl,
    bill_vt_10 TYPE acdoca-hsl,
    bill_vt_11 TYPE acdoca-hsl,
    bill_vt_12 TYPE acdoca-hsl,
    bill_vt_yr TYPE acdoca-hsl,
    coll_vt_op TYPE acdoca-hsl,
    coll_vt_01 TYPE acdoca-hsl,
    coll_vt_02 TYPE acdoca-hsl,
    coll_vt_03 TYPE acdoca-hsl,
    coll_vt_04 TYPE acdoca-hsl,
    coll_vt_05 TYPE acdoca-hsl,
    coll_vt_06 TYPE acdoca-hsl,
    coll_vt_07 TYPE acdoca-hsl,
    coll_vt_08 TYPE acdoca-hsl,
    coll_vt_09 TYPE acdoca-hsl,
    coll_vt_10 TYPE acdoca-hsl,
    coll_vt_11 TYPE acdoca-hsl,
    coll_vt_12 TYPE acdoca-hsl,
    coll_vt_yr TYPE acdoca-hsl,
  END OF ty_output,
  tt_output TYPE STANDARD TABLE OF ty_output WITH EMPTY KEY.

*-- Final ALV output (master data + amounts) --------------------------*
TYPES:
  BEGIN OF ty_final,
*--- Master-data fields (1-11) ---------------------------------------*
    entity       TYPE t001-butxt,
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

*-- Master-data driver tables ----------------------------------------*
TYPES:
  BEGIN OF ty_bk,
    bukrs TYPE acdoca-rbukrs,
    kunnr TYPE acdoca-kunnr,
  END OF ty_bk,
  tt_bk TYPE HASHED TABLE OF ty_bk WITH UNIQUE KEY bukrs kunnr.

TYPES:
  BEGIN OF ty_bukrs_only,
    bukrs TYPE acdoca-rbukrs,
  END OF ty_bukrs_only,
  tt_bukrs TYPE HASHED TABLE OF ty_bukrs_only WITH UNIQUE KEY bukrs.

TYPES:
  BEGIN OF ty_prctr_only,
    prctr TYPE acdoca-prctr,
  END OF ty_prctr_only,
  tt_prctr TYPE HASHED TABLE OF ty_prctr_only WITH UNIQUE KEY prctr.

*-- Master-data lookup types (filled by enrich_with_master_data) -----*
TYPES:
  BEGIN OF ty_cust_lookup,
    kunnr   TYPE kna1-kunnr,
    name1   TYPE kna1-name1,
    ktokd   TYPE kna1-ktokd,
    city1   TYPE adrc-city1,
    landx50 TYPE t005t-landx50,
  END OF ty_cust_lookup,

  BEGIN OF ty_cepct_lookup,
    prctr TYPE cepct-prctr,
    ltext TYPE cepct-ltext,
  END OF ty_cepct_lookup,

  BEGIN OF ty_pmt_lookup,
    bukrs TYPE knb1-bukrs,
    kunnr TYPE knb1-kunnr,
    ztag1 TYPE t052-ztag1,
  END OF ty_pmt_lookup,

  BEGIN OF ty_t001_lookup,
    bukrs TYPE t001-bukrs,
    butxt TYPE t001-butxt,
  END OF ty_t001_lookup.


*&---------------------------------------------------------------------*
*&  CLASS lcl_main DEFINITION
*&  Controller class - orchestrates the full report flow.
*&---------------------------------------------------------------------*
CLASS lcl_main DEFINITION FINAL CREATE PRIVATE.

  PUBLIC SECTION.

    CLASS-METHODS:
      get_instance
        RETURNING VALUE(ro_instance) TYPE REF TO lcl_main.

    METHODS:
      modify_screen,
      get_data,
      process_data,
      display_report.

  PRIVATE SECTION.

*&---------------------------------------------------------------------*
*&  CONSTANTS (private - only used inside this class)
*&---------------------------------------------------------------------*

*-- Document types (BLART) -------------------------------------------*
    CONSTANTS: gc_blart_invoice     TYPE acdoca-blart VALUE 'DR',
               gc_blart_credit_memo TYPE acdoca-blart VALUE 'DG',
               gc_blart_billing_doc TYPE acdoca-blart VALUE 'RV',
               gc_blart_payment     TYPE acdoca-blart VALUE 'DZ',
               gc_blart_pay_offset  TYPE acdoca-blart VALUE 'Z4'.

*-- Ledger / posting flags -------------------------------------------*
    CONSTANTS: gc_leading_ledger TYPE acdoca-rldnr VALUE '0L',
               gc_vat_ktosl      TYPE acdoca-ktosl VALUE 'MWS',
               gc_debit          TYPE acdoca-drcrk VALUE 'S'.

*-- Customer master flags --------------------------------------------*
    CONSTANTS: gc_related_party TYPE kna1-ktokd VALUE 'ZRPC'.

*-- Profit-centre marker (DoF/Non-DoF) -------------------------------*
    CONSTANTS: gc_non_dof_prefix TYPE c LENGTH 1 VALUE 'N'.

*-- Bucket category codes --------------------------------------------*
    CONSTANTS: gc_cat_bill_no_vat   TYPE c LENGTH 4 VALUE 'BLNV',
               gc_cat_bill_with_vat TYPE c LENGTH 4 VALUE 'BLVT',
               gc_cat_coll_with_vat TYPE c LENGTH 4 VALUE 'CLVT'.

*-- Field-name prefixes for dynamic column resolution ----------------*
    CONSTANTS: gc_prefix_bill_nv TYPE string VALUE 'BILL_NV_',
               gc_prefix_bill_vt TYPE string VALUE 'BILL_VT_',
               gc_prefix_coll_vt TYPE string VALUE 'COLL_VT_'.

*-- Field-name suffixes for dynamic column resolution ----------------*
    CONSTANTS: gc_suffix_opening TYPE string VALUE 'OP',
               gc_suffix_yearly  TYPE string VALUE 'YR'.

*-- Selection-screen field names (for screen modification) -----------*
    CONSTANTS: gc_fld_prctr TYPE c LENGTH 7 VALUE 'S_PRCTR',
               gc_fld_aufnr TYPE c LENGTH 7 VALUE 'S_AUFNR'.

*-- Internal-order-mode specific constants ---------------------------*
    CONSTANTS: gc_rev_gl_pattern  TYPE acdoca-racct VALUE '0000003%',
               gc_excl_coll_racct TYPE acdoca-racct VALUE '0022999900'.

*&---------------------------------------------------------------------*
*&  STATIC ATTRIBUTES
*&---------------------------------------------------------------------*
    CLASS-DATA: go_singleton TYPE REF TO lcl_main.

*&---------------------------------------------------------------------*
*&  INSTANCE ATTRIBUTES (class-level tables)
*&---------------------------------------------------------------------*
    DATA: gt_doc_keys TYPE tt_doc_key,
          gt_bill     TYPE tt_bill_bucket,
          gt_coll     TYPE tt_coll_bucket,
          gt_output   TYPE tt_output,
          gt_final    TYPE tt_final.

*&---------------------------------------------------------------------*
*&  PRIVATE METHODS
*&---------------------------------------------------------------------*

*-- Data fetch (Profit Centre mode) ----------------------------------*
    METHODS:
      fetch_doc_keys,
      fetch_bill_buckets,
      fetch_coll_buckets.

*-- Data fetch (Internal Order mode) ---------------------------------*
    METHODS:
      fetch_doc_keys_io,
      fetch_bill_buckets_io,
      fetch_coll_buckets_io.

*-- Pivot ------------------------------------------------------------*
    METHODS:
      build_output,
      add_to_field
        IMPORTING iv_gjahr  TYPE acdoca-gjahr
                  iv_poper  TYPE acdoca-poper
                  iv_prefix TYPE string
                  iv_hsl    TYPE acdoca-hsl
        CHANGING  cs_row    TYPE ty_output.

*-- Enrichment -------------------------------------------------------*
    METHODS:
      enrich_with_master_data.

*-- ALV --------------------------------------------------------------*
    METHODS:
      set_column_captions
        IMPORTING io_cols TYPE REF TO cl_salv_columns_table,
      set_col
        IMPORTING io_cols  TYPE REF TO cl_salv_columns_table
                  iv_field TYPE csequence
                  iv_text  TYPE csequence,
      set_aggregations
        IMPORTING io_alv TYPE REF TO cl_salv_table.

ENDCLASS.


*&---------------------------------------------------------------------*
*&  Global controller instance (created at INITIALIZATION)
*&---------------------------------------------------------------------*
DATA: go_main TYPE REF TO lcl_main.
