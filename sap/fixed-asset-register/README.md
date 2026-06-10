# Fixed Asset Register Report (SAP FI-AA)

## Overview
SAP ABAP report for displaying consolidated fixed asset financial data including procurement details, asset master information, GL account postings, and all asset movement values.

## System Requirements
- **SAP System**: S/4HANA or ERP with FI-AA module
- **Program Name**: ZRFI_FIXED_ASSET_REGISTER
- **Include Files**: 
  - ZFI_FIXED_ASSET_REGISTER_TOP
  - ZFI_FIXED_ASSET_REGISTER_F01

## Features
- **29-Column ALV Grid Output** with asset-level financial data
- **Subtotals** by Company Code and Asset Class
- **Dynamic Selection Criteria** for flexible filtering
- **Depreciation Calculations** (Beginning, Period, Retirement, Ending, Book Value)
- **Asset Movement Tracking** (Opening, Additions, Impairment, Retirement, Transfer, In/Out)
- **Multi-Company Support** with currency handling

## Output Columns
| # | Column | Source | Description |
|---|--------|--------|-------------|
| 01 | Company Code | T001 | Bukrs |
| 02 | Purchase Order | ACDOCA | PO Number (Ebeln) |
| 03 | Vendor Name | LFA1 | Vendor Master Name |
| 04 | Profit Center | ANLZ | Time-dependent Profit Center |
| 05 | Original Asset | ANLA | Inventory Number (Aibn1) |
| 06 | Asset Number | ANLA | Main Asset (Anln1) |
| 07 | Sub-Asset | ANLA | Asset Sub-number (Anln2) |
| 08 | Movement Type | ANEK | First Movement (Bwasl) |
| 09 | Quantity | ANLA | Quantity (Menge) |
| 10 | Useful Life (Yr) | ANLB | Years (Ndjar) |
| 11 | Useful Life (Per) | ANLB | Periods (Ndper) |
| 12 | Dep. Start Date | ANLB | Depreciation Start (Afabg) |
| 13 | Asset Description | ANLA | Text50 |
| 14 | Currency | T001 | Waers |
| 15 | Asset Class | ANLA | Anlkl |
| 16 | Class Description | ANKT | TXK50 |
| 17 | GL Account | T095 | Ktansw |
| 18 | GL Account Desc | SKAT | Txt20 |
| 19 | Opening | ANLC | Kansw (APC) |
| 20 | Addition | ANLC/ANEP | Answl (BWASL=100 for AUC) |
| 21 | Impairment | ANEP | Sum by BWASL range (800-898, R00-R10, S01, S10) |
| 22 | Retirement | ANEP | Sum by BWASL 200-299 |
| 23 | Transfer | ANEP | BWASL=310 (for AUC assets) |
| 24 | In/Out | ANEP | BWASL=100(In) - BWASL=105(Out) |
| 25 | CIP Cost | ANLC | Kaufw |
| 26 | Total Acq Cost | Calculated | Opening + Addition + movements |
| 27 | Dep. Beginning | ANLC-1 | Previous year Nafav |
| 28 | Dep. Period | ANLC | Knafa + Nafap |
| 29 | Dep. Retirement | Calculated | Retirement depreciation |
| 30 | Dep. End | Calculated | Cumulative depreciation |
| 31 | Book Value | Calculated | Total Acq - Dep. End |

## Selection Screen Parameters
- **Company Code** (s_bukrs): Mandatory, multiple selection
- **Asset Class** (s_anlkl): Optional, multiple selection
- **Asset Number** (s_anln1): Optional, multiple selection
- **Profit Center** (s_prctr): Optional, multiple selection
- **Vendor** (s_lifnr): Optional, multiple selection
- **Purchase Order** (s_ebeln): Optional, multiple selection
- **Fiscal Year** (p_gjahr): Mandatory
- **Period From** (p_peraf): Default '001', mandatory
- **Period To** (p_perat): Default '012', mandatory
- **Depreciation Area** (p_afabe): Default '01', mandatory

## Key Tables
- **T001**: Company Code Master (Currency, Chart of Accounts)
- **ANLA**: Asset Master General (Asset Description, Class, Quantity)
- **ANLZ**: Asset Master Time-Dependent (Profit Center)
- **ANLB**: Depreciation Terms (Useful Life, Depreciation Start Date)
- **ANLC**: Asset Annual Values (Opening, Cumulative Depreciation)
- **ANEP**: Asset Line Items (Movements, Amounts, Types)
- **ANEK**: Asset Document Header (Movement Document Number)
- **ANKT**: Asset Class Description
- **SKAT**: GL Account Short Texts
- **T095**: GL Account Assignments for Asset Postings
- **ACDOCA**: Universal Journal (PO/Vendor Link in S/4HANA)
- **RBKP**: MM Invoice Header (Vendor Link)
- **LFA1**: Vendor Master

## Special Features
- **AUC Asset Handling**: Supports Construction in Progress (CIP) asset class detection via setname ZFI_AUC_CLASS
- **ALV Grid Features**: Zebra pattern, column width optimization, variant storage
- **Time-Valid Data**: Profit Center fetched with current date (BDATU >= SY-DATUM)
- **Currency-Aware Summing**: Financial fields properly formatted by currency (WAERS)

## Development Notes
- Custom field AIBN1 may replace standard INVNR if appended to ANLA
- Depreciation area (AFABE) filters all depreciation-related queries
- Previous fiscal year calculated automatically for comparative depreciation analysis
- AUC asset detection uses SAP set configuration (ZFI_AUC_CLASS setname)

## Version History
- **v1.0** (03.06.2026): Initial Development - EKX Deep Agent
