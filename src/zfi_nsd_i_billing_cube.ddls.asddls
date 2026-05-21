@AbapCatalog.sqlViewName: 'ZFINSBCUBE'
@AbapCatalog.compiler.compareFilter: true
@EndUserText.label: 'Non-SD Billing Cube (Fact)'
@Analytics.dataCategory: #CUBE
@Analytics.internalName: #DEFAULT
define view ZFI_NSD_I_Billing_Cube
  with parameters
    P_FiscalYear : abap.numc(4)
  as select from acdoca as je
    left outer join t001 on je.rbukrs = t001.bukrs
    left outer join kna1 on je.kunnr = kna1.kunnr
    left outer join adrc on kna1.adrnr = adrc.addrnumber
    left outer join t005t on adrc.country = t005t.land1 and t005t.spras = 'E'
    left outer join cepct on je.prctr = cepct.prctr and cepct.spras = 'E'
    left outer join knb1 on je.rbukrs = knb1.bukrs and je.kunnr = knb1.kunnr
    left outer join t052 on knb1.zterm = t052.zterm
{
  // Key dimensions
  key je.rbukrs as CompanyCode,
  key je.kunnr as Customer,
  key je.prctr as ProfitCenter,
  key je.aufnr as InternalOrder,

  // Master data dimensions (attributes)
  t001.butxt as Entity,
  kna1.name1 as CustomerName,
  adrc.city1 as City,
  t005t.landx50 as Country,
  cepct.ltext as ResearchCenter,
  je.prctr as ProfitCenterCode,
  je.aufnr as InternalOrderCode,
  je.racct as RevenueGL,
  knb1.zterm as PaymentTermCode,
  t052.ztag1 as PaymentTermsDays,

  // Computed columns
  case when je.prctr like 'N%' then 'Non-DoF Funded' else 'DoF Funded' end as DofNonDofFlag,
  case when kna1.ktokd = 'ZRPC' then 'Yes' else 'No' end as RelatedPartyFlag,

  // Measures: Amount Billed (Without VAT) - Cumulative as of 31.12.(Year-1)
  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed as of 31.12.24 without VAT'
  sum(
    case
      when je.gjahr < $parameters.P_FiscalYear
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl = ''
      then je.hsl else 0
    end
  ) as AmountBilledYTD_NoVAT,

  // Amount Billed (Without VAT) - Monthly measures (Jan-25 through Dec-25)
  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Jan-25 without VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '01'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl = ''
      then je.hsl else 0
    end
  ) as AmountBilledJan_NoVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Feb-25 without VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '02'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl = ''
      then je.hsl else 0
    end
  ) as AmountBilledFeb_NoVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Mar-25 without VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '03'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl = ''
      then je.hsl else 0
    end
  ) as AmountBilledMar_NoVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Apr-25 without VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '04'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl = ''
      then je.hsl else 0
    end
  ) as AmountBilledApr_NoVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed May-25 without VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '05'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl = ''
      then je.hsl else 0
    end
  ) as AmountBilledMay_NoVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Jun-25 without VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '06'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl = ''
      then je.hsl else 0
    end
  ) as AmountBilledJun_NoVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Jul-25 without VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '07'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl = ''
      then je.hsl else 0
    end
  ) as AmountBilledJul_NoVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Aug-25 without VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '08'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl = ''
      then je.hsl else 0
    end
  ) as AmountBilledAug_NoVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Sep-25 without VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '09'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl = ''
      then je.hsl else 0
    end
  ) as AmountBilledSep_NoVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Oct-25 without VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '10'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl = ''
      then je.hsl else 0
    end
  ) as AmountBilledOct_NoVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Nov-25 without VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '11'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl = ''
      then je.hsl else 0
    end
  ) as AmountBilledNov_NoVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Dec-25 without VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '12'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl = ''
      then je.hsl else 0
    end
  ) as AmountBilledDec_NoVAT,

  // Amount Billed 2025 without VAT (Annual Total)
  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed 2025 without VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl = ''
      then je.hsl else 0
    end
  ) as AmountBilledYear_NoVAT,

  // Measures: Amount Billed (With VAT) - Cumulative as of 31.12.(Year-1)
  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed as of 31.12.24 with VAT'
  sum(
    case
      when je.gjahr < $parameters.P_FiscalYear
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl in ('', 'MWS')
      then je.hsl else 0
    end
  ) as AmountBilledYTD_WithVAT,

  // Amount Billed (With VAT) - Monthly measures
  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Jan-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '01'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl in ('', 'MWS')
      then je.hsl else 0
    end
  ) as AmountBilledJan_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Feb-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '02'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl in ('', 'MWS')
      then je.hsl else 0
    end
  ) as AmountBilledFeb_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Mar-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '03'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl in ('', 'MWS')
      then je.hsl else 0
    end
  ) as AmountBilledMar_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Apr-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '04'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl in ('', 'MWS')
      then je.hsl else 0
    end
  ) as AmountBilledApr_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed May-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '05'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl in ('', 'MWS')
      then je.hsl else 0
    end
  ) as AmountBilledMay_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Jun-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '06'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl in ('', 'MWS')
      then je.hsl else 0
    end
  ) as AmountBilledJun_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Jul-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '07'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl in ('', 'MWS')
      then je.hsl else 0
    end
  ) as AmountBilledJul_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Aug-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '08'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl in ('', 'MWS')
      then je.hsl else 0
    end
  ) as AmountBilledAug_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Sep-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '09'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl in ('', 'MWS')
      then je.hsl else 0
    end
  ) as AmountBilledSep_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Oct-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '10'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl in ('', 'MWS')
      then je.hsl else 0
    end
  ) as AmountBilledOct_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Nov-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '11'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl in ('', 'MWS')
      then je.hsl else 0
    end
  ) as AmountBilledNov_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed Dec-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '12'
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl in ('', 'MWS')
      then je.hsl else 0
    end
  ) as AmountBilledDec_WithVAT,

  // Amount Billed 2025 with VAT (Annual Total)
  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Billed 2025 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.rldnr = '0L'
        and je.blart in ('DR', 'DG', 'RV')
        and je.ktosl in ('', 'MWS')
      then je.hsl else 0
    end
  ) as AmountBilledYear_WithVAT,

  // Measures: Amount Collected (With VAT) - Cumulative as of 31.12.(Year-1)
  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Collected as of 31.12.24 with VAT'
  sum(
    case
      when je.gjahr < $parameters.P_FiscalYear
        and je.rldnr = '0L'
        and je.blart in ('DZ', 'Z4')
        and je.drcrk = 'S'
      then je.hsl else 0
    end
  ) as AmountCollectedYTD_WithVAT,

  // Amount Collected (With VAT) - Monthly measures
  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Collected Jan-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '01'
        and je.rldnr = '0L'
        and je.blart in ('DZ', 'Z4')
        and je.drcrk = 'S'
      then je.hsl else 0
    end
  ) as AmountCollectedJan_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Collected Feb-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '02'
        and je.rldnr = '0L'
        and je.blart in ('DZ', 'Z4')
        and je.drcrk = 'S'
      then je.hsl else 0
    end
  ) as AmountCollectedFeb_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Collected Mar-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '03'
        and je.rldnr = '0L'
        and je.blart in ('DZ', 'Z4')
        and je.drcrk = 'S'
      then je.hsl else 0
    end
  ) as AmountCollectedMar_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Collected Apr-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '04'
        and je.rldnr = '0L'
        and je.blart in ('DZ', 'Z4')
        and je.drcrk = 'S'
      then je.hsl else 0
    end
  ) as AmountCollectedApr_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Collected May-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '05'
        and je.rldnr = '0L'
        and je.blart in ('DZ', 'Z4')
        and je.drcrk = 'S'
      then je.hsl else 0
    end
  ) as AmountCollectedMay_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Collected Jun-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '06'
        and je.rldnr = '0L'
        and je.blart in ('DZ', 'Z4')
        and je.drcrk = 'S'
      then je.hsl else 0
    end
  ) as AmountCollectedJun_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Collected Jul-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '07'
        and je.rldnr = '0L'
        and je.blart in ('DZ', 'Z4')
        and je.drcrk = 'S'
      then je.hsl else 0
    end
  ) as AmountCollectedJul_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Collected Aug-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '08'
        and je.rldnr = '0L'
        and je.blart in ('DZ', 'Z4')
        and je.drcrk = 'S'
      then je.hsl else 0
    end
  ) as AmountCollectedAug_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Collected Sep-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '09'
        and je.rldnr = '0L'
        and je.blart in ('DZ', 'Z4')
        and je.drcrk = 'S'
      then je.hsl else 0
    end
  ) as AmountCollectedSep_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Collected Oct-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '10'
        and je.rldnr = '0L'
        and je.blart in ('DZ', 'Z4')
        and je.drcrk = 'S'
      then je.hsl else 0
    end
  ) as AmountCollectedOct_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Collected Nov-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '11'
        and je.rldnr = '0L'
        and je.blart in ('DZ', 'Z4')
        and je.drcrk = 'S'
      then je.hsl else 0
    end
  ) as AmountCollectedNov_WithVAT,

  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Collected Dec-25 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.poper = '12'
        and je.rldnr = '0L'
        and je.blart in ('DZ', 'Z4')
        and je.drcrk = 'S'
      then je.hsl else 0
    end
  ) as AmountCollectedDec_WithVAT,

  // Amount Collected 2025 with VAT (Annual Total)
  @Semantics.amount.currencyCode: 'CURRENCY'
  @EndUserText.label: 'Amount Collected 2025 with VAT'
  sum(
    case
      when je.gjahr = $parameters.P_FiscalYear
        and je.rldnr = '0L'
        and je.blart in ('DZ', 'Z4')
        and je.drcrk = 'S'
      then je.hsl else 0
    end
  ) as AmountCollectedYear_WithVAT
}
group by
  je.rbukrs,
  je.kunnr,
  je.prctr,
  je.aufnr,
  t001.butxt,
  kna1.name1,
  adrc.city1,
  t005t.landx50,
  cepct.ltext,
  je.racct,
  knb1.zterm,
  t052.ztag1,
  je.prctr,
  je.aufnr,
  kna1.ktokd
