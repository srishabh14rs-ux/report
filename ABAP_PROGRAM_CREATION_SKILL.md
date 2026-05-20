---
name: abap-program-creation
description: "Use this skill whenever creating, refactoring, or scaffolding any ABAP program, report, or include. Triggers include: 'create a report', 'write an ABAP program', 'refactor this into local classes', 'restructure this include', 'create includes for this program', 'convert FORMs to methods', 'scaffold a BAdI implementation', or any request to produce ABAP code that spans more than a single method or snippet. Also use when the user pastes existing ABAP code and asks for it to be restructured, modernized, or refactored. DO NOT use for single method/form fixes, debugging help, or BRF+ configuration tasks."
---

# ABAP Program Creation

This skill encodes confirmed conventions and architecture decisions for ABAP program generation. Apply these without asking clarifying questions unless something is genuinely absent and critical.

---

## Naming Conventions (Confirmed)

### Program & Object Names
| Object | Pattern | Example |
|---|---|---|
| Report | `ZR<MOD>_<NAME>` | `ZRFI_NON_SD_PROJECT_REPORT` |
| Include | `Z<MOD>_<NAME>_<SUFFIX>` | `ZIFI_NON_SD_PROJECT_REPORT_TOP` |
| Function Group | `Z<MOD>_<NAME>` | `ZFI_PRCTR_CUST` |
| BAdI Impl Class | `ZCL_BADI_<NAME>` | `ZCL_BADI_ME_PR_CUST` |
| Enhancement Spot | `ZES_<NAME>` | `ZES_PRCTR_SCREEN` |

### Include Suffixes
| Suffix | Content |
|---|---|
| `_TOP` | Types, constants, class definitions, global variable instances |
| `_S01` | Selection screen |
| `_F01` | Class implementations + event block delegation only |
| `_CLS` | (optional) Separate class implementations if F01 becomes large |

### Variable Prefixes
| Scope | Type | Table | Structure | Object ref |
|---|---|---|---|---|
| Global | `gv_` | `gt_` | `gs_` | `go_` |
| Local | `lv_` | `lt_` | `ls_` | `lo_` |
| Class member | `mv_` | `mt_` | `ms_` | `mo_` |
| Constant | `gc_` | — | — | — |
| Parameter (importing) | `iv_`/`it_`/`is_` | | | |
| Parameter (returning) | `rv_`/`rt_`/`rs_` | | | |
| Parameter (changing) | `cv_`/`ct_`/`cs_` | | | |
| Parameter (exporting) | `ev_`/`et_`/`es_` | | | |

### Type Prefixes
| Object | Prefix | Example |
|---|---|---|
| Type (scalar) | `ty_` | `ty_status` |
| Table type | `tt_` | `tt_output` |
| Structure type | `ts_` | `ts_output` |

### Subroutine / Method Names
- Format: `verb_noun` — `get_data`, `build_output`, `display_report`, `fetch_doc_keys`
- All lowercase with underscore separators
- BAdI methods follow interface names exactly

---

## Standard Program Architecture

### Default: Single Controller Class Pattern
Use for all reports unless specified otherwise. Never use global classes for single-program reports — local classes only.

**Main Program (REPORT):**
```abap
REPORT zr<mod>_<name>.
INCLUDE z<mod>_<name>_top.   " types, constants, class defs, global instances
INCLUDE z<mod>_<name>_s01.   " selection screen
INCLUDE z<mod>_<name>_f01.   " class implementations

INITIALIZATION.
  go_main = lcl_main=>get_instance( ).

AT SELECTION-SCREEN OUTPUT.
  go_main->modify_screen( ).

START-OF-SELECTION.
  go_main->get_data( ).
  go_main->process_data( ).
  go_main->display_report( ).
```

**TOP Include structure:**
1. Types section (`TYPES:`)
2. Constants section (`CONSTANTS:`) — all `gc_` prefixed, NO string literals in F01/S01
3. Class definition (`CLASS lcl_main DEFINITION`)
4. Global instance declaration (`DATA: go_main TYPE REF TO lcl_main.`)

**F01 Include structure:**
1. Class implementation (`CLASS lcl_main IMPLEMENTATION`)
2. All methods implemented here
3. Event blocks contain ONE line each — delegate to `go_main->method( )`

**lcl_main skeleton:**
```abap
CLASS lcl_main DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS get_instance RETURNING VALUE(ro_instance) TYPE REF TO lcl_main.
    METHODS:
      modify_screen,
      get_data,
      process_data,
      display_report.
  PRIVATE SECTION.
    CLASS-DATA go_instance TYPE REF TO lcl_main.
    DATA:
      mt_<main_table> TYPE tt_<main_table>,
      mt_output       TYPE tt_output,
      mo_alv          TYPE REF TO cl_gui_alv_grid.
    METHODS:
      build_field_catalog RETURNING VALUE(rt_fcat) TYPE lvc_t_fcat,
      set_layout          RETURNING VALUE(rs_layout) TYPE lvc_s_layo.
ENDCLASS.

CLASS lcl_main IMPLEMENTATION.
  METHOD get_instance.
    IF go_instance IS NOT BOUND.
      go_instance = NEW #( ).
    ENDIF.
    ro_instance = go_instance.
  ENDMETHOD.
ENDCLASS.
```

---

## Coding Standards (Always Apply)

### Syntax
- **Modern ABAP only**: inline declarations `DATA(lv_x)`, string templates `` |{ lv_x }| ``, `NEW #( )`, `CONV`, `CORRESPONDING`, `REDUCING`, `FILTER`, `FOR ... IN`
- **No obsolete**: no `MOVE`, no `COMPUTE`, no `ADD/SUBTRACT`, no `WRITE TO`, no `CONCATENATE` (use string templates)
- **No `SELECT *`**: always name fields explicitly or use `@DATA(ls_result)`
- **RETURNING preferred** over EXPORTING for methods that return a single value

### HANA-Compatibility Rules
- No nested SELECTs (no SELECT inside a loop)
- No `ORDER BY` on non-key fields without `%_HINTS` or CDS
- Use `UP TO 1 ROWS` instead of `SELECT SINGLE` for non-key reads
- Avoid `IS INITIAL` checks on joined results — check `sy-subrc` instead
- Prefer `JOIN` in SELECT over separate SELECTs with loops
- Use `@DATA()` inline for all SELECT targets

### No Hardcoding Rule
Every string/number literal that represents business logic goes into a constant in TOP:
```abap
CONSTANTS:
  gc_doc_type_dr   TYPE blart VALUE 'DR',
  gc_pstyp_service TYPE pstyp VALUE '9',
  gc_step_activate TYPE i     VALUE 98.
```
Text shown to user (column headers, messages) → text elements `TEXT-001` etc.

### Error Handling
- BAPI calls: always check `lt_return` for `TYPE = 'E'` or `'A'` before `BAPI_TRANSACTION_COMMIT`
- FM calls: always handle `OTHERS` exception
- Database reads: check `sy-subrc` after every `SELECT SINGLE` / `UP TO 1 ROWS`

---

## Performance Optimization Patterns (NEW)

### 1. HASHED Table Lookups (O(1) instead of O(n))

**Pattern:** Pre-sort + deduplicate, then use HASHED table with `READ TABLE ... WITH TABLE KEY`

```abap
*-- Create HASHED table with unique key for O(1) lookups
TYPES: BEGIN OF ty_resolved,
         bukrs    TYPE acdoca-rbukrs,
         pc_or_io TYPE acdoca-aufnr,
         kunnr    TYPE acdoca-kunnr,
       END OF ty_resolved.

DATA lt_resolved TYPE HASHED TABLE OF ty_resolved
                 WITH UNIQUE KEY bukrs pc_or_io.

*-- Populate: one row per key, DESCENDING wins tie-breaks
SORT gt_doc_keys BY rbukrs aufnr kunnr DESCENDING.
DELETE ADJACENT DUPLICATES FROM gt_doc_keys COMPARING rbukrs aufnr.
lt_resolved = VALUE #( FOR <ls_r> IN gt_doc_keys
                        ( bukrs    = <ls_r>-rbukrs
                          pc_or_io = <ls_r>-aufnr
                          kunnr    = <ls_r>-kunnr ) ).

*-- Lookup: O(1) hash read, never iterates
READ TABLE lt_resolved INTO DATA(ls_res)
     WITH TABLE KEY bukrs    = lv_bukrs
                    pc_or_io = lv_aufnr.
IF sy-subrc = 0.
  lv_kunnr = ls_res-kunnr.
ENDIF.
```

**When to use:** Frequent repeated lookups on the same key (10+ lookups on 1000+ rows = massive gain)

---

### 2. BINARY SEARCH on Sorted Lookups (O(log n) vs O(n))

**Pattern:** Sort lookup table once, then use `BINARY SEARCH` in all subsequent reads

```abap
*-- Sort once after all data is loaded
SORT lt_customer BY kunnr.

*-- Loop with BINARY SEARCH (O(log n) per read, not O(n))
LOOP AT gt_output ASSIGNING FIELD-SYMBOL(<ls_out>).
  READ TABLE lt_customer INTO DATA(ls_cust)
       WITH KEY kunnr = <ls_out>-kunnr BINARY SEARCH.
  IF sy-subrc = 0.
    <ls_out>-cust_name = ls_cust-name1.
  ENDIF.
ENDLOOP.
```

**Complexity:**
- Without BINARY SEARCH: O(m × n) where m = loop iterations, n = table rows
- With BINARY SEARCH: O(m × log n) — for m=1000, n=1000: 10M ops → 10K ops

---

### 3. SELECT DISTINCT Joined on Internal Tables (Database-side filtering)

**Pattern:** Join directly on `@gt_doc_keys` / `@gt_output` with DISTINCT to avoid manual dedup

```abap
*-- Instead of building separate driver tables and SELECTs,
*-- join directly on the internal table source
SELECT DISTINCT t~bukrs, t~butxt
  FROM @gt_doc_keys AS d
       INNER JOIN t001 AS t ON t~bukrs = d~rbukrs
  INTO TABLE @lt_t001.

*-- Append results from multiple sources (PC mode + IO mode)
SELECT DISTINCT k~kunnr, k~name1
  FROM @gt_doc_keys AS d
       INNER JOIN kna1 AS k ON k~kunnr = d~kunnr AND d~kunnr <> @space
  INTO TABLE @lt_cust.

SELECT DISTINCT k~kunnr, k~name1
  FROM @gt_output AS o
       INNER JOIN kna1 AS k ON k~kunnr = o~kunnr AND o~kunnr <> @space
  APPENDING TABLE @lt_cust.
```

**Benefit:** 
- Eliminates O(n) loop-based driver table building (lt_bukrs, lt_prctr, lt_bk_keys)
- Database handles deduplication with DISTINCT (faster than application layer)
- Filters at source: `AND d~kunnr <> @space` in SELECT beats post-filter LOOP

---

### 4. VALUE # FOR Expressions (Bulk construction, no LOOP/INSERT)

**Pattern:** Build entire table in one expression instead of LOOP-at-source / INSERT

**Bad (O(n) inserts with overhead):**
```abap
LOOP AT gt_doc_keys ASSIGNING FIELD-SYMBOL(<ls_dk>).
  INSERT VALUE #( bukrs = <ls_dk>-rbukrs prctr = <ls_dk>-prctr )
         INTO TABLE lt_prctr.
ENDLOOP.
```

**Good (O(n) with less overhead):**
```abap
lt_resolved = VALUE #( FOR <ls_r> IN gt_doc_keys
                        ( bukrs    = <ls_r>-rbukrs
                          pc_or_io = <ls_r>-prctr
                          kunnr    = <ls_r>-kunnr ) ).
```

**Safe use:** Only after `DELETE ADJACENT DUPLICATES` guarantees no key collisions in HASHED tables

---

### 5. APPENDING TABLE (Multi-source accumulation)

**Pattern:** First SELECT uses `INTO TABLE`, subsequent ones use `APPENDING TABLE`

```abap
*-- First SELECT: INTO (replace, clear target)
SELECT DISTINCT ...
  FROM @gt_doc_keys ...
  INTO TABLE @lt_lookup.

*-- Second SELECT: APPENDING (accumulate)
SELECT DISTINCT ...
  FROM @gt_output ...
  APPENDING TABLE @lt_lookup.

*-- Now deduplicate if needed
SORT lt_lookup BY key_field.
DELETE ADJACENT DUPLICATES FROM lt_lookup COMPARING key_field.
```

**Benefit:** Avoids separate SELECT + manual append loop

---

### 6. Algorithmic Improvements (Complexity Analysis)

**Document the complexity savings in comments above methods that use these patterns:**

```abap
*-- Performance: O(1) hash read replaces O(m×k) nested LOOP
*-- Eliminates O(n) loop-based driver table building
*-- Four SELECTs joined on @gt_doc_keys use database-side DISTINCT
```

**Example: m_enrich_with_master_data gains:**
- Removed O(n) driver table build loops
- Removed O(m×k) nested LOOP lookups in merge pass
- O(1) hash resolution for (bukrs, pc_or_io) matching
- O(log L) BINARY SEARCH on sorted master-data lookups
- Result: from O(n + m×k + m×L) → O(n + m×log L + m) for sorted tables

---

## ALV Standard Pattern

```abap
METHOD build_field_catalog.
  DATA ls_fcat TYPE lvc_s_fcat.
  DEFINE m_fcat.
    CLEAR ls_fcat.
    ls_fcat-fieldname  = &1.
    ls_fcat-coltext    = &2.
    ls_fcat-outputlen  = &3.
    ls_fcat-just       = &4.
    APPEND ls_fcat TO rt_fcat.
  END-OF-DEFINITION.

  m_fcat 'FIELD1' TEXT-001 10 'L'.
  m_fcat 'AMOUNT' TEXT-002 15 'R'.
ENDMETHOD.

METHOD set_layout.
  rs_layout-zebra      = abap_true.
  rs_layout-cwidth_opt = abap_true.
  rs_layout-sel_mode   = 'D'.
ENDMETHOD.

METHOD display_report.
  DATA(lt_fcat)   = build_field_catalog( ).
  DATA(ls_layout) = set_layout( ).

  IF mo_alv IS NOT BOUND.
    mo_alv = NEW cl_gui_alv_grid(
      i_parent = cl_gui_container=>default_screen ).
  ENDIF.

  mo_alv->set_table_for_first_display(
    EXPORTING
      is_layout       = ls_layout
    CHANGING
      it_outtab       = mt_output
      it_fieldcatalog = lt_fcat ).
ENDMETHOD.
```

---

## BAdI Implementation Pattern

### ME Framework (Procurement) BAdIs
For `ME_PROCESS_REQ_CUST` and `ME_PROCESS_PO_CUST` — see confirmed warning message pattern in memory.

**Scaffold:**
```abap
CLASS zcl_badi_<name> DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_ex_<badi_interface>.
    ALIASES:
      check FOR if_ex_<badi_interface>~check.
ENDCLASS.

CLASS zcl_badi_<name> IMPLEMENTATION.
  METHOD check.
    INCLUDE mm_messages_mac.
    " mmpur_business_obj im_item.          " PR: pass object ref
    " mmpur_business_obj_id ls_item-id.    " PO: pass ID field
    " mmpur_metafield mmmfd_<field>.       " optional: highlight field
    " mmpur_message_forced 'W' 'ZMM' '001' '' '' '' ''.
  ENDMETHOD.
ENDCLASS.
```

### Screen Enhancement BAdIs (KE51/KE52 etc.)
- Create Function Group `ZFG_<NAME>` → program `SAPLZFG_<NAME>`
- Create subscreen `0100` with type = Subscreen in SE51
- Register in BAdI with `Default Program = SAPLZFG_<NAME>`, `Screen = 0100`
- TABLES declaration for main structure goes in FG TOP include

---

## Refactoring Checklist (FORM → Local Class)

When given an existing program to restructure:
1. **Do not change any logic** — pure structural refactor
2. Move all `TYPES`/`DATA`/`CONSTANTS` from TOP into class definition private section
3. Each `FORM f_<name>` becomes `METHOD <name>` on `lcl_main`
4. Global variables referenced across forms become `mt_`/`mv_`/`ms_` class attributes
5. `START-OF-SELECTION` becomes one line: `go_main->run( ).`  
   Or split into `get_data` / `process_data` / `display_report` if the form structure allows clean separation
6. All string literals → `gc_` constants in TOP
7. Apply modern syntax throughout (but same logic)
8. Verify: every constant declared, no `SELECT *`, no nested SELECTs
9. **Document complexity improvements** in method comments if applying performance patterns

---

## What NOT to Do
- Never suggest global classes for a single-program report
- Never use `MESSAGE ... TYPE 'W'` inside ME BAdI CHECK method (swallowed silently)
- Never hardcode document types, movement types, or business logic strings inline
- Never use `PERCENTAGE` width type in ALV field catalog (use `OUTPUTLEN`)
- Never put business logic in event blocks — they delegate to `go_main` only
- Never iterate over a lookup table multiple times for the same data — use HASHED table with O(1) READ instead
- Never build multi-source HASHED tables with `VALUE #` before deduplication — collisions fail silently
- Never skip `BINARY SEARCH` clause after sorting a lookup table that's read in a loop (n × log n matters at scale)
