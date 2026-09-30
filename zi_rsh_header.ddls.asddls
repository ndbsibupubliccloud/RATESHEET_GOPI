@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Rate Sheet Header - Interface'
@ObjectModel.usageType.dataClass: #TRANSACTIONAL
@ObjectModel.usageType.serviceQuality: #C
@ObjectModel.usageType.sizeCategory: #S
define root view entity ZI_RSH_HEADER
  as select from zrsh_hdr
  composition [0..*] of ZI_RSH_ITEM as _Item
{
  key rate_sheet_uuid          as RateSheetUUID,
      rate_sheet_number        as RateSheetNumber,
      purchase_req             as PurchaseRequisition,
      purch_req_item           as PurchReqItem,
      plant                    as Plant,
      material                 as Material,
      requested_qty            as RequestedQuantity,
      base_uom                 as BaseUoM,
      ref_rate_sheet           as ReferenceRateSheetNumber,
      overall_status           as OverallStatus,
      currency                 as Currency,
      purchasing_org           as PurchasingOrg,
      rate_sheet_date          as RateSheetDate,
      bom_exploded_at          as BomExplodedAt,
      bom_check_ack            as BomCheckAck,

      _Item,

      @Semantics.user.createdBy: true
      created_by               as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at               as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by          as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at          as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at    as LocalLastChangedAt
}
