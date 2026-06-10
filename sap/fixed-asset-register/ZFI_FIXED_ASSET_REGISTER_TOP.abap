*&---------------------------------------------------------------------*
*& Include          ZFI_FIXED_ASSET_REGISTER_TOP
*&---------------------------------------------------------------------*
*----------------------------------------------------------------------*
* Type Pool for ALV Headers
*----------------------------------------------------------------------*
TYPE-POOLS: slis.

*----------------------------------------------------------------------*
* Table Declarations (for F4 Help on Selection Screen)
*----------------------------------------------------------------------*
TABLES: t001, anla, anlz, lfa1, ekko.

*----------------------------------------------------------------------*
* Constants
*----------------------------------------------------------------------*
CONSTANTS:
  gc_afabe     TYPE anlb-afabe VALUE '01',
  gc_bwasl_100 TYPE anep-bwasl VALUE '100',
  gc_bwasl_105 TYPE anep-bwasl VALUE '105',
  gc_bwasl_310 TYPE anep-bwasl VALUE '310'.

*----------------------------------------------------------------------*
* Type Definitions  (ALL in global section - required for ABAP syntax)
*----------------------------------------------------------------------*
TYPES:
  " T001 - Company Code Master
  BEGIN OF ty_t001,
    bukrs TYPE t001-bukrs,
    waers TYPE t001-waers,
    ktopl TYPE t001-ktopl,
  END OF ty_t001,

  " ANLA - Asset Master General
  BEGIN OF ty_anla,
    bukrs TYPE anla-bukrs,
    anln1 TYPE anla-anln1,
    anln2 TYPE anla-anln2,
    txt50 TYPE anla-txt50,
    anlkl TYPE anla-anlkl,
    ktogr TYPE anla-ktogr,
    menge TYPE anla-menge,
    aibn1 TYPE anla-aibn1,    " Original Asset (INVNR). Replace with AIBN1 if custom field exists.
  END OF ty_anla,

  " ANLZ - Asset Master Time-Dependent (Profit Center)
  BEGIN OF ty_anlz,
    bukrs TYPE anlz-bukrs,
    anln1 TYPE anlz-anln1,
    anln2 TYPE anlz-anln2,
    bdatu TYPE anlz-bdatu,
    prctr TYPE anlz-prctr,
  END OF ty_anlz,

  " ANLB - Depreciation Terms per Depreciation Area
  BEGIN OF ty_anlb,
    bukrs TYPE anlb-bukrs,
    anln1 TYPE anlb-anln1,
    anln2 TYPE anlb-anln2,
    afabe TYPE anlb-afabe,
    ndjar TYPE anlb-ndjar,
    ndper TYPE anlb-ndper,
    afabg TYPE anlb-afabg,
  END OF ty_anlb,

  " ANLC - Asset Annual Values
  BEGIN OF ty_anlc,
    bukrs TYPE anlc-bukrs,    "#02 - Company Code
    anln1 TYPE anlc-anln1,    "#03 - Main Asset Number
    anln2 TYPE anlc-anln2,    "#04 - Asset Subnumber
    gjahr TYPE anlc-gjahr,    "#05 - Fiscal Year
    afabe TYPE anlc-afabe,    "#06 - Depreciation Area
    kansw TYPE anlc-kansw,    "#17 - Cumulative APC
    kaufw TYPE anlc-kaufw,    "#18 - Cumulative Revaluation
    knafa TYPE anlc-knafa,    "#20 - Accum. Ordinary Depreciation
    nafap TYPE anlc-nafap,    "#29 - Planned Ordinary Depreciation
    nafav TYPE anlc-nafav,    "#~36 - Proportional Accum. Ord. Dep. (prior yrs)
    answl TYPE anlc-answl,    "#42 - APC Transactions for Year,
    abgan TYPE anlc-abgan,   "Added on 04.06.2026
*         abgaf TYPE abgan,         "#~43 - Retirements (custom ref type)
*         answt TYPE answt,         "Non-ANLC field - standalone reference type
  END OF ty_anlc,
  " ANEP - Asset Line Items
  BEGIN OF ty_anep,
    bukrs TYPE anep-bukrs,
    anln1 TYPE anep-anln1,
    anln2 TYPE anep-anln2,
    gjahr TYPE anep-gjahr,
    belnr TYPE anep-belnr,
    lnran TYPE anep-lnran,
    bwasl TYPE anep-bwasl,
    anbtr TYPE anep-anbtr,
    menge TYPE menge_d,
  END OF ty_anep,

  " ANEK - Asset Document Header
  BEGIN OF ty_anek,
    bukrs TYPE anek-bukrs,
    anln1 TYPE anek-anln1,
    anln2 TYPE anek-anln2,
    gjahr TYPE anek-gjahr,
    belnr TYPE anek-belnr,
    bwasl TYPE bwasl,
  END OF ty_anek,

  " T095 - GL Account Assignments for Asset Postings
  BEGIN OF ty_t095,
*    bukrs  TYPE bukrs,
    afabe  TYPE t095-afabe,
    ktogr  TYPE t095-ktogr,
    ktansw TYPE t095-ktansw,
  END OF ty_t095,

  " ANKT - Asset Class Description (language-dependent)
  BEGIN OF ty_ankt,
    spras TYPE ankt-spras,
    anlkl TYPE ankt-anlkl,
    txk50 TYPE ankt-txk50,
  END OF ty_ankt,

  " SKAT - GL Account Short Texts
  BEGIN OF ty_skat,
    spras TYPE skat-spras,
    ktopl TYPE skat-ktopl,
    saknr TYPE skat-saknr,
    txt20 TYPE skat-txt20,
  END OF ty_skat,

  " ACDOCA - Universal Journal (PO + Vendor linkage in S/4HANA)
  BEGIN OF ty_acdoca,
    rbukrs TYPE acdoca-rbukrs,
    gjahr  TYPE acdoca-gjahr,
    belnr  TYPE acdoca-belnr,
    awref  TYPE acdoca-awref,
    ebeln  TYPE acdoca-ebeln,
    lifnr  TYPE acdoca-lifnr,
  END OF ty_acdoca,

  " RBKP - MM Invoice Document Header (Vendor linkage)
  BEGIN OF ty_rbkp,
    bukrs TYPE rbkp-bukrs,
    gjahr TYPE rbkp-gjahr,
    belnr TYPE rbkp-belnr,
    lifnr TYPE rbkp-lifnr,
  END OF ty_rbkp,

  " LFA1 - Vendor Master General
  BEGIN OF ty_lfa1,
    lifnr TYPE lfa1-lifnr,
    name1 TYPE lfa1-name1,
  END OF ty_lfa1,

  " Final ALV Output Structure (29 Columns)
  BEGIN OF ty_output,
    bukrs      TYPE t001-bukrs,     " Col 01: Company Code
    ebeln      TYPE ekko-ebeln,     " Col 02: Purchase Order
    name1      TYPE lfa1-name1,     " Col 03: Vendor Name
    prctr      TYPE anlz-prctr,     " Col 04: Profit Center
    aibn1      TYPE anla-aibn1,     " Col 05: Original Asset (INVNR)
    anln1      TYPE anla-anln1,     " Col 06: Asset Number
    anln2      TYPE anla-anln2,     " Col 06: Sub-Asset Number
    bwasl      TYPE anep-bwasl,     " Col 07: Movement Type
    menge      TYPE menge_d,        " Col 08: Quantity
    ndjar      TYPE anlb-ndjar,     " Col 09: Useful Life (Years)
    ndper      TYPE anlb-ndper,     " Col 09: Useful Life (Periods)
    afabg      TYPE anlb-afabg,     " Col 10: Dep. Calc. Start Date
    txt50      TYPE anla-txt50,     " Col 11: Asset Description
    waers      TYPE t001-waers,     " Col 12: Currency
    anlkl      TYPE anla-anlkl,     " Col 13: Asset Class
    txk50      TYPE ankt-txk50,     " Col 14: Asset Class Description
    saknr      TYPE t095-ktansw,    " Col 15: GL Account
    txt20      TYPE skat-txt20,     " Col 16: GL Account Description
    opening    TYPE anlc-kansw,          " Col 17: Opening (ANLC-ANSWT)
    addition   TYPE anlc-answl,     " Col 18: Addition (ANLC-KANSW / ANEP BWASL=100 for AUC)
    impairment TYPE answt,          " Col 19: Impairment (derived - ANEP by BWASL)
    retirement TYPE anlc-kansw,          " Col 20: Asset Retirement (ANEP BWASL 200-299)
    transfer   TYPE answt,          " Col 21: Transferred (ANLC-ANSWL / ANEP BWASL=310 for AUC)
    inout      TYPE answt,          " Col 22: In/Out net (ANEP: BWASL=100 In, BWASL=105 Out)
    cip_cost   TYPE anlc-kaufw,     " Col 23: CIP Cost (ANLC-KAUFW)
    tot_acq    TYPE answt,          " Col 24: Total Acq. Cost (Col17 + Col18)
    dep_beg    TYPE anlc-nafav,     " Col 25: Dep. Beginning (previous year ANLC-KNAFA)
    dep_per    TYPE anlc-knafa,     " Col 26: Dep. Period (ANLC-NAFAG)
    dep_ret    TYPE anlc-abgan,     " Col 27: Dep. Retirement (ANLC-ABGAF)
    dep_end    TYPE anlc-nafap,     " Col 28: Dep. End (current year ANLC-KNAFA)
    book_val   TYPE answt,          " Col 29: Book Value (Col24 - Col28)
  END OF ty_output.

*----------------------------------------------------------------------*
* Internal Table Declarations (ALL global) - RENAMED gt_*
*----------------------------------------------------------------------*
DATA:
  gt_t001    TYPE STANDARD TABLE OF ty_t001,
  gt_anla    TYPE STANDARD TABLE OF ty_anla,
  gt_anlz    TYPE SORTED TABLE OF ty_anlz
               WITH NON-UNIQUE KEY bukrs anln1 anln2 bdatu,
  gt_anlb    TYPE SORTED TABLE OF ty_anlb
               WITH NON-UNIQUE KEY bukrs anln1 anln2 afabe,
  gt_anlc    TYPE STANDARD TABLE OF ty_anlc,
  gt_anlc_py TYPE STANDARD TABLE OF ty_anlc,     " ANLC previous year
  gt_anep    TYPE SORTED TABLE OF ty_anep
               WITH NON-UNIQUE KEY bukrs anln1 anln2 gjahr bwasl,
  gt_anek    TYPE SORTED TABLE OF ty_anek
               WITH NON-UNIQUE KEY bukrs anln1 anln2 gjahr,
  gt_t095    TYPE SORTED TABLE OF ty_t095
               WITH NON-UNIQUE KEY afabe ktogr,
  gt_ankt    TYPE SORTED TABLE OF ty_ankt
               WITH NON-UNIQUE KEY spras anlkl,
  gt_skat    TYPE SORTED TABLE OF ty_skat
               WITH NON-UNIQUE KEY spras ktopl saknr,
  gt_acdoca  TYPE SORTED TABLE OF ty_acdoca
               WITH NON-UNIQUE KEY rbukrs gjahr awref,
  gt_rbkp    TYPE SORTED TABLE OF ty_rbkp
               WITH NON-UNIQUE KEY bukrs gjahr belnr,
  gt_lfa1    TYPE SORTED TABLE OF ty_lfa1
               WITH UNIQUE KEY lifnr,
  gt_output  TYPE STANDARD TABLE OF ty_output.

*----------------------------------------------------------------------*
* Range tables (ALL global)
*----------------------------------------------------------------------*
DATA:
  gr_imp         TYPE RANGE OF anep-bwasl,
  ls_imp_r       LIKE LINE OF gr_imp,
  gt_belnr_range TYPE RANGE OF anek-belnr,
  ls_belnr_range LIKE LINE OF gt_belnr_range,
  gt_rbkp_belnr  TYPE RANGE OF rbkp-belnr,
  ls_rbkp_belnr  LIKE LINE OF gt_rbkp_belnr,
  gt_lifnr_range TYPE RANGE OF lfa1-lifnr,
  ls_lifnr_range LIKE LINE OF gt_lifnr_range.

*----------------------------------------------------------------------*
* Work Areas - RENAMED ls_*
*----------------------------------------------------------------------*
DATA:
  ls_t001   TYPE ty_t001,
  ls_anla   TYPE ty_anla,
  ls_anlz   TYPE ty_anlz,
  ls_anlb   TYPE ty_anlb,
  ls_anlc   TYPE ty_anlc,
  ls_anc_py TYPE ty_anlc,
  ls_anep   TYPE ty_anep,
  ls_anek   TYPE ty_anek,
  ls_t095   TYPE ty_t095,
  ls_ankt   TYPE ty_ankt,
  ls_skat   TYPE ty_skat,
  ls_acdoca TYPE ty_acdoca,
  ls_rbkp   TYPE ty_rbkp,
  ls_lfa1   TYPE ty_lfa1,
  ls_output TYPE ty_output.

*----------------------------------------------------------------------*
* Global Variables
*----------------------------------------------------------------------*
DATA:
  gv_gjahr_py  TYPE gjahr,
  gv_auc_class TYPE anla-anlkl,
  gv_is_auc    TYPE abap_bool,
  gv_ktopl     TYPE t001-ktopl,
  gv_lifnr     TYPE lfa1-lifnr,
  lv_imp_amt   TYPE answt,
  lv_ret_amt   TYPE answt,
  lv_trf_amt   TYPE answt,
  lv_in_amt    TYPE answt,
  lv_out_amt   TYPE answt,
  lv_add_auc   TYPE anlc-kansw.

*----------------------------------------------------------------------*
* ALV Objects
*----------------------------------------------------------------------*
DATA:
  gt_fieldcat TYPE lvc_t_fcat,
  gt_sort     TYPE lvc_t_sort,
  ls_layout   TYPE lvc_s_layo,
  ls_variant  TYPE disvariant.

*----------------------------------------------------------------------*
* SELECTION SCREEN
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.

  SELECT-OPTIONS: s_bukrs FOR t001-bukrs OBLIGATORY,
                  s_anlkl FOR anla-anlkl,
                  s_anln1 FOR anla-anln1,
                  s_prctr FOR anlz-prctr,
                  s_lifnr FOR lfa1-lifnr,
                  s_ebeln FOR ekko-ebeln.

  PARAMETERS: p_gjahr TYPE gjahr  OBLIGATORY,
              p_peraf TYPE monat  OBLIGATORY DEFAULT '001',
              p_perat TYPE monat  OBLIGATORY DEFAULT '012',
              p_afabe TYPE anlb-afabe DEFAULT '01'.

SELECTION-SCREEN END OF BLOCK b1.
