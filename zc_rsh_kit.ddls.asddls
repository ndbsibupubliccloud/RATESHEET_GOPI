@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Rate Sheet Kit Costing - Projection'
@Metadata.allowExtensions: true
define view entity ZC_RSH_KIT
  as projection on ZI_RSH_KIT
{
  key KitCostingUUID,
      RateSheetItemUUID,
      RateSheetUUID,
      SrNo,
      BomComponent,
      UoM,
      Qty,
      QtyRequired,
      VendorOrderQty,
      Pcwtgms,
      Pcwtgross,
      Pcwtgorssbynos,
      Currency,
      Rcost,
      Rcostperpc,
      Mcostperpc,
      Mcostperset,
      Productcostperpc,
      Productcostperkit,
      LocalFreight,
      FormType,
      FormConditionType,
      Ze31Pct,
      Ze32Rate,
      WeightFactor,
      HasFurtherBom,
      IsSelectedComponent,

      _RateSheetItem : redirected to parent ZC_RSH_ITEM,
      _Header : redirected to ZC_RSH_HEADER,
      _RawMaterialCostingItem : redirected to composition child ZC_RSH_RAW,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt
}
