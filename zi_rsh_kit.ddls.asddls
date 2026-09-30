@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Rate Sheet Kit Costing - Interface'
@ObjectModel.usageType.dataClass: #TRANSACTIONAL
@ObjectModel.usageType.serviceQuality: #C
@ObjectModel.usageType.sizeCategory: #S
define view entity ZI_RSH_KIT
  as select from zrsh_kit
  association to parent ZI_RSH_ITEM as _RateSheetItem on $projection.RateSheetItemUUID = _RateSheetItem.RateSheetItemUUID
  association [1..1] to ZI_RSH_HEADER as _Header       on $projection.RateSheetUUID     = _Header.RateSheetUUID
  composition [0..*] of ZI_RSH_RAW  as _RawMaterialCostingItem
{
  key kit_costing_uuid         as KitCostingUUID,
      rate_sheet_item_uuid     as RateSheetItemUUID,
      rate_sheet_uuid          as RateSheetUUID,
      sr_no                    as SrNo,
      bom_component            as BomComponent,
      uom                      as UoM,
      qty                      as Qty,
      qty_required             as QtyRequired,
      vendor_order_qty         as VendorOrderQty,
      pcwtgms                  as Pcwtgms,
      pcwtgross                as Pcwtgross,
      pcwtgorssbynos           as Pcwtgorssbynos,
      currency                 as Currency,
      rcost                    as Rcost,
      rcostperpc               as Rcostperpc,
      mcostperpc               as Mcostperpc,
      mcostperset              as Mcostperset,
      productcostperpc         as Productcostperpc,
      productcostperkit        as Productcostperkit,
      local_freight            as LocalFreight,
      form_type                as FormType,
      form_condition_type      as FormConditionType,
      ze31_pct                 as Ze31Pct,
      ze32_rate                as Ze32Rate,
      weight_factor            as WeightFactor,
      has_further_bom          as HasFurtherBom,
      @Semantics.booleanIndicator: true
      is_selected_component    as IsSelectedComponent,

      _RateSheetItem,
      _Header,
      _RawMaterialCostingItem,

      created_by               as CreatedBy,
      created_at               as CreatedAt,
      last_changed_by          as LastChangedBy,
      last_changed_at          as LastChangedAt
}
