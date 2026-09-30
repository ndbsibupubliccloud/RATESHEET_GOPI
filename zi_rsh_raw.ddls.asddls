@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Rate Sheet Raw Mat. Costing'
@ObjectModel.usageType.dataClass: #TRANSACTIONAL
@ObjectModel.usageType.serviceQuality: #C
@ObjectModel.usageType.sizeCategory: #S
define view entity ZI_RSH_RAW
  as select from zrsh_raw
  association to parent ZI_RSH_KIT as _KitCostingItem on $projection.KitCostingUUID = _KitCostingItem.KitCostingUUID
  association [1..1] to ZI_RSH_HEADER as _Header      on $projection.RateSheetUUID  = _Header.RateSheetUUID
{
  key raw_mat_cost_uuid        as RawMatCostUUID,
      kit_costing_uuid         as KitCostingUUID,
      rate_sheet_uuid          as RateSheetUUID,
      sr_no                    as SrNo,
      bom_component            as BomComponent,
      vendor_code              as VendorCode,
      uom                      as UoM,
      qty                      as Qty,
      qty_required             as QtyRequired,
      vendor_order_qty         as VendorOrderQty,
      currency                 as Currency,
      basic_rate               as BasicRate,
      igst_pct                 as IgstPct,
      igst_amt                 as IgstAmt,
      cgst_pct                 as CgstPct,
      cgst_amt                 as CgstAmt,
      sgst_pct                 as SgstPct,
      sgst_amt                 as SgstAmt,
      ugst_pct                 as UgstPct,
      ugst_amt                 as UgstAmt,
      tax_value                as TaxValue,
      freight                  as Freight,
      handling                 as Handling,
      total_cost               as TotalCost,
      modvat                   as Modvat,
      net_landed               as NetLanded,
      basic_material           as BasicMaterial,
      colouring                as Colouring,
      net_cost                 as NetCost,
      local_benefit            as LocalBenefit,
      ze35_pct                 as Ze35Pct,
      tax_code                 as TaxCode,
      info_record              as InfoRecord,
      @Semantics.booleanIndicator: true
      is_selected_for_costing  as IsSelectedForCosting,

      _KitCostingItem,
      _Header,

      created_by               as CreatedBy,
      created_at               as CreatedAt,
      last_changed_by          as LastChangedBy,
      last_changed_at          as LastChangedAt
}
