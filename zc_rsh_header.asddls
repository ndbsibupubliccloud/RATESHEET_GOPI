@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Rate Sheet Header - Projection'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_RSH_HEADER
  provider contract transactional_query
  as projection on ZI_RSH_HEADER
{
  key RateSheetUUID,
      RateSheetNumber,
      @Search.defaultSearchElement: true
      PurchaseRequisition,
      PurchReqItem,
      Plant,
      @Search.defaultSearchElement: true
      Material,
      RequestedQuantity,
      BaseUoM,
      ReferenceRateSheetNumber,
      OverallStatus,
      Currency,
      PurchasingOrg,
      RateSheetDate,
      BomExplodedAt,
      BomCheckAck,

      _Item : redirected to composition child ZC_RSH_ITEM,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt
}
