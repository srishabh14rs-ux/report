# Technical Specification: Non-SD Billing & Collection Report (ZFI_NSD)

**Document Version:** 1.0  
**Date Created:** 2026-06-05  
**Author:** rishabh.sharma@diligentglobal.com  
**Status:** Draft  
**Classification:** Internal

---

## 1. Executive Summary

This Technical Specification outlines the complete architectural design, data models, integration points, and implementation details for the **Non-SD (non-Sales & Distribution) Billing & Collection Report** system in SAP S/4HANA. The system leverages SAP's Core Data Services (CDS) analytical framework to provide real-time aggregated billing, collection, and receivables data without requiring periodic batch runs.

**Key Characteristics:**
- Pure CDS analytical model (no external ABAP logic classes)
- Flat merged-joins architecture for optimal query performance
- OData V4 consumption layer for UI/reporting tools
- Multi-currency support via company-code ledger (HSL)
- Time-independent parametric design (fiscal year as parameter)

---

## 2. System Objectives

### 2.1 Primary Objectives
1. **Centralized Billing Data:** Aggregate billing and collection transactions from ACDOCA (Universal Journal) enriched with master data
2. **Real-Time Reporting:** Enable on-demand reporting without batch dependencies
3. **Flexible Filtering:** Support filtering by Company Code, Customer, Profit Center, and Internal Order
4. **53-Column Output:** Standardized output format with all required financial metrics
5. **Compliance:** Support DoF/Non-DoF tracking, Related-Party flagging, and Payment Terms visibility

### 2.2 Business Scope
- **Entity Coverage:** All company codes and customers within the financial ledger (RLDNR = '0L')
- **Transaction Types:**
  - Billing documents: DR (Invoices), DG (Debit Memos), RV (Billing documents)
  - Collections: DZ (Payments), Z4 (Clearing documents)
- **Time Range:** Current fiscal year + historical "as of" year-end snapshots
- **Currency:** Company-code local currency (HSL from ACDOCA)

---

## 3. Functional Requirements

### 3.1 Report Output Structure (53 Columns)

#### 3.1.1 Master Data Attributes (Columns 1–11)

| # | Field Name | Source Table | Business Logic | Mandatory |
|---|---|---|---|---|
| 1 | Entity | T001 | Company code description (BUTXT) | Yes |
| 2 | Customer Name | KNA1 | Customer name (NAME1) | Yes |
| 3 | City | ADRC | Customer city (CITY1) from primary address | Yes |
| 4 | Country | T005T | Country name in English; filter SPRAS='E' | Yes |
| 5 | Research Center | CEPCT | Profit center long text in English; filter SPRAS='E' | Yes |
| 6 | DoF/Non-DoF Flag | CASE logic | Profit center prefix: 'N%' = Non-DoF, else DoF Funded | Yes |
| 7 | Profit Center Code | ACDOCA | Profit center GL posting (PRCTR) | No |
| 8 | Internal Order | ACDOCA | Internal order (AUFNR) | No |
| 9 | Revenue GL | ACDOCA | GL account code (RACCT); *see note 3.1.9* | No |
| 10 | Related Party Flag | CASE logic | Customer account type: KTOKD='ZRPC' → 'Yes', else 'No' | No |
| 11 | Payment Terms (Days) | T052 | Payment terms days (ZTAG1) from KNB1.ZTERM lookup | No |

#### 3.1.2 Amount Billed without VAT (Columns 12–25)

All measures apply filters:
- **Document Type:** DR, DG, RV
- **Tax Indicator:** KTOSL = '' (exclude tax line items)
- **Ledger:** RLDNR = '0L'

| # | Column Name | Time Filter | Formula |
|---|---|---|---|
| 12 | Amount Billed as of 31.12.24 without VAT | GJAHR < P_FiscalYear | SUM(HSL) |
| 13–24 | Amount Billed [Month]-25 without VAT | GJAHR=P_FiscalYear, POPER='01'–'12' | SUM(HSL) per month |
| 25 | Amount Billed 2025 without VAT | GJAHR=P_FiscalYear (all POPER) | SUM(HSL) annual |

#### 3.1.3 Amount Billed with VAT (Columns 26–39)

All measures apply filters:
- **Document Type:** DR, DG, RV
- **Tax Indicator:** KTOSL IN ('', 'MWS') (include tax)
- **Ledger:** RLDNR = '0L'

| # | Column Name | Time Filter | Formula |
|---|---|---|---|
| 26 | Amount Billed as of 31.12.24 with VAT | GJAHR < P_FiscalYear | SUM(HSL) |
| 27–38 | Amount Billed [Month]-25 with VAT | GJAHR=P_FiscalYear, POPER='01'–'12' | SUM(HSL) per month |
| 39 | Amount Billed 2025 with VAT | GJAHR=P_FiscalYear (all POPER) | SUM(HSL) annual |

#### 3.1.4 Amount Collected with VAT (Columns 40–53)

All measures apply filters:
- **Document Type:** DZ, Z4
- **Direction:** DRCRK = 'S' (credit entries only)
- **Ledger:** RLDNR = '0L'

| # | Column Name | Time Filter | Formula |
|---|---|---|---|
| 40 | Amount Collected as of 31.12.24 with VAT | GJAHR < P_FiscalYear | SUM(HSL) |
| 41–52 | Amount Collected [Month]-25 with VAT | GJAHR=P_FiscalYear, POPER='01'–'12' | SUM(HSL) per month |
| 53 | Amount Collected 2025 with VAT | GJAHR=P_FiscalYear (all POPER) | SUM(HSL) annual |

### 3.2 Input Parameters & Filters

#### 3.2.1 Mandatory Parameters
- **Company Code (BUKRS):** Filter on ACDOCA.RBUKRS; User must specify at least one company code
- **Fiscal Year (P_FiscalYear):** CDS parameter (ABAP numeric, 4 digits); controls "as of" year boundary

#### 3.2.2 Optional Selection Filters
- **Customer (KUNNR):** Single or multiple customer selection
- **Profit Center (PRCTR):** Single or multiple profit center codes
- **Internal Order (AUFNR):** Single or multiple internal order codes

#### 3.2.3 Non-Exposed Parameters
- **Period (POPER):** Implicit in measure definitions; not exposed for direct selection (period selection via measure choice in consuming UI)

### 3.3 Data Aggregation & Grouping

All measures are grouped by:
```
Group By: RBUKRS, KUNNR, PRCTR, AUFNR
```

This ensures one row per unique company-customer-profit-center-order combination.

---

## 4. Technical Architecture

### 4.1 System Landscape

```
┌─────────────────────────────────────────────────────┐
│  SAP S/4HANA On-Premise (2020 or later)            │
├─────────────────────────────────────────────────────┤
│  CDS Framework Layer                                │
│  ├─ ZFI_NSD_I_Billing_Cube      (CUBE view)        │
│  │   └─ Core aggregation + 8 table joins             │
│  └─ ZFI_NSD_C_NonSdBilling      (QUERY view)        │
│      └─ Consumption + OData annotations              │
├─────────────────────────────────────────────────────┤
│  Service Layer (RAP)                                │
│  ├─ Service Definition (zfi_nsd_ui_nonsd_billing)  │
│  └─ Service Binding (OData V4)                      │
├─────────────────────────────────────────────────────┤
│  Consumption Layer                                  │
│  ├─ Fiori Analytics Apps                           │
│  ├─ SAP Analytics Cloud                            │
│  ├─ Analysis for Office (Excel)                    │
│  └─ Custom Web Applications (REST via OData)       │
└─────────────────────────────────────────────────────┘
```

### 4.2 CDS Layer Architecture

#### 4.2.1 CUBE View: `ZFI_NSD_I_Billing_Cube`

**Purpose:** Core aggregation layer; contains all joins, filtering, and measure definitions.

**Key Characteristics:**
- Annotation: `@Analytics.dataCategory: #CUBE`
- Source: ACDOCA (Universal Journal) with 8 LEFT OUTER JOINs
- Filter: RLDNR = '0L' (Financial GL only)
- Grouping: RBUKRS, KUNNR, PRCTR, AUFNR
- Measures: 42 aggregated columns (SUM/CASE pattern)

**Join Details:**

| Join # | Table | Key Condition | Cardinality | Purpose |
|---|---|---|---|---|
| 1 | T001 | RBUKRS = BUKRS | 1:1 | Company code text |
| 2 | KNA1 | KUNNR = KUNNR | 1:1 | Customer master, account type, address link |
| 3 | ADRC | KNA1.ADRNR = ADDRNUMBER | 1:1 | Customer primary address (city, country) |
| 4 | T005T | ADRC.COUNTRY = LAND1, SPRAS='E' | 1:1 | Country name (English) |
| 5 | CEPCT | PRCTR = PRCTR, SPRAS='E' | 1:1 | Profit center long text (English) |
| 6 | KNB1 | (RBUKRS, KUNNR) = (BUKRS, KUNNR) | 1:1 | Customer by company (payment terms link) |
| 7 | T052 | KNB1.ZTERM = ZTERM | 1:1 | Payment terms → days |
| 8 | T005T (2nd) | *Optional; reserved for future currency code expansion* | — | — |

All joins use **LEFT OUTER JOIN** to preserve ACDOCA rows even if master data is missing.

**Measure Pattern (SUM/CASE):**

```abap
sum(
  case
    when <time_condition> and <document_type> and <field_condition>
    then hsl
    else 0
  end
) as <MeasureName>
```

Example (Amount Billed Jan without VAT):
```abap
sum(
  case
    when gjahr = $parameters.P_FiscalYear
      and poper = '01'
      and blart in ('DR', 'DG', 'RV')
      and ktosl = ''
    then hsl
    else 0
  end
) as AmountBilledJan_NoVAT
```

#### 4.2.2 QUERY View: `ZFI_NSD_C_NonSdBilling`

**Purpose:** Consumption layer; exposes CUBE via OData with user-friendly labels and filters.

**Key Characteristics:**
- Annotation: `@Analytics.query: true`
- Selects from: ZFI_NSD_I_Billing_Cube
- Filters: Company Code (mandatory), Customer, Profit Center, Internal Order (all optional)
- Parameters: P_FiscalYear (4-digit numeric)
- Labels: All 53 columns labeled in English
- Semantics: Measures marked with `@Semantics.amount.currencyCode: 'CURRENCY'`

**Selection Filter Annotations:**

```abap
@Consumption.filter.mandatory: true
CompanyCode: RBUKRS,

@Consumption.filter.hidden: false
Customer: KUNNR,

@Consumption.filter.hidden: false
ProfitCenter: PRCTR,

@Consumption.filter.hidden: false
InternalOrder: AUFNR
```

### 4.3 Service Layer (RAP)

#### 4.3.1 Service Definition: `zfi_nsd_ui_nonsd_billing.srvd`

**Purpose:** Defines the OData service contract; exposes the QUERY view as an entity set.

**Structure:**
```abap
service {
  expose ZFI_NSD_C_NonSdBilling as NonSdBilling;
}
```

**Entity Set Name:** `NonSdBilling`  
**Key Elements:** Implicit (row identity derived from RBUKRS + KUNNR + PRCTR + AUFNR)

#### 4.3.2 Service Binding: `zfi_nsd_ui_nonsd_billing.srvb.xml`

**Purpose:** Binds the service to OData V4 protocol and configures UI metadata.

**Configuration:**
- **Protocol:** OData V4
- **Service:** ZFI_NSD_UI_NONSD_BILLING (from service definition)
- **URI Path:** `/odata/v4/zfi_nsd_ui_nonsd_billing`

**Endpoint Example:**
```
GET /odata/v4/zfi_nsd_ui_nonsd_billing/NonSdBilling
    ?$filter=CompanyCode eq '1000' and Customer eq '0000001234'
    &P_FiscalYear='2025'
```

### 4.4 Data Flow

```
┌─────────────────────────────────────────────────────┐
│ SAP S/4HANA Database                               │
│ ├─ ACDOCA (Facts: 500M+ rows)                       │
│ ├─ T001, KNA1, ADRC, T005T, CEPCT, KNB1, T052      │
│ │  (Master data reference tables)                    │
└─────────────────────────────────────────────────────┘
            ↓ (LEFT OUTER JOINs in CDS)
┌─────────────────────────────────────────────────────┐
│ ZFI_NSD_I_Billing_Cube (CUBE View)                 │
│ ├─ Filters: RLDNR='0L'                              │
│ ├─ Groups By: RBUKRS, KUNNR, PRCTR, AUFNR          │
│ └─ Measures: 42 aggregates (SUM/CASE)               │
└─────────────────────────────────────────────────────┘
            ↓ (Alias/relabel)
┌─────────────────────────────────────────────────────┐
│ ZFI_NSD_C_NonSdBilling (QUERY View)                │
│ ├─ Selection Filters (Company, Customer, etc.)     │
│ ├─ Parameters (P_FiscalYear)                        │
│ └─ OData Annotations (labels, semantics)            │
└─────────────────────────────────────────────────────┘
            ↓ (OData V4 protocol)
┌─────────────────────────────────────────────────────┐
│ Consumers                                           │
│ ├─ Fiori Analytics App                             │
│ ├─ Analysis for Office                             │
│ ├─ SAP Analytics Cloud                             │
│ └─ REST clients (custom apps)                       │
└─────────────────────────────────────────────────────┘
```

---

## 5. Data Model & Semantics

### 5.1 Core Entity Model

**Primary Entity: NonSdBilling**

```
NonSdBilling {
  Key RBUKRS        : abap.char(4)      // Company Code
  Key KUNNR         : abap.char(10)     // Customer
  Key PRCTR         : abap.char(10)     // Profit Center
  Key AUFNR         : abap.char(12)     // Internal Order

  // Attributes
  Entity            : abap.string       // T001.BUTXT
  CustomerName      : abap.string       // KNA1.NAME1
  City              : abap.string       // ADRC.CITY1
  Country           : abap.string       // T005T.LANDX50
  ResearchCenter    : abap.string       // CEPCT.LTEXT
  DofNonDofFlag     : abap.string       // Computed CASE
  ProfitCenterCode  : abap.char(10)     // PRCTR
  InternalOrderCode : abap.char(12)     // AUFNR
  RevenueGL         : abap.char(10)     // RACCT
  RelatedPartyFlag  : abap.string       // Computed CASE
  PaymentTermsDays  : abap.numc(3)      // T052.ZTAG1

  // Measures (42 total: 14 columns × 3 measure types)
  AmountBilledYTD_NoVAT      : abap.curr(19,2) // HSL sum
  AmountBilledJan_NoVAT      : abap.curr(19,2)
  AmountBilledFeb_NoVAT      : abap.curr(19,2)
  // ... 10 more monthly measures
  AmountBilledYear_NoVAT     : abap.curr(19,2)

  AmountBilledYTD_WithVAT    : abap.curr(19,2) // HSL sum with MWS
  AmountBilledJan_WithVAT    : abap.curr(19,2)
  // ... 12 more monthly measures
  AmountBilledYear_WithVAT   : abap.curr(19,2)

  AmountCollectedYTD_WithVAT : abap.curr(19,2) // Payment docs, credit only
  AmountCollectedJan_WithVAT : abap.curr(19,2)
  // ... 12 more monthly measures
  AmountCollectedYear_WithVAT: abap.curr(19,2)
}
```

### 5.2 Currency & Decimals

- **Currency Field:** Company-code local currency (HSL, implicit from ACDOCA)
- **Decimal Places:** 2 (standard SAP monetary precision)
- **Type:** `abap.curr(19,2)` with semantics annotation for currency code

### 5.3 Time Dimension

**Time Aggregation Strategy:**

| Measure Type | Time Filter | Use Case |
|---|---|---|
| YTD (Year-To-Date) | GJAHR < P_FiscalYear | Historical snapshot (e.g., "as of 31.12.2024") |
| Monthly | GJAHR = P_FiscalYear, POPER = 'nn' | Period-specific analysis |
| Annual | GJAHR = P_FiscalYear (all POPER) | Fiscal year total |

**Parameter Design (P_FiscalYear):**
- Type: ABAP numeric (4 digits)
- Purpose: Dynamically control year boundary
- Example: If P_FiscalYear = 2025, then:
  - YTD = all documents with GJAHR < 2025 (i.e., 2024 and earlier)
  - Monthly = documents with GJAHR = 2025 and specific POPER
  - Annual = documents with GJAHR = 2025 (sum all periods)

---

## 6. Non-Functional Requirements

### 6.1 Performance Requirements

| Requirement | Target | Notes |
|---|---|---|
| Single-Company Query | < 2 seconds | 10 filters (customer, profit center, order) applied |
| Multi-Company Query | < 5 seconds | Up to 5 company codes |
| Result Set Size | ≤ 10,000 rows | Per query; configurable at runtime |
| Metadata Load | < 500 ms | OData $metadata endpoint |
| Parallel Requests | ≥ 10 concurrent | System should handle multiple simultaneous users |

**Performance Optimization Techniques:**
- CDS CUBE view native grouping (processed at DB layer, not application layer)
- LEFT OUTER JOINs on indexed master-data tables
- Selective projection (only required columns fetched)
- Parameter-based filtering (P_FiscalYear reduces ACDOCA scan scope)

### 6.2 Scalability

- **Expected Data Volume:** ACDOCA contains 500M+ rows; CUBE aggregation reduces to millions of fact rows (company-customer-profit-center-order combinations)
- **Horizontal Growth:** Time-independent design allows report reuse across multiple fiscal years
- **User Concurrency:** OData service should support 50+ concurrent analytical users (estimate; adjust per SAP system capacity planning)

### 6.3 Availability

- **Service Level:** 99.5% uptime during business hours
- **Backup & Recovery:** Inherited from SAP system backup strategy (no external state)
- **Disaster Recovery:** RTO/RPO inherited from S/4HANA infrastructure

### 6.4 Security

#### 6.4.1 Data-Level Security (Planned)

Future enhancements:
- **Field-Level Authorization:** Via SAP DCL (Data Control Language) — restrict by company code, profit center
- **User Filtering:** Implicit company-code filter based on user's BUKRS authorization
- **Read-Only Access:** Query layer grants no INSERT/UPDATE/DELETE permissions

#### 6.4.2 Application-Level Security

- **OData Protocol Security:** TLS 1.2+ for all transmissions
- **Authentication:** SAP user authentication (inherits from SAP system)
- **Authorization:** Profile-based via PFCG roles (e.g., `ZFI_NSD_VIEWER`, `ZFI_NSD_ADMIN`)
- **Audit Logging:** OData requests logged via SAP audit trail (CDCLS/CDHDR)

#### 6.4.3 Data Privacy

- Compliant with SAP's standard data-access logging
- No PII-specific masking in base model (customer names exposed; apply UI-level redaction if needed)
- GDPR: Right to erasure requires ACDOCA historical record preservation (business-critical); coordinate with legal/compliance

### 6.5 Data Quality & Integrity

| Aspect | Approach |
|---|---|
| Null Handling | LEFT OUTER JOIN preserves non-matching rows; aggregate sums include 0 (not NULL) |
| Duplicate Prevention | Implicit via GROUP BY key (RBUKRS, KUNNR, PRCTR, AUFNR) |
| Data Consistency | Read-only aggregation from single source of truth (ACDOCA) |
| Reconciliation | Manual spot-check: compare OData result vs. SE16 ACDOCA query with same filters |

---

## 7. Integration Points

### 7.1 Data Source Integration

**Primary Source:** ACDOCA (Universal Journal)
- **Frequency:** Real-time (no ETL; CDS queries live data)
- **Integration Type:** Direct SQL read (CDS native)
- **Dependencies:** ACDOCA must be populated by all posting modules (FI, MM, SD, etc.)

**Master Data Integration:**
- T001, KNA1, ADRC, T005T, CEPCT, KNB1, T052 maintained via standard SAP transactions
- No custom synchronization required

### 7.2 Consumption Integrations

#### 7.2.1 Fiori Analytical App

**Integration Type:** Native SAP CDS Fiori consumption
- **Protocol:** OData V4
- **App Type:** Analytical Tile
- **Tile Size:** Configurable (1×1, 1×2, 2×1, 2×2)
- **Drilldown:** Via embedded Fiori Analytics UI (Analytical List Page)

#### 7.2.2 Analysis for Office

**Integration Type:** OData feed into Excel pivot tables
- **Protocol:** OData V4 → Excel Data Model
- **Refresh Frequency:** Manual or automatic (configurable in workbook)
- **Data Limit:** Excel row/column limits apply (1M rows typical)

#### 7.2.3 SAP Analytics Cloud

**Integration Type:** Direct SAP Analytics Cloud connection (if cloud S/4HANA; otherwise manual OData export)
- **Model Type:** Analytical Query
- **Dimensions:** Company, Customer, Profit Center, Internal Order (all optional except Company)
- **Measures:** All 42 aggregates available for charting/analysis

#### 7.2.4 Custom REST/Web Applications

**Integration Type:** REST API (OData V4 standard)
- **Endpoint:** `/odata/v4/zfi_nsd_ui_nonsd_billing/NonSdBilling`
- **Methods:** GET (queries), OPTIONS (CORS metadata)
- **Query Language:** OData v4 filters, select, orderby

---

## 8. Configuration & Customization

### 8.1 Installation & Activation

**Steps:**

1. **Clone Repository (abapGit)**
   ```
   T-Code: ZABAPGIT or /n/abapgit
   → New Offline Repository
   → Enter repo URL
   → Select branch: main or claude/eloquent-mayer-RsWqA
   → Target Package: ZFI_NSD
   ```

2. **Activate Objects (in order)**
   ```
   CTRL+A → Activate
   Order (critical):
   1. package.devc (package)
   2. zfi_nsd_i_billing_cube.ddls (CUBE)
   3. zfi_nsd_c_nonsd_billing.ddls (QUERY)
   4. zfi_nsd_ui_nonsd_billing.srvd (Service Def)
   5. zfi_nsd_ui_nonsd_billing.srvb (Service Binding)
   ```

3. **Test OData Endpoint**
   ```
   T-Code: SODATA_EXPLORE
   → Find: ZFI_NSD_UI_NONSD_BILLING (OData V4)
   → Open URL in browser → $metadata (should validate without errors)
   ```

### 8.2 Customization Scenarios

#### 8.2.1 Add a New Measure

**Scenario:** Client requests "Outstanding Balance as of Period End"

**Steps:**
1. Open `zfi_nsd_i_billing_cube.ddls` in SE80/ADT
2. Add measure definition (SUM/CASE pattern):
   ```abap
   sum(
     case
       when blart in ('DZ', 'Z4') and drcrk = 'S'
       then hsl
       else 0
     end
   ) as OutstandingBalance_WithVAT
   ```
3. Activate CUBE view
4. Open `zfi_nsd_c_nonsd_billing.ddls`
5. Add selection with label:
   ```abap
   OutstandingBalance_WithVAT: zfi_nsd_i_billing_cube.OutstandingBalance_WithVAT,
   @EndUserText.label: 'Outstanding Balance with VAT'
   ```
6. Activate QUERY view → automatically exposed in OData

#### 8.2.2 Add a Master Data Column

**Scenario:** Client wants "Customer Segment" (from custom table ZCUST_SEGMENT)

**Steps:**
1. Open `zfi_nsd_i_billing_cube.ddls`
2. Add JOIN:
   ```abap
   left outer join zcust_segment
     on zcust_segment.kunnr = acdoca.kunnr
   ```
3. Add field selection:
   ```abap
   zcust_segment.segment as CustomerSegment,
   ```
4. Activate CUBE
5. Add to QUERY view with label
6. Activate QUERY

#### 8.2.3 Restrict by Company Code (Authorization)

**Future Enhancement (not in v1.0):**
- Use CDS DCL (Data Control Language) to apply company-code filter based on user's SAP roles
- Create file: `zfi_nsd_c_nonsd_billing.dcls`
- Define role-based access rules

### 8.3 Parameter Configuration

**Fiscal Year Parameter (P_FiscalYear):**

Passed at OData query time:
```
GET /odata/v4/zfi_nsd_ui_nonsd_billing/NonSdBilling
    ?P_FiscalYear=2025
    &$filter=CompanyCode eq '1000'
```

**Default Value:** Typically current fiscal year (hardcoded in calling app; CDS accepts any 4-digit year)

**Validation:** App-level (no CDS-level validation of year range; values of 1900–2999 supported)

---

## 9. Error Handling & Logging

### 9.1 CDS-Level Errors

| Error Scenario | Behavior | Resolution |
|---|---|---|
| Invalid Company Code | OData returns empty result set | User must provide valid BUKRS (check T001) |
| Missing ACDOCA data | Aggregates return 0 (not NULL) | Verify posting logic; check ACDOCA with SE16 |
| Join failure (master data missing) | LEFT OUTER JOIN preserves row; missing fields NULL | Acceptable; master data optional for GL posting |
| Invalid P_FiscalYear parameter | Query executes; may return empty if year out of range | Pass valid 4-digit year |

### 9.2 OData-Level Errors

| HTTP Status | Scenario | Message |
|---|---|---|
| 200 OK | Successful query | Result set returned |
| 400 Bad Request | Invalid $filter syntax | OData parser error; review filter syntax |
| 401 Unauthorized | User not authenticated | Login to SAP system |
| 403 Forbidden | User lacks PFCG role | Request ZFI_NSD_VIEWER role assignment |
| 500 Internal Server Error | Unexpected DB error | Check SAP system logs (SM21, ST22) |

### 9.3 Logging & Diagnostics

**SAP Logging:**
- **CDS Query Log:** T-Code CDQLOG (if enabled)
- **OData Trace:** T-Code ODATATEST (OData analysis tools)
- **SQL Trace:** T-Code ST05 (DB-level SQL analysis)
- **Error Log:** T-Code ST22 (ABAP runtime errors)

**Recommended Troubleshooting:**
1. Verify object activation: T-Code SE11 → Enter object name → Check "Active" checkbox
2. Check CDS dependencies: T-Code SE21 → Navigate to ZFI_NSD_I_BILLING_CUBE → Dependencies
3. Test OData manually: SODATA_EXPLORE → Execute simple queries without filters first

---

## 10. Testing & Validation

### 10.1 Unit-Level Testing

| Test Case | Expected Result | Validation |
|---|---|---|
| CUBE view activates | No syntax errors | Check SE11 activation log |
| All 42 measures return numeric | Data type abap.curr(19,2) | Inspect CDS definition |
| GROUP BY cardinality | One row per (RBUKRS, KUNNR, PRCTR, AUFNR) | SE16 CUBE view data |
| YTD filter logic | GJAHR < P_FiscalYear | Manual SQL: `select ... where gjahr < :py_year` |

### 10.2 Integration Testing

| Test Case | Setup | Expected Result | Validation |
|---|---|---|---|
| OData metadata loads | Deploy service binding | $metadata returns all 53 columns | SODATA_EXPLORE or REST client |
| Filter by Company Code | Pass valid BUKRS | Result set filtered to that company | Count rows; verify RBUKRS values |
| Filter by Customer | Pass valid KUNNR | Result set filtered to that customer | Verify KUNNR in output |
| Multi-filter query | Company + Customer + Profit Center | Intersection of all filters applied | Cross-check with manual SE16 query |
| Parameter P_FiscalYear | Pass 2024, then 2025 | Year-dependent measures change | Compare YTD measure values |

### 10.3 User Acceptance Testing (UAT)

| Scenario | Business Requirement | Validation |
|---|---|---|
| View 53-column output | All columns present with correct labels | Export to Excel; verify column headers |
| Filter by DoF/Non-DoF | Profit center prefix determines flag | Manual check: does 'N%' = Non-DoF? |
| Spot-check amounts | Billing amounts match ACDOCA | SE16: `select sum(hsl) from acdoca where ... and blart in (...)` |
| Monthly aggregation | Monthly totals = annual total | Sum Jan–Dec measures; compare to annual measure |
| Payment terms visibility | Days populated from T052 | Verify non-null ZTERM/ZTAG1 joins |

### 10.4 Performance Testing

| Test | Load | Expected | Metric |
|---|---|---|---|
| Single-company query | 1000 rows result | < 2 seconds | Response time |
| Multi-company query (5 cos.) | 5000 rows result | < 5 seconds | Response time |
| Concurrent users | 10 simultaneous OData requests | No timeouts | System CPU/memory |
| Result set pagination | Request 1000 rows via $skip/$top | Correct page returned | Pagination logic |

---

## 11. Deployment & Release Management

### 11.1 Release Checklist

- [ ] All CDS views compile without errors
- [ ] All objects activated in correct order
- [ ] OData service binding accessible (SODATA_EXPLORE)
- [ ] Metadata validation passed (no TYPE MISSING)
- [ ] Sample OData query executed successfully
- [ ] Performance benchmark met (< 5 sec for multi-company)
- [ ] UAT sign-off received
- [ ] Documentation updated (README, TS)
- [ ] Abapgit tag created (v1.0-prod)

### 11.2 Version Control

**Branch Strategy:**
- `main` — Production-ready code; protected branch
- `develop` — Integration branch for features
- `claude/eloquent-mayer-RsWqA` — Feature branch (this TS)
- `feature/*` — Individual feature branches

**Commit Naming Convention:**
```
<type>(<scope>): <description>

Types: feat, fix, docs, refactor, perf, test, chore
Scope: cube, query, service, config
Example: feat(cube): add outstanding-balance measure
```

### 11.3 Deployment Procedure

**Target Systems:**
1. **DEV (Development):** Continuous deployment from feature branches
2. **QA (Quality Assurance):** Release candidate from `develop`
3. **PROD (Production):** Release from `main` tag (after UAT approval)

**Deployment Steps:**
1. Merge feature branch → `develop` (PR review required)
2. UAT in QA system (2-week window)
3. Merge `develop` → `main` (approval required)
4. Tag `main` with version (e.g., `v1.0.0`)
5. Deploy abapGit repo to PROD using same tag
6. Activate objects in PROD package

---

## 12. Maintenance & Operations

### 12.1 Operational Runbook

**Daily Checks:**
- OData endpoint availability (Fiori Health Check tile)
- ACDOCA posting volume (sanity check; unusual spikes indicate posting errors)

**Weekly Checks:**
- CUBE view query performance (analyze slow queries via ST05)
- Master data staleness (check ACDOCA vs. KNA1/T001 consistency)

**Monthly Checks:**
- Back-up and disaster recovery test
- Review audit logs (user access patterns)
- Update documentation with known issues/workarounds

### 12.2 Known Limitations & Workarounds

| Limitation | Impact | Workaround |
|---|---|---|
| Revenue GL (Col 9) undefined | Business logic unclear; currently RACCT placeholder | Clarify with Finance; update CDS if different source required |
| No real-time VAT reversal | Collected amounts already net VAT; not separated | Accept as-is; VAT detail available in ACDOCA if needed |
| Period labels hard-coded (2025) | Labels won't change for 2026 queries | UI app must dynamically adjust labels based on P_FiscalYear parameter |
| No user-level company restriction (v1.0) | All users see all companies | Implement DCL in future release |

### 12.3 Incident Management

**Escalation Path:**
1. **Level 1 (End User):** Contact Fiori support (internal IT helpdesk)
2. **Level 2 (Application Support):** ABAP team reviews CDS logic, re-activates objects
3. **Level 3 (SAP Basis):** Check system logs (SM21, ST22); coordinate SAP support if DB/kernel issue

**Incident Resolution SLA:**
- **Severity 1 (Data Loss/Corruption):** 1-hour response, 4-hour resolution target
- **Severity 2 (Service Down):** 4-hour response, 1-day resolution target
- **Severity 3 (Performance Degradation):** 1-day response, 3-day resolution target

---

## 13. Future Enhancements & Roadmap

### Phase 2 (Q3 2026)
- [ ] **Data-Level Security (DCL):** Company-code authorization filtering
- [ ] **Performance Optimization:** Index creation recommendations (SAP basis team)
- [ ] **Additional Master Data:** Integration with CO-PA, overhead cost center
- [ ] **Advanced Analytics:** Ratio calculations (DSO, cash conversion cycle)

### Phase 3 (Q4 2026)
- [ ] **Fiori UX Redesign:** Analytical List Page with tile navigation
- [ ] **Mobile Support:** Responsive design for phone/tablet views
- [ ] **Scheduled Reporting:** Email exports on defined cadence
- [ ] **Audit Trail Enhancement:** Track all user queries (compliant with GDPR)

### Phase 4 (2027)
- [ ] **AI/ML Integration:** Anomaly detection in billing amounts
- [ ] **Predictive Collection:** Model outstanding balance by customer segment
- [ ] **Multi-Currency Reporting:** Consolidated view across different company-code currencies

---

## 14. Appendix

### 14.1 CDS Syntax Reference

**Key Annotations (used in this design):**

| Annotation | Level | Purpose |
|---|---|---|
| `@Analytics.dataCategory: #CUBE` | View | Marks aggregation layer |
| `@Analytics.query: true` | View | Marks consumption layer |
| `@EndUserText.label: '...'` | Field | User-facing label |
| `@EndUserText.tooltip: '...'` | Field | Tooltip on UI |
| `@Consumption.filter.mandatory` | Field | Selection filter required |
| `@Consumption.filter.hidden` | Field | Filter hidden/visible |
| `@Semantics.amount.currencyCode: 'CURRENCY'` | Measure | Currency semantics |
| `@Semantics.user.name` | Field | Identifies user name field |

### 14.2 SAP Table Quick Reference

| Table | Purpose | Key Fields |
|---|---|---|
| ACDOCA | Universal Journal (Facts) | RBUKRS, KUNNR, PRCTR, AUFNR, GJAHR, POPER, BLART, HSL |
| T001 | Company Code (Org) | BUKRS, BUTXT |
| KNA1 | Customer Master | KUNNR, NAME1, ADRNR, KTOKD |
| ADRC | Address | ADDRNUMBER, CITY1, COUNTRY |
| T005T | Country Text | LAND1, LANDX50, SPRAS |
| CEPCT | Profit Center Text | PRCTR, LTEXT, SPRAS |
| KNB1 | Customer by Co. | BUKRS, KUNNR, ZTERM |
| T052 | Payment Terms | ZTERM, ZTAG1 |

### 14.3 OData V4 Query Examples

**Example 1: Single Company, Single Customer**
```
GET /odata/v4/zfi_nsd_ui_nonsd_billing/NonSdBilling
    ?$select=Entity,CustomerName,AmountBilledYear_NoVAT,AmountCollectedYear_WithVAT
    &$filter=CompanyCode eq '1000' and Customer eq '0000001234'
    &P_FiscalYear=2025
```

**Example 2: All Customers in Multiple Companies**
```
GET /odata/v4/zfi_nsd_ui_nonsd_billing/NonSdBilling
    ?$filter=CompanyCode in ('1000', '2000')
    &$orderby=AmountBilledYear_NoVAT desc
    &$top=100
    &P_FiscalYear=2025
```

**Example 3: Profit Center Analysis**
```
GET /odata/v4/zfi_nsd_ui_nonsd_billing/NonSdBilling
    ?$filter=CompanyCode eq '1000' and startswith(ResearchCenter, 'Science')
    &$select=ProfitCenterCode,ResearchCenter,AmountBilledYear_NoVAT,AmountBilledYear_WithVAT
    &P_FiscalYear=2025
```

### 14.4 Document Change Log

| Date | Version | Changes | Author |
|---|---|---|---|
| 2026-06-05 | 1.0 | Initial Technical Specification | rishabh.sharma@diligentglobal.com |

---

**End of Technical Specification**
