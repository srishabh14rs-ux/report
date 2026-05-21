# Non-SD Billing & Collection Report (ZFI_NSD)

## Overview

This repository contains a **SAP RAP analytical CDS framework** for a Non-SD (non-Sales & Distribution) accounts-receivable, billing, and collection report. The report aggregates Universal Journal (`ACDOCA`) data enriched with customer, company, and master-data information from standard SAP tables.

**Key Facts:**
- **Source Data:** `ACDOCA` (Universal Journal) with joins to T001, KNA1, ADRC, T005T, CEPCT, KNB1, T052
- **Target Platform:** S/4HANA on-premise (standard abapGit `/src` layout)
- **Approach:** Pure CDS analytical views (no RAP query class), flat merged-joins architecture
- **Namespace:** `ZFI_NSD_` (all objects prefixed)
- **Export:** Full project importable via abapGit

---

## Architecture

### Layer Model

```
ACDOCA (fact)
    ↓
[joins] ← T001, KNA1, ADRC, T005T, CEPCT, KNB1, T052
    ↓
ZFI_NSD_I_Billing_Cube
  @Analytics.dataCategory: #CUBE
  (aggregation core: all joins, GROUP BY, SUM/CASE measures)
    ↓
ZFI_NSD_C_NonSdBilling
  @Analytics.query: true
  (OData consumption, selection filters, parameter passing)
    ↓
Service Definition → Service Binding → OData V4 API
```

### Objects

| File | Type | Purpose |
|------|------|---------|
| `.abapgit.xml` | Git metadata | abapGit repo descriptor |
| `src/package.devc.xml` | ABAP Package | `ZFI_NSD` package definition |
| `src/zfi_nsd_i_billing_cube.ddls.asddls` | CDS View (CUBE) | Aggregation core; joins 8 tables inline; 42 measures |
| `src/zfi_nsd_c_nonsd_billing.ddls.asddls` | CDS View (QUERY) | Consumption layer; selection filters + labels |
| `src/zfi_nsd_ui_nonsd_billing.srvd.srvdsrv` | Service Definition | Service contract |
| `src/zfi_nsd_ui_nonsd_billing.srvb.xml` | Service Binding | OData V4 UI binding |
| `README.md` | Documentation | This file |

---

## Selection Screen Mapping

The selection screen (from `NONSD_po.xlsx` → "screen" tab) maps to CDS filters as follows:

| Input Label | Field | CDS Filter Field | Mandatory | Type |
|---|---|---|---|---|
| Company Code | BUKRS | `CompanyCode` (RBUKRS) | **Yes** | `@Consumption.filter.mandatory: true` |
| Customer | KUNNR | `Customer` (KUNNR) | No | `@Consumption.filter.hidden: false` |
| Profit Centre | PRCTR | `ProfitCenter` (PRCTR) | No | `@Consumption.filter.hidden: false` |
| Internal Order | AUFNR | `InternalOrder` (AUFNR) | No | `@Consumption.filter.hidden: false` |
| Period | PERIO | `POPER` (implicit in monthly measures) | **Yes** | Filtered via measure selection |
| Fiscal Year | GJAHR | `P_FiscalYear` (CDS parameter) | **Yes** | `with parameters P_FiscalYear : abap.numc(4)` |

---

## Output Columns & Traceability Matrix

All 53 output columns from `NONSD_po.xlsx` → "output" tab are exposed in `ZFI_NSD_C_NonSdBilling`.

### Master Data Columns (1–11)

| Col # | Output Label | CDS Field | Type | Logic / Source |
|----|----|----|----|---|
| 1 | Entity | `Entity` | Attribute | T001.BUTXT (company code text) |
| 2 | Customer Name | `CustomerName` | Attribute | KNA1.NAME1 |
| 3 | City | `City` | Attribute | ADRC.CITY1 (from customer's address) |
| 4 | Country | `Country` | Attribute | T005T.LANDX50 (country text, SPRAS='E') |
| 5 | Research Center | `ResearchCenter` | Attribute | CEPCT.LTEXT (profit center text, SPRAS='E') |
| 6 | DoF/ Non-DoF Funded | `DofNonDofFlag` | Computed | CASE WHEN PRCTR LIKE 'N%' THEN 'Non-DoF Funded' ELSE 'DoF Funded' |
| 7 | Profit Center/Cost Center | `ProfitCenterCode` | Attribute | ACDOCA.PRCTR |
| 8 | Internal Order | `InternalOrderCode` | Attribute | ACDOCA.AUFNR |
| 9 | Revenue GL | `RevenueGL` | Attribute | ACDOCA.RACCT *(no derivation in spec; placeholder)* |
| 10 | Related Party Entity | `RelatedPartyFlag` | Computed | CASE WHEN KNA1.KTOKD='ZRPC' THEN 'Yes' ELSE 'No' |
| 11 | Payment Terms (Days) | `PaymentTermsDays` | Attribute | T052.ZTAG1 (from KNB1.ZTERM) |

### Amount Billed without VAT (12–25)

All use **RLDNR = '0L', BLART IN ('DR','DG','RV'), KTOSL = '' (exclude tax)**

| Col # | Output Label | CDS Measure | Time Filter |
|----|----|----|----|
| 12 | Amount Billed as of 31.12.24 without VAT | `AmountBilledYTD_NoVAT` | GJAHR < P_FiscalYear |
| 13 | Amount Billed Jan-25 without VAT | `AmountBilledJan_NoVAT` | GJAHR=P_FiscalYear, POPER='01' |
| 14 | Amount Billed Feb-25 without VAT | `AmountBilledFeb_NoVAT` | GJAHR=P_FiscalYear, POPER='02' |
| 15 | Amount Billed Mar-25 without VAT | `AmountBilledMar_NoVAT` | GJAHR=P_FiscalYear, POPER='03' |
| 16 | Amount Billed Apr-25 without VAT | `AmountBilledApr_NoVAT` | GJAHR=P_FiscalYear, POPER='04' |
| 17 | Amount Billed May-25 without VAT | `AmountBilledMay_NoVAT` | GJAHR=P_FiscalYear, POPER='05' |
| 18 | Amount Billed Jun-25 without VAT | `AmountBilledJun_NoVAT` | GJAHR=P_FiscalYear, POPER='06' |
| 19 | Amount Billed Jul-25 without VAT | `AmountBilledJul_NoVAT` | GJAHR=P_FiscalYear, POPER='07' |
| 20 | Amount Billed Aug-25 without VAT | `AmountBilledAug_NoVAT` | GJAHR=P_FiscalYear, POPER='08' |
| 21 | Amount Billed Sep-25 without VAT | `AmountBilledSep_NoVAT` | GJAHR=P_FiscalYear, POPER='09' |
| 22 | Amount Billed Oct-25 without VAT | `AmountBilledOct_NoVAT` | GJAHR=P_FiscalYear, POPER='10' |
| 23 | Amount Billed Nov-25 without VAT | `AmountBilledNov_NoVAT` | GJAHR=P_FiscalYear, POPER='11' |
| 24 | Amount Billed Dec-25 without VAT | `AmountBilledDec_NoVAT` | GJAHR=P_FiscalYear, POPER='12' |
| 25 | Amount Billed 2025 without VAT | `AmountBilledYear_NoVAT` | GJAHR=P_FiscalYear (all periods) |

### Amount Billed with VAT (26–39)

All use **RLDNR = '0L', BLART IN ('DR','DG','RV'), KTOSL IN ('','MWS')** (include tax)

| Col # | Output Label | CDS Measure | Time Filter |
|----|----|----|----|
| 26 | Amount Billed as of 31.12.24 with VAT | `AmountBilledYTD_WithVAT` | GJAHR < P_FiscalYear |
| 27 | Amount Billed Jan-25 with VAT | `AmountBilledJan_WithVAT` | GJAHR=P_FiscalYear, POPER='01' |
| 28 | Amount Billed Feb-25 with VAT | `AmountBilledFeb_WithVAT` | GJAHR=P_FiscalYear, POPER='02' |
| 29 | Amount Billed Mar-25 with VAT | `AmountBilledMar_WithVAT` | GJAHR=P_FiscalYear, POPER='03' |
| 30 | Amount Billed Apr-25 with VAT | `AmountBilledApr_WithVAT` | GJAHR=P_FiscalYear, POPER='04' |
| 31 | Amount Billed May-25 with VAT | `AmountBilledMay_WithVAT` | GJAHR=P_FiscalYear, POPER='05' |
| 32 | Amount Billed Jun-25 with VAT | `AmountBilledJun_WithVAT` | GJAHR=P_FiscalYear, POPER='06' |
| 33 | Amount Billed Jul-25 with VAT | `AmountBilledJul_WithVAT` | GJAHR=P_FiscalYear, POPER='07' |
| 34 | Amount Billed Aug-25 with VAT | `AmountBilledAug_WithVAT` | GJAHR=P_FiscalYear, POPER='08' |
| 35 | Amount Billed Sep-25 with VAT | `AmountBilledSep_WithVAT` | GJAHR=P_FiscalYear, POPER='09' |
| 36 | Amount Billed Oct-25 with VAT | `AmountBilledOct_WithVAT` | GJAHR=P_FiscalYear, POPER='10' |
| 37 | Amount Billed Nov-25 with VAT | `AmountBilledNov_WithVAT` | GJAHR=P_FiscalYear, POPER='11' |
| 38 | Amount Billed Dec-25 with VAT | `AmountBilledDec_WithVAT` | GJAHR=P_FiscalYear, POPER='12' |
| 39 | Amount Billed 2025 with VAT | `AmountBilledYear_WithVAT` | GJAHR=P_FiscalYear (all periods) |

### Amount Collected with VAT (40–53)

All use **RLDNR = '0L', BLART IN ('DZ','Z4'), DRCRK = 'S'** (credit amount only)

| Col # | Output Label | CDS Measure | Time Filter |
|----|----|----|----|
| 40 | Amount Collected as of 31.12.24 with VAT | `AmountCollectedYTD_WithVAT` | GJAHR < P_FiscalYear |
| 41 | Amount Collected Jan-25 with VAT | `AmountCollectedJan_WithVAT` | GJAHR=P_FiscalYear, POPER='01' |
| 42 | Amount Collected Feb-25 with VAT | `AmountCollectedFeb_WithVAT` | GJAHR=P_FiscalYear, POPER='02' |
| 43 | Amount Collected Mar-25 with VAT | `AmountCollectedMar_WithVAT` | GJAHR=P_FiscalYear, POPER='03' |
| 44 | Amount Collected Apr-25 with VAT | `AmountCollectedApr_WithVAT` | GJAHR=P_FiscalYear, POPER='04' |
| 45 | Amount Collected May-25 with VAT | `AmountCollectedMay_WithVAT` | GJAHR=P_FiscalYear, POPER='05' |
| 46 | Amount Collected Jun-25 with VAT | `AmountCollectedJun_WithVAT` | GJAHR=P_FiscalYear, POPER='06' |
| 47 | Amount Collected Jul-25 with VAT | `AmountCollectedJul_WithVAT` | GJAHR=P_FiscalYear, POPER='07' |
| 48 | Amount Collected Aug-25 with VAT | `AmountCollectedAug_WithVAT` | GJAHR=P_FiscalYear, POPER='08' |
| 49 | Amount Collected Sep-25 with VAT | `AmountCollectedSep_WithVAT` | GJAHR=P_FiscalYear, POPER='09' |
| 50 | Amount Collected Oct-25 with VAT | `AmountCollectedOct_WithVAT` | GJAHR=P_FiscalYear, POPER='10' |
| 51 | Amount Collected Nov-25 with VAT | `AmountCollectedNov_WithVAT` | GJAHR=P_FiscalYear, POPER='11' |
| 52 | Amount Collected Dec-25 with VAT | `AmountCollectedDec_WithVAT` | GJAHR=P_FiscalYear, POPER='12' |
| 53 | Amount Collected 2025 with VAT | `AmountCollectedYear_WithVAT` | GJAHR=P_FiscalYear (all periods) |

---

## Measure Logic Details

### Grouping

All aggregates are grouped by:
- RBUKRS (Company Code)
- KUNNR (Customer)
- PRCTR (Profit Center)
- AUFNR (Internal Order)

### Base Filters (common to all measures)

- **RLDNR = '0L'** — Ledger: Accounting Index (Financial GL)
- **Language:** T005T, CEPCT filtered by SPRAS = 'E'

### Amount Billed Measures

**Document Type:** DR (Invoice), DG (Debit Memo), RV (Billing Document)

- **Without VAT:** `KTOSL = ''` (exclude tax line items)
- **With VAT:** `KTOSL IN ('', 'MWS')` (include both regular and tax lines; MWS is the standard German VAT code)

### Amount Collected Measures

**Document Type:** DZ (Payment), Z4 (Clearing document)

- **Credit Direction Only:** `DRCRK = 'S'` (credit debit/credit indicator)
- **All include VAT** (amounts in collected documents already net VAT treatment)

### Time Aggregation

- **Cumulative "as of 31.12.(Year-1)":** `GJAHR < P_FiscalYear`
- **Single Month:** `GJAHR = P_FiscalYear AND POPER = nn`
- **Annual Total:** `GJAHR = P_FiscalYear` (all POPER values summed)

### Currency

All measures use `ACDOCA.HSL` (company-code / local currency, company code-specific). Future: add `@Semantics.currencyCode: WAERS` association if needed.

---

## Joins and Master Data

| Dictionary Table | Key Join | Purpose | Fields Used |
|---|---|---|---|
| T001 | RBUKRS = BUKRS | Company Code → Text | BUTXT (Entity) |
| KNA1 | KUNNR = KUNNR | Customer → Names & Flags | NAME1 (Customer Name), ADRNR (Address key), KTOKD (Acct Type for Related-Party check) |
| ADRC | ADRNR = ADDRNUMBER | Customer Address | CITY1 (City), COUNTRY (Country Code) |
| T005T | COUNTRY = LAND1, SPRAS='E' | Country Code → Text (English) | LANDX50 (Country Name) |
| CEPCT | PRCTR = PRCTR, SPRAS='E' | Profit Center → Text (English) | LTEXT (Research Center) |
| KNB1 | (BUKRS, KUNNR) = (BUKRS, KUNNR) | Customer by Company → Payment Terms | ZTERM (Payment Terms Code) |
| T052 | ZTERM = ZTERM | Payment Terms → Days | ZTAG1 (Days) |

**Null Safety:** All joins are LEFT OUTER JOIN to preserve revenue lines even if customer/address master data is missing.

---

## Special Notes

### 1. Column 9: Revenue GL
The specification does not provide a derivation for "Revenue GL" (output col 9). Currently exposed as placeholder `ACDOCA.RACCT` (GL account code). **Business clarification required** on whether this should be:
- A fixed value per Profit Center?
- A lookup from another table?
- Derived from ACDOCA join logic?

### 2. Profit Center Text Source
The spec says "CEPC-LTEXT" → we use **CEPCT** (the language-dependent table for profit center texts), not CEPC (master data only). CEPCT is standard SAP; it holds the long texts per profit center and language.

### 3. Period Labels
Month labels (Jan-25, Feb-25, etc.) are hard-coded in the output column labels for 2025. The underlying logic works for any fiscal year via the `P_FiscalYear` parameter:
- If P_FiscalYear = 2026, POPER='01' means January 2026.
- Labels should be dynamically adjusted in a Fiori app or reporting tool based on the parameter value.

### 4. VAT Handling
- **KTOSL = 'MWS'** is the SAP-standard posting key for VAT (Mehrwertsteuer) in Germany. Adjust for other countries if needed.
- Documents may have multiple line items: regular posting + VAT posting. KTOSL='MWS' identifies the tax line.

### 5. Cumulative as of 31.12.(Year-1)
All "as of 31.12.24" measures compare against `P_FiscalYear`:
- If P_FiscalYear = 2025, then `GJAHR < 2025` means all documents through 2024.
- If P_FiscalYear = 2026, then `GJAHR < 2026` means all documents through 2025.

This design allows the report to be year-independent and reusable.

---

## Installation & Activation

### Prerequisites
- S/4HANA on-premise system (2020 or later recommended)
- abapGit installed and configured
- ABAP development authorizations

### Steps
1. Clone this repository via abapGit:
   - Create a new abapGit repo in your system.
   - Enter this repo URL and the target package `ZFI_NSD`.
   - Pull the repo.

2. Activate all objects in order:
   - `package.devc` (package)
   - `zfi_nsd_i_billing_cube.ddls` (cube view)
   - `zfi_nsd_c_nonsd_billing.ddls` (query view)
   - `zfi_nsd_ui_nonsd_billing.srvd` (service definition)
   - `zfi_nsd_ui_nonsd_billing.srvb` (service binding)

3. Test the OData endpoint:
   - Go to **Manage Service Bindings** (SODATA_EXPLORE or similar).
   - Find `ZFI_NSD_UI_NONSD_BILLING` (OData V4).
   - Click the URL to test metadata and simple queries.

4. Test data retrieval:
   - Call `/odata/v4/zfi_nsd_ui_nonsd_billing/NonSdBilling` with filters and the `P_FiscalYear` parameter.
   - Example: `?$filter=CompanyCode eq '1000' and P_FiscalYear='2025'`

---

## Testing Checklist

- [ ] All objects activate without syntax errors.
- [ ] Service binding OData metadata is valid (no TYPE MISSING or view references).
- [ ] Test query with valid Company Code (mandatory parameter) and Fiscal Year.
- [ ] Verify 53 columns are present and labeled correctly.
- [ ] Spot-check amounts against ACDOCA base data (manual query or SE16).
- [ ] Test filters: by Customer, Profit Center, Internal Order (optional).
- [ ] Verify "as of 31.12.24" measure (GJAHR < param) vs. monthly aggregates.
- [ ] Validate DoF/Non-DoF flag logic (PRCTR starts with 'N'?).
- [ ] Confirm Related-Party flag (KTOKD='ZRPC'?).

---

## Support & Maintenance

**Questions or Issues:**
- Review the specification in `NONSD_po.xlsx` for exact business logic.
- Check SAP table documentation (SE11) for field definitions.
- Verify that joins target the correct tables (especially CEPCT vs CEPC).

**Future Enhancements:**
- Add authorizations (PFCG) and data-level security (DCL).
- Optimize performance with appropriate database indexes on ACDOCA.
- Add Fiori UI annotations for analytical UI.
- Implement unit tests for key measure definitions.

---

## Document History

| Date | Version | Author | Changes |
|---|---|---|---|
| 2026-05-21 | 0001 | rishabh.sharma@diligentglobal.com | Initial framework; pure CDS analytical model with flat merged-joins architecture. All 53 output columns defined. |

---

## Appendix: CDS Syntax Notes

### Key Annotations

- `@Analytics.dataCategory: #CUBE` — Marks the aggregation layer.
- `@Analytics.query: true` — Marks the OData consumption layer.
- `@Consumption.filter.mandatory: true` — Selection parameter is required.
- `@Semantics.amount.currencyCode: 'CURRENCY'` — Identifies numeric measures (currency conversion-aware).
- `@EndUserText.label: '...'` — User-facing label (displayed in tools like Analysis for Office).

### Measure Definition (SUM/CASE Pattern)

All measures follow this pattern:
```abap
sum(
  case
    when <time_filter> and <doc_filter> and <field_filter>
    then hsl
    else 0
  end
) as <MeasureName>
```

This ensures:
- Null/missing document types sum to 0 (not null).
- Time-based filtering is encapsulated in the measure (not the WHERE clause).
- Grouping is implicit in the GROUP BY clause.

---

**End of README**
