@EndUserText.label: 'Rate Sheet - Add More Line'
define abstract entity ZA_RSH_ADD_LINE
{
  @EndUserText.label: 'BOM Component'
  @ObjectModel.mandatory: true
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_ProductStdVH', element: 'Product' } }]
  BomComponent : abap.char(40);

  @EndUserText.label: 'Component Desc'
  Description  : abap.char(132);

  @EndUserText.label: 'Qty'
  @ObjectModel.mandatory: true
  Qty          : abap.dec(13,3);

  @EndUserText.label: 'UOM'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasureStdVH', element: 'UnitOfMeasure' } }]
  UoM          : abap.unit(3);

  @EndUserText.label: 'Basic Amt'
  BasicAmount  : abap.dec(13,2);
}