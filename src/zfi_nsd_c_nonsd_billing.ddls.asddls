@AbapCatalog.sqlViewName: 'ZFINSBQUERY'
@AbapCatalog.compiler.compareFilter: true
@EndUserText.label: 'Non-SD Billing & Collection Report'
@Analytics.query: true
define view ZFI_NSD_C_NonSdBilling
  with parameters
    P_FiscalYear : abap.numc(4)
  as select from zfi_nsd_i_billing_cube(
    P_FiscalYear: $parameters.P_FiscalYear
  )
{
  // Selection filters
  @Consumption.filter.mandatory: true
  @EndUserText.label: 'Company Code'
  CompanyCode,

  @Consumption.filter.hidden: false
  @EndUserText.label: 'Customer'
  Customer,

  @Consumption.filter.hidden: false
  @EndUserText.label: 'Profit Center'
  ProfitCenter,

  @Consumption.filter.hidden: false
  @EndUserText.label: 'Internal Order'
  InternalOrder,

  // Master data columns
  @EndUserText.label: 'Entity'
  Entity,

  @EndUserText.label: 'Customer Name'
  CustomerName,

  @EndUserText.label: 'City'
  City,

  @EndUserText.label: 'Country'
  Country,

  @EndUserText.label: 'Research Center'
  ResearchCenter,

  @EndUserText.label: 'DoF/ Non-DoF Funded'
  DofNonDofFlag,

  @EndUserText.label: 'Profit Center/Cost Center'
  ProfitCenterCode,

  @EndUserText.label: 'Internal Order'
  InternalOrderCode,

  @EndUserText.label: 'Revenue GL'
  RevenueGL,

  @EndUserText.label: 'Related Party Entity'
  RelatedPartyFlag,

  @EndUserText.label: 'Payment Terms (Days)'
  PaymentTermsDays,

  // Amount Billed (Without VAT) measures
  @EndUserText.label: 'Amount Billed as of 31.12.24 without VAT'
  AmountBilledYTD_NoVAT,

  @EndUserText.label: 'Amount Billed Jan-25 without VAT'
  AmountBilledJan_NoVAT,

  @EndUserText.label: 'Amount Billed Feb-25 without VAT'
  AmountBilledFeb_NoVAT,

  @EndUserText.label: 'Amount Billed Mar-25 without VAT'
  AmountBilledMar_NoVAT,

  @EndUserText.label: 'Amount Billed Apr-25 without VAT'
  AmountBilledApr_NoVAT,

  @EndUserText.label: 'Amount Billed May-25 without VAT'
  AmountBilledMay_NoVAT,

  @EndUserText.label: 'Amount Billed Jun-25 without VAT'
  AmountBilledJun_NoVAT,

  @EndUserText.label: 'Amount Billed Jul-25 without VAT'
  AmountBilledJul_NoVAT,

  @EndUserText.label: 'Amount Billed Aug-25 without VAT'
  AmountBilledAug_NoVAT,

  @EndUserText.label: 'Amount Billed Sep-25 without VAT'
  AmountBilledSep_NoVAT,

  @EndUserText.label: 'Amount Billed Oct-25 without VAT'
  AmountBilledOct_NoVAT,

  @EndUserText.label: 'Amount Billed Nov-25 without VAT'
  AmountBilledNov_NoVAT,

  @EndUserText.label: 'Amount Billed Dec-25 without VAT'
  AmountBilledDec_NoVAT,

  @EndUserText.label: 'Amount Billed 2025 without VAT'
  AmountBilledYear_NoVAT,

  // Amount Billed (With VAT) measures
  @EndUserText.label: 'Amount Billed as of 31.12.24 with VAT'
  AmountBilledYTD_WithVAT,

  @EndUserText.label: 'Amount Billed Jan-25 with VAT'
  AmountBilledJan_WithVAT,

  @EndUserText.label: 'Amount Billed Feb-25 with VAT'
  AmountBilledFeb_WithVAT,

  @EndUserText.label: 'Amount Billed Mar-25 with VAT'
  AmountBilledMar_WithVAT,

  @EndUserText.label: 'Amount Billed Apr-25 with VAT'
  AmountBilledApr_WithVAT,

  @EndUserText.label: 'Amount Billed May-25 with VAT'
  AmountBilledMay_WithVAT,

  @EndUserText.label: 'Amount Billed Jun-25 with VAT'
  AmountBilledJun_WithVAT,

  @EndUserText.label: 'Amount Billed Jul-25 with VAT'
  AmountBilledJul_WithVAT,

  @EndUserText.label: 'Amount Billed Aug-25 with VAT'
  AmountBilledAug_WithVAT,

  @EndUserText.label: 'Amount Billed Sep-25 with VAT'
  AmountBilledSep_WithVAT,

  @EndUserText.label: 'Amount Billed Oct-25 with VAT'
  AmountBilledOct_WithVAT,

  @EndUserText.label: 'Amount Billed Nov-25 with VAT'
  AmountBilledNov_WithVAT,

  @EndUserText.label: 'Amount Billed Dec-25 with VAT'
  AmountBilledDec_WithVAT,

  @EndUserText.label: 'Amount Billed 2025 with VAT'
  AmountBilledYear_WithVAT,

  // Amount Collected (With VAT) measures
  @EndUserText.label: 'Amount Collected as of 31.12.24 with VAT'
  AmountCollectedYTD_WithVAT,

  @EndUserText.label: 'Amount Collected Jan-25 with VAT'
  AmountCollectedJan_WithVAT,

  @EndUserText.label: 'Amount Collected Feb-25 with VAT'
  AmountCollectedFeb_WithVAT,

  @EndUserText.label: 'Amount Collected Mar-25 with VAT'
  AmountCollectedMar_WithVAT,

  @EndUserText.label: 'Amount Collected Apr-25 with VAT'
  AmountCollectedApr_WithVAT,

  @EndUserText.label: 'Amount Collected May-25 with VAT'
  AmountCollectedMay_WithVAT,

  @EndUserText.label: 'Amount Collected Jun-25 with VAT'
  AmountCollectedJun_WithVAT,

  @EndUserText.label: 'Amount Collected Jul-25 with VAT'
  AmountCollectedJul_WithVAT,

  @EndUserText.label: 'Amount Collected Aug-25 with VAT'
  AmountCollectedAug_WithVAT,

  @EndUserText.label: 'Amount Collected Sep-25 with VAT'
  AmountCollectedSep_WithVAT,

  @EndUserText.label: 'Amount Collected Oct-25 with VAT'
  AmountCollectedOct_WithVAT,

  @EndUserText.label: 'Amount Collected Nov-25 with VAT'
  AmountCollectedNov_WithVAT,

  @EndUserText.label: 'Amount Collected Dec-25 with VAT'
  AmountCollectedDec_WithVAT,

  @EndUserText.label: 'Amount Collected 2025 with VAT'
  AmountCollectedYear_WithVAT
}
