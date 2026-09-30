@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Rate Sheet Item - Interface'
@ObjectModel.usageType.dataClass: #TRANSACTIONAL
@ObjectModel.usageType.serviceQuality: #C
@ObjectModel.usageType.sizeCategory: #S
define view entity ZI_RSH_ITEM
  as select from zrsh_itm
  association to parent ZI_RSH_HEADER as _Header on $projection.RateSheetUUID = _Header.RateSheetUUID
  composition [0..*] of ZI_RSH_KIT    as _KitCostingItem
{
  key rate_sheet_item_uuid     as RateSheetItemUUID,
      rate_sheet_uuid          as RateSheetUUID,
      sr_no                    as SrNo,
      bom_status               as BomStatus,
      contract_no              as ContractNo,
      bom_component            as BomComponent,
      bom_uom                  as BomUoM,
      bom_qty                  as BomQty,
      qty_required             as QtyRequired,
      vendor_code              as VendorCode,
      vendor_name              as VendorName,
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
      total_price              as TotalPrice,
      pay_day                  as PayDay,
      modvat                   as Modvat,
      total_cost               as TotalCost,
      total_value              as TotalValue,
      average_rate             as AverageRate,
      @Semantics.booleanIndicator: true
      is_included              as IsIncluded,
      is_manual_line           as IsManualLine,
      manual_text              as ManualText,
      item_status              as ItemStatus,
      bom_item_node            as BomItemNode,
      bom_drift_status         as BomDriftStatus,
      quoted_basic_rate        as QuotedBasicRate,
      is_rate_from_kit         as IsRateFromKit,
      tax_code                 as TaxCode,
      info_record              as InfoRecord,
      is_avg_rate_row          as IsAvgRateRow,

      _Header,
      _KitCostingItem,

      created_by               as CreatedBy,
      created_at               as CreatedAt,
      last_changed_by          as LastChangedBy,
      last_changed_at          as LastChangedAt
}
