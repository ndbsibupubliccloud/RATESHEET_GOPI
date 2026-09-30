@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Rate Sheet Raw Mat. Costing - Proj'
@Metadata.allowExtensions: true
define view entity ZC_RSH_RAW
  as projection on ZI_RSH_RAW
{
  key RawMatCostUUID,
      KitCostingUUID,
      RateSheetUUID,
      SrNo,
      BomComponent,
      VendorCode,
      UoM,
      Qty,
      QtyRequired,
      VendorOrderQty,
      Currency,
      BasicRate,
      IgstPct,
      IgstAmt,
      CgstPct,
      CgstAmt,
      SgstPct,
      SgstAmt,
      UgstPct,
      UgstAmt,
      TaxValue,
      Freight,
      Handling,
      TotalCost,
      Modvat,
      NetLanded,
      BasicMaterial,
      Colouring,
      NetCost,
      LocalBenefit,
      Ze35Pct,
      TaxCode,
      InfoRecord,
      IsSelectedForCosting,

      _KitCostingItem : redirected to parent ZC_RSH_KIT,
      _Header : redirected to ZC_RSH_HEADER,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt
}
