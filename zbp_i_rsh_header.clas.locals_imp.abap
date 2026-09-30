CLASS lhc_rawmaterialcostingitem DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS calculateRawMaterialCost FOR DETERMINE ON MODIFY
      IMPORTING keys FOR RawMaterialCostingItem~calculateRawMaterialCost.

    METHODS rollUpRawMaterialToKit FOR DETERMINE ON MODIFY
      IMPORTING keys FOR RawMaterialCostingItem~rollUpRawMaterialToKit.

    METHODS parkdocument FOR MODIFY
      IMPORTING keys FOR ACTION RawMaterialCostingItem~parkDocument RESULT result.

ENDCLASS.

CLASS lhc_rawmaterialcostingitem IMPLEMENTATION.

  METHOD calculateRawMaterialCost.
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RawMaterialCostingItem
        FIELDS ( RawMatCostUUID KitCostingUUID RateSheetUUID BomComponent VendorCode
                 Qty QtyRequired VendorOrderQty IsSelectedForCosting )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_raws).

    IF lt_raws IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_header_keys TYPE TABLE FOR READ IMPORT zi_rsh_header.
    lt_header_keys = CORRESPONDING #( lt_raws MAPPING RateSheetUUID = RateSheetUUID ).
    SORT lt_header_keys BY RateSheetUUID.
    DELETE ADJACENT DUPLICATES FROM lt_header_keys COMPARING RateSheetUUID.

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        FIELDS ( RateSheetUUID Plant )
        WITH lt_header_keys
      RESULT DATA(lt_headers).

    TYPES: BEGIN OF ty_mat_vendor_plant,
             material TYPE i_purchasinginforecordapi01-material,
             supplier TYPE i_purchasinginforecordapi01-supplier,
             plant    TYPE i_purginforecdorgplntdataapi01-plant,
           END OF ty_mat_vendor_plant.

    DATA lt_mvp_keys TYPE STANDARD TABLE OF ty_mat_vendor_plant WITH EMPTY KEY.

    LOOP AT lt_raws ASSIGNING FIELD-SYMBOL(<raw>).
      IF <raw>-BomComponent IS INITIAL OR <raw>-VendorCode IS INITIAL.
        CONTINUE.
      ENDIF.
      READ TABLE lt_headers ASSIGNING FIELD-SYMBOL(<hdr>)
        WITH KEY RateSheetUUID = <raw>-RateSheetUUID.
      IF sy-subrc = 0 AND <hdr>-Plant IS NOT INITIAL.
        APPEND VALUE #( material = <raw>-BomComponent supplier = <raw>-VendorCode plant = <hdr>-Plant ) TO lt_mvp_keys.
      ENDIF.
    ENDLOOP.

    SORT lt_mvp_keys BY material supplier plant.
    DELETE ADJACENT DUPLICATES FROM lt_mvp_keys COMPARING material supplier plant.

    TYPES: BEGIN OF ty_info_rec_map,
             material             TYPE i_purchasinginforecordapi01-material,
             supplier             TYPE i_purchasinginforecordapi01-supplier,
             plant                TYPE i_purginforecdorgplntdataapi01-plant,
             purchasinginforecord TYPE i_purchasinginforecordapi01-purchasinginforecord,
           END OF ty_info_rec_map.
    DATA lt_info_map TYPE STANDARD TABLE OF ty_info_rec_map WITH EMPTY KEY.

    IF lt_mvp_keys IS NOT INITIAL.
      SELECT i~material, i~supplier, o~plant, i~purchasinginforecord
        FROM i_purchasinginforecordapi01 AS i
        INNER JOIN i_purginforecdorgplntdataapi01 AS o
          ON o~purchasinginforecord = i~purchasinginforecord
        FOR ALL ENTRIES IN @lt_mvp_keys
        WHERE i~material  = @lt_mvp_keys-material
          AND i~supplier  = @lt_mvp_keys-supplier
          AND o~plant     = @lt_mvp_keys-plant
          AND i~isdeleted = @abap_false
        INTO TABLE @lt_info_map.
    ENDIF.

    TYPES: BEGIN OF ty_cndn_key,
             purchasinginforecord TYPE i_purginforecdcndnrecordtp-purchasinginforecord,
             plant                TYPE i_purginforecdcndnrecordtp-plant,
           END OF ty_cndn_key.
    DATA lt_cndn_keys TYPE STANDARD TABLE OF ty_cndn_key WITH EMPTY KEY.

    LOOP AT lt_info_map ASSIGNING FIELD-SYMBOL(<info>).
      APPEND VALUE #( purchasinginforecord = <info>-purchasinginforecord plant = <info>-plant ) TO lt_cndn_keys.
    ENDLOOP.
    SORT lt_cndn_keys BY purchasinginforecord plant.
    DELETE ADJACENT DUPLICATES FROM lt_cndn_keys COMPARING purchasinginforecord plant.

    IF lt_cndn_keys IS NOT INITIAL.
      SELECT purchasinginforecord,
             plant,
             conditionrecord,
             conditiontype,
             conditionratevalue,
             conditionratevalueunit
        FROM i_purginforecdcndnrecordtp
        FOR ALL ENTRIES IN @lt_cndn_keys
        WHERE purchasinginforecord     = @lt_cndn_keys-purchasinginforecord
          AND plant                    = @lt_cndn_keys-plant
          AND conditionvalidityenddate = '99991231'
          AND conditionisdeleted       = @abap_false
        INTO TABLE @DATA(lt_conditions).
    ENDIF.

    DATA lt_updates TYPE TABLE FOR UPDATE zi_rsh_raw.

    LOOP AT lt_raws ASSIGNING <raw>.
      DATA lv_plant TYPE i_purginforecdorgplntdataapi01-plant.
      CLEAR lv_plant.
      READ TABLE lt_headers ASSIGNING <hdr>
        WITH KEY RateSheetUUID = <raw>-RateSheetUUID.
      IF sy-subrc = 0.
        lv_plant = <hdr>-Plant.
      ENDIF.

      DATA(lv_basic) = CONV zrsh_raw-basic_rate( 0 ).
      DATA(lv_igst_pct) = CONV zrsh_raw-igst_pct( 0 ).
      DATA(lv_cgst_pct) = CONV zrsh_raw-cgst_pct( 0 ).
      DATA(lv_sgst_pct) = CONV zrsh_raw-sgst_pct( 0 ).
      DATA(lv_ugst_pct) = CONV zrsh_raw-ugst_pct( 0 ).
      DATA(lv_freight) = CONV zrsh_raw-freight( 0 ).
      DATA(lv_handling) = CONV zrsh_raw-handling( 0 ).
      DATA(lv_colouring) = CONV zrsh_raw-colouring( 0 ).
      DATA(lv_ze35_pct) = CONV zrsh_raw-ze35_pct( 0 ).
      DATA(lv_loc_ben) = CONV zrsh_raw-local_benefit( 0 ).

      READ TABLE lt_info_map ASSIGNING <info>
        WITH KEY material = <raw>-BomComponent
                 supplier = <raw>-VendorCode
                 plant    = lv_plant.
      IF sy-subrc = 0 AND lt_cndn_keys IS NOT INITIAL.
        LOOP AT lt_conditions ASSIGNING FIELD-SYMBOL(<c>)
          WHERE purchasinginforecord = <info>-purchasinginforecord
            AND plant                = lv_plant.

          DATA(lv_val) = <c>-conditionratevalue.

          CASE <c>-conditiontype.
            WHEN 'ZP00'.
              lv_basic = lv_val.
            " P-102: legacy level-3 divides GST rates by 10 (KBETR / 10)
            WHEN 'ZE01' OR 'ZE02' OR 'ZE43' OR 'ZE47'.
              lv_igst_pct = lv_val / 10.
            WHEN 'ZE05' OR 'ZE06' OR 'ZE42' OR 'ZE46'.
              lv_cgst_pct = lv_val / 10.
            WHEN 'ZE10' OR 'ZE11' OR 'ZE41' OR 'ZE45'.
              lv_sgst_pct = lv_val / 10.
            WHEN 'ZE44' OR 'ZE48'.
              lv_ugst_pct = lv_val / 10.
            WHEN 'ZE20'.
              lv_freight = lv_val.
            WHEN 'ZE33'.
              lv_handling = lv_val.
            WHEN 'ZE34'.
              lv_colouring = lv_val.
            WHEN 'ZE35'.
              lv_ze35_pct = lv_val.
            WHEN 'ZE40'.
              lv_loc_ben = lv_val.
          ENDCASE.
        ENDLOOP.
      ENDIF.

      DATA(lv_igst_amt) = CONV zrsh_raw-igst_amt( lv_basic * ( lv_igst_pct / 100 ) ).
      DATA(lv_cgst_amt) = CONV zrsh_raw-cgst_amt( 0 ).
      DATA(lv_sgst_amt) = CONV zrsh_raw-sgst_amt( 0 ).
      DATA(lv_ugst_amt) = CONV zrsh_raw-ugst_amt( 0 ).

      IF lv_igst_amt = 0.
        lv_cgst_amt = CONV zrsh_raw-cgst_amt( lv_basic * ( lv_cgst_pct / 100 ) ).
        lv_sgst_amt = CONV zrsh_raw-sgst_amt( ( lv_basic + lv_igst_amt ) * ( lv_sgst_pct / 100 ) ).
        lv_ugst_amt = CONV zrsh_raw-ugst_amt( lv_basic * ( lv_ugst_pct / 100 ) ).
      ENDIF.

      DATA(lv_tax_val) = CONV zrsh_raw-tax_value( lv_igst_amt + lv_cgst_amt + lv_sgst_amt + lv_ugst_amt ).
      " P-102: legacy level-3 T_PRI = KBETR + GST + KSCHL4 (ZE20) + HAND (ZE33)
      " (legacy l.2337); T_COST = T_PRI - M_AMT; NTOT = T_PRI - M_AMT - LOCA
      DATA(lv_total_price) = CONV zrsh_raw-total_cost( lv_basic + lv_tax_val + lv_freight + lv_handling ).
      DATA(lv_modvat) = CONV zrsh_raw-modvat( lv_tax_val ).
      DATA(lv_total_cost) = CONV zrsh_raw-total_cost( lv_total_price - lv_modvat ).
      DATA(lv_net_landed) = CONV zrsh_raw-net_landed( lv_total_price - lv_modvat - lv_loc_ben ).
      DATA(lv_basic_mat) = CONV zrsh_raw-basic_material( lv_net_landed * ( lv_ze35_pct / 100 ) ).
      DATA(lv_net_cost) = COND zrsh_raw-net_cost(
        WHEN lv_basic_mat IS NOT INITIAL THEN CONV #( lv_basic_mat + lv_colouring )
        ELSE CONV #( lv_net_landed + lv_colouring ) ).

      APPEND VALUE #(
        %tky                 = <raw>-%tky
        BasicRate            = lv_basic
        IgstPct              = lv_igst_pct
        IgstAmt              = lv_igst_amt
        CgstPct              = lv_cgst_pct
        CgstAmt              = lv_cgst_amt
        SgstPct              = lv_sgst_pct
        SgstAmt              = lv_sgst_amt
        UgstPct              = lv_ugst_pct
        UgstAmt              = lv_ugst_amt
        TaxValue             = lv_tax_val
        Freight              = lv_freight
        Handling             = lv_handling
        TotalCost            = lv_total_cost
        Modvat               = lv_modvat
        NetLanded            = lv_net_landed
        BasicMaterial        = lv_basic_mat
        Colouring            = lv_colouring
        NetCost              = lv_net_cost
        LocalBenefit         = lv_loc_ben
        Ze35Pct              = lv_ze35_pct
      ) TO lt_updates.
    ENDLOOP.

    IF lt_updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
        ENTITY RawMaterialCostingItem
          UPDATE FIELDS ( BasicRate IgstPct IgstAmt CgstPct CgstAmt SgstPct SgstAmt UgstPct UgstAmt
                          TaxValue Freight Handling TotalCost Modvat NetLanded BasicMaterial
                          Colouring NetCost LocalBenefit Ze35Pct )
          WITH lt_updates.
    ENDIF.
  ENDMETHOD.

  METHOD rollUpRawMaterialToKit.
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RawMaterialCostingItem
        FIELDS ( RawMatCostUUID KitCostingUUID RateSheetUUID NetCost IsSelectedForCosting )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_raws).

    IF lt_raws IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_kit_updates TYPE TABLE FOR UPDATE zi_rsh_kit.

    LOOP AT lt_raws ASSIGNING FIELD-SYMBOL(<raw>).
      IF <raw>-KitCostingUUID IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_rcost) = COND zrsh_kit-rcost(
        WHEN <raw>-IsSelectedForCosting = abap_true AND <raw>-NetCost > 0
        THEN <raw>-NetCost
        ELSE '1.00' ).

      APPEND VALUE #(
        %tky  = VALUE #( KitCostingUUID = <raw>-KitCostingUUID %is_draft = <raw>-%is_draft )
        Rcost = lv_rcost
      ) TO lt_kit_updates.
    ENDLOOP.

    IF lt_kit_updates IS NOT INITIAL.
      SORT lt_kit_updates BY KitCostingUUID.
      DELETE ADJACENT DUPLICATES FROM lt_kit_updates COMPARING KitCostingUUID.

      MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
        ENTITY KitCostingItem
          UPDATE FIELDS ( Rcost )
          WITH lt_kit_updates.
    ENDIF.
  ENDMETHOD.

  METHOD parkdocument.
    " Legacy 'Document Park' is client-side only (E15 - no DB write besides the
    " normal RAP draft persistence which already happens on every MODIFY).
    " Model it as a no-op confirmation action returning the current instance.
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RawMaterialCostingItem
        FIELDS ( RawMatCostUUID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_raws).

    result = VALUE #( FOR raw IN lt_raws (
      %tky      = raw-%tky
      %param    = raw
    ) ).
  ENDMETHOD.

ENDCLASS.

CLASS lhc_kitcostingitem DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    METHODS checkkitqtyallocation FOR VALIDATE ON SAVE
      IMPORTING keys FOR KitCostingItem~checkKitQtyAllocation.


    METHODS deriveKitCosting FOR DETERMINE ON MODIFY
      IMPORTING keys FOR KitCostingItem~deriveKitCosting.

    METHODS explodeRawMaterialBom FOR DETERMINE ON MODIFY
      IMPORTING keys FOR KitCostingItem~explodeRawMaterialBom.

    METHODS rollUpKitToMainGrid FOR DETERMINE ON MODIFY
      IMPORTING keys FOR KitCostingItem~rollUpKitToMainGrid.

    METHODS parkdocument FOR MODIFY
      IMPORTING keys FOR ACTION KitCostingItem~parkDocument RESULT result.

ENDCLASS.

CLASS lhc_kitcostingitem IMPLEMENTATION.

METHOD deriveKitCosting.
READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY KitCostingItem
        FIELDS ( KitCostingUUID RateSheetItemUUID RateSheetUUID BomComponent Qty QtyRequired
                 VendorOrderQty Pcwtgms Rcost Ze31Pct Ze32Rate WeightFactor IsSelectedComponent
                 Pcwtgross Pcwtgorssbynos Rcostperpc Mcostperpc Mcostperset
                 Productcostperpc Productcostperkit )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_kits).

    IF lt_kits IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_item_keys TYPE TABLE FOR READ IMPORT zi_rsh_item.
    lt_item_keys = CORRESPONDING #( lt_kits MAPPING RateSheetItemUUID = RateSheetItemUUID ).
    SORT lt_item_keys BY RateSheetItemUUID.
    DELETE ADJACENT DUPLICATES FROM lt_item_keys COMPARING RateSheetItemUUID.

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetItem
        FIELDS ( RateSheetItemUUID RateSheetUUID VendorCode )
        WITH lt_item_keys
      RESULT DATA(lt_items).

    DATA lt_header_keys TYPE TABLE FOR READ IMPORT zi_rsh_header.
    lt_header_keys = CORRESPONDING #( lt_items MAPPING RateSheetUUID = RateSheetUUID ).
    SORT lt_header_keys BY RateSheetUUID.
    DELETE ADJACENT DUPLICATES FROM lt_header_keys COMPARING RateSheetUUID.

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        FIELDS ( RateSheetUUID Plant )
        WITH lt_header_keys
      RESULT DATA(lt_headers).

    TYPES: BEGIN OF ty_mat_vendor_plant,
             material TYPE i_purchasinginforecordapi01-material,
             supplier TYPE i_purchasinginforecordapi01-supplier,
             plant    TYPE i_purginforecdorgplntdataapi01-plant,
           END OF ty_mat_vendor_plant.

    DATA lt_mvp_keys TYPE STANDARD TABLE OF ty_mat_vendor_plant WITH EMPTY KEY.

    LOOP AT lt_kits ASSIGNING FIELD-SYMBOL(<kit>).
      READ TABLE lt_items ASSIGNING FIELD-SYMBOL(<itm>)
        WITH KEY RateSheetItemUUID = <kit>-RateSheetItemUUID.
      IF sy-subrc = 0 AND <itm>-VendorCode IS NOT INITIAL.
        READ TABLE lt_headers ASSIGNING FIELD-SYMBOL(<hdr>)
          WITH KEY RateSheetUUID = <itm>-RateSheetUUID.
        IF sy-subrc = 0 AND <hdr>-Plant IS NOT INITIAL.
          APPEND VALUE #( material = <kit>-BomComponent supplier = <itm>-VendorCode plant = <hdr>-Plant ) TO lt_mvp_keys.
        ENDIF.
      ENDIF.
    ENDLOOP.

    SORT lt_mvp_keys BY material supplier plant.
    DELETE ADJACENT DUPLICATES FROM lt_mvp_keys COMPARING material supplier plant.

    TYPES: BEGIN OF ty_info_rec_map,
             material             TYPE i_purchasinginforecordapi01-material,
             supplier             TYPE i_purchasinginforecordapi01-supplier,
             plant                TYPE i_purginforecdorgplntdataapi01-plant,
             purchasinginforecord TYPE i_purchasinginforecordapi01-purchasinginforecord,
           END OF ty_info_rec_map.
    DATA lt_info_map TYPE STANDARD TABLE OF ty_info_rec_map WITH EMPTY KEY.

    IF lt_mvp_keys IS NOT INITIAL.
      SELECT i~material, i~supplier, o~plant, i~purchasinginforecord
        FROM i_purchasinginforecordapi01 AS i
        INNER JOIN i_purginforecdorgplntdataapi01 AS o
          ON o~purchasinginforecord = i~purchasinginforecord
        FOR ALL ENTRIES IN @lt_mvp_keys
        WHERE i~material  = @lt_mvp_keys-material
          AND i~supplier  = @lt_mvp_keys-supplier
          AND o~plant     = @lt_mvp_keys-plant
          AND i~isdeleted = @abap_false
        INTO TABLE @lt_info_map.
    ENDIF.

    TYPES: BEGIN OF ty_cndn_key,
             purchasinginforecord TYPE i_purginforecdcndnrecordtp-purchasinginforecord,
             plant                TYPE i_purginforecdcndnrecordtp-plant,
           END OF ty_cndn_key.
    DATA lt_cndn_keys TYPE STANDARD TABLE OF ty_cndn_key WITH EMPTY KEY.

    LOOP AT lt_info_map ASSIGNING FIELD-SYMBOL(<info>).
      APPEND VALUE #( purchasinginforecord = <info>-purchasinginforecord plant = <info>-plant ) TO lt_cndn_keys.
    ENDLOOP.
    SORT lt_cndn_keys BY purchasinginforecord plant.
    DELETE ADJACENT DUPLICATES FROM lt_cndn_keys COMPARING purchasinginforecord plant.

    IF lt_cndn_keys IS NOT INITIAL.
      SELECT purchasinginforecord,
             plant,
             conditionrecord,
             conditiontype,
             conditionratevalue,
             conditionratevalueunit
        FROM i_purginforecdcndnrecordtp
        FOR ALL ENTRIES IN @lt_cndn_keys
        WHERE purchasinginforecord     = @lt_cndn_keys-purchasinginforecord
          AND plant                    = @lt_cndn_keys-plant
          AND conditiontype            IN ( 'ZE31', 'ZE32' )
          AND conditionvalidityenddate = '99991231'
          AND conditionisdeleted       = @abap_false
        INTO TABLE @DATA(lt_conditions).
    ENDIF.

    DATA lt_updates TYPE TABLE FOR UPDATE zi_rsh_kit.

    LOOP AT lt_kits ASSIGNING <kit>.
      DATA lv_vendor TYPE i_purchasinginforecordapi01-supplier.
      DATA lv_plant  TYPE i_purginforecdorgplntdataapi01-plant.
      CLEAR: lv_vendor, lv_plant.

      READ TABLE lt_items ASSIGNING <itm>
        WITH KEY RateSheetItemUUID = <kit>-RateSheetItemUUID.
      IF sy-subrc = 0.
        lv_vendor = <itm>-VendorCode.
        READ TABLE lt_headers ASSIGNING <hdr>
          WITH KEY RateSheetUUID = <itm>-RateSheetUUID.
        IF sy-subrc = 0.
          lv_plant = <hdr>-Plant.
        ENDIF.
      ENDIF.

      DATA(lv_ze31) = CONV zrsh_kit-ze31_pct( 0 ).
      DATA(lv_ze32) = CONV zrsh_kit-ze32_rate( 0 ).

      READ TABLE lt_info_map ASSIGNING <info>
        WITH KEY material = <kit>-BomComponent
                 supplier = lv_vendor
                 plant    = lv_plant.
      IF sy-subrc = 0 AND lt_cndn_keys IS NOT INITIAL.
        LOOP AT lt_conditions ASSIGNING FIELD-SYMBOL(<c>)
          WHERE purchasinginforecord = <info>-purchasinginforecord
            AND plant                = lv_plant.
          IF <c>-conditiontype = 'ZE31'.
            lv_ze31 = <c>-conditionratevalue.
          ELSEIF <c>-conditiontype = 'ZE32'.
            lv_ze32 = <c>-conditionratevalue.
          ENDIF.
        ENDLOOP.
      ENDIF.

      DATA(lv_rcost) = <kit>-Rcost.
      IF lv_rcost IS INITIAL.
        lv_rcost = '1.00'.
      ENDIF.

      DATA(lv_pcwtgms) = <kit>-Pcwtgms.
      IF lv_pcwtgms IS INITIAL.
        lv_pcwtgms = <kit>-Qty.
      ENDIF.

      DATA(lv_pcwtgross) = CONV zrsh_kit-pcwtgross( lv_pcwtgms + ( lv_pcwtgms * lv_ze31 / 100 ) ).
      DATA(lv_pcwtgorssbynos) = CONV zrsh_kit-pcwtgorssbynos( <kit>-Qty * lv_pcwtgross ).
      DATA(lv_rcostperpc) = CONV zrsh_kit-rcostperpc( ( lv_rcost * lv_pcwtgorssbynos ) / 1000 ).
      DATA(lv_mcostperpc) = CONV zrsh_kit-mcostperpc( ( lv_pcwtgms * lv_ze32 ) / 1000 ).
      DATA(lv_mcostperset) = CONV zrsh_kit-mcostperset( lv_mcostperpc * <kit>-Qty ).
      DATA(lv_productcostperpc) = CONV zrsh_kit-productcostperpc( lv_mcostperset + lv_rcostperpc ).
      DATA(lv_productcostperkit) = CONV zrsh_kit-productcostperkit( lv_productcostperpc ).

      " Idempotency guard (same pattern as P-034/D-031 fix in deriveeligiblevendors):
      " Rcost is an on-modify trigger field for this very determination. Writing it
      " even with an unchanged value re-triggers deriveKitCosting on itself; for
      " Kit rows the framework's recursion-depth guard eventually aborts with
      " LCX_ABAP_BEHV_DETVAL_ERROR ("stack of on-modify determinations too deep").
      " Only queue the UPDATE if at least one computed value genuinely differs
      " from what is already persisted, so a second/third self-triggered
      " invocation converges to a true no-op and the recursion stops.
      IF    <kit>-Rcost              <> lv_rcost
         OR <kit>-Pcwtgms            <> lv_pcwtgms
         OR <kit>-Ze31Pct            <> lv_ze31
         OR <kit>-Ze32Rate           <> lv_ze32
         OR <kit>-Pcwtgross          <> lv_pcwtgross
         OR <kit>-Pcwtgorssbynos     <> lv_pcwtgorssbynos
         OR <kit>-Rcostperpc         <> lv_rcostperpc
         OR <kit>-Mcostperpc         <> lv_mcostperpc
         OR <kit>-Mcostperset        <> lv_mcostperset
         OR <kit>-Productcostperpc   <> lv_productcostperpc
         OR <kit>-Productcostperkit  <> lv_productcostperkit.
        APPEND VALUE #(
          %tky              = <kit>-%tky
          Rcost             = lv_rcost
          Pcwtgms           = lv_pcwtgms
          Ze31Pct           = lv_ze31
          Ze32Rate          = lv_ze32
          Pcwtgross         = lv_pcwtgross
          Pcwtgorssbynos    = lv_pcwtgorssbynos
          Rcostperpc        = lv_rcostperpc
          Mcostperpc        = lv_mcostperpc
          Mcostperset       = lv_mcostperset
          Productcostperpc  = lv_productcostperpc
          Productcostperkit = lv_productcostperkit
        ) TO lt_updates.
      ENDIF.
    ENDLOOP.

    IF lt_updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
        ENTITY KitCostingItem
          UPDATE FIELDS ( Rcost Pcwtgms Ze31Pct Ze32Rate Pcwtgross Pcwtgorssbynos
                          Rcostperpc Mcostperpc Mcostperset Productcostperpc Productcostperkit )
          WITH lt_updates.
    ENDIF.
  ENDMETHOD.

METHOD explodeRawMaterialBom.
READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY KitCostingItem
        FIELDS ( KitCostingUUID RateSheetUUID RateSheetItemUUID BomComponent Qty QtyRequired VendorOrderQty )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_kits).

    IF lt_kits IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_header_keys TYPE TABLE FOR READ IMPORT zi_rsh_header.
    lt_header_keys = CORRESPONDING #( lt_kits MAPPING RateSheetUUID = RateSheetUUID ).
    SORT lt_header_keys BY RateSheetUUID.
    DELETE ADJACENT DUPLICATES FROM lt_header_keys COMPARING RateSheetUUID.

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        FIELDS ( RateSheetUUID Plant )
        WITH lt_header_keys
      RESULT DATA(lt_headers).

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY KitCostingItem BY \_RawMaterialCostingItem
        FIELDS ( KitCostingUUID BomComponent )
        WITH CORRESPONDING #( lt_kits )
      RESULT DATA(lt_existing_raws).

    TYPES: BEGIN OF ty_mat_plant,
             material TYPE i_billofmaterialitemtp_2-material,
             plant    TYPE i_billofmaterialitemtp_2-plant,
           END OF ty_mat_plant.

    DATA lt_mat_plant TYPE STANDARD TABLE OF ty_mat_plant WITH EMPTY KEY.

    LOOP AT lt_kits ASSIGNING FIELD-SYMBOL(<kit>).
      IF <kit>-BomComponent IS INITIAL.
        CONTINUE.
      ENDIF.
      IF line_exists( lt_existing_raws[ KitCostingUUID = <kit>-KitCostingUUID ] ).
        CONTINUE.
      ENDIF.

      READ TABLE lt_headers ASSIGNING FIELD-SYMBOL(<hdr>)
        WITH KEY RateSheetUUID = <kit>-RateSheetUUID.
      IF sy-subrc = 0 AND <hdr>-Plant IS NOT INITIAL.
        APPEND VALUE #( material = <kit>-BomComponent plant = <hdr>-Plant ) TO lt_mat_plant.
      ENDIF.
    ENDLOOP.

    IF lt_mat_plant IS INITIAL.
      RETURN.
    ENDIF.

    SORT lt_mat_plant BY material plant.
    DELETE ADJACENT DUPLICATES FROM lt_mat_plant COMPARING material plant.

    SELECT material, plant, billofmaterialcomponent, billofmaterialitemquantity,
           billofmaterialitemunit
      FROM i_billofmaterialitemtp_2
      FOR ALL ENTRIES IN @lt_mat_plant
      WHERE material               = @lt_mat_plant-material
        AND plant                  = @lt_mat_plant-plant
        AND billofmaterialcomponent IS NOT INITIAL
        AND isproductionrelevant   = @abap_true
        AND isdeleted              = @abap_false
      INTO TABLE @DATA(lt_raw_bom).

    IF lt_raw_bom IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_prod_type,
             product     TYPE i_product-product,
             producttype TYPE i_product-producttype,
           END OF ty_prod_type.
    DATA lt_prods TYPE STANDARD TABLE OF ty_prod_type WITH EMPTY KEY.

    LOOP AT lt_raw_bom ASSIGNING FIELD-SYMBOL(<raw>).
      APPEND VALUE #( product = <raw>-billofmaterialcomponent ) TO lt_prods.
    ENDLOOP.
    SORT lt_prods BY product.
    DELETE ADJACENT DUPLICATES FROM lt_prods COMPARING product.

    IF lt_prods IS NOT INITIAL.
      SELECT product, producttype
        FROM i_product
        FOR ALL ENTRIES IN @lt_prods
        WHERE product = @lt_prods-product
          AND ( producttype = 'ZROH' OR producttype = 'ROH' )
        INTO TABLE @DATA(lt_zroh_products).
    ENDIF.

    TYPES: BEGIN OF ty_info_key,
             material TYPE i_purchasinginforecordapi01-material,
             plant    TYPE i_purginforecdorgplntdataapi01-plant,
           END OF ty_info_key.
    DATA lt_info_keys TYPE STANDARD TABLE OF ty_info_key WITH EMPTY KEY.

    LOOP AT lt_raw_bom ASSIGNING <raw>.
      READ TABLE lt_headers ASSIGNING <hdr>
        WITH KEY RateSheetUUID = <kit>-RateSheetUUID.
      IF sy-subrc = 0.
        APPEND VALUE #( material = <raw>-billofmaterialcomponent plant = <hdr>-Plant ) TO lt_info_keys.
      ENDIF.
    ENDLOOP.
    SORT lt_info_keys BY material plant.
    DELETE ADJACENT DUPLICATES FROM lt_info_keys COMPARING material plant.

    IF lt_info_keys IS NOT INITIAL.
      SELECT i~material, o~plant, i~supplier, i~purchasinginforecord, o~netpriceamount, o~taxcode
        FROM i_purchasinginforecordapi01 AS i
        INNER JOIN i_purginforecdorgplntdataapi01 AS o
          ON o~purchasinginforecord = i~purchasinginforecord
        FOR ALL ENTRIES IN @lt_info_keys
        WHERE i~material  = @lt_info_keys-material
          AND o~plant     = @lt_info_keys-plant
          AND i~isdeleted = @abap_false
        INTO TABLE @DATA(lt_raw_vendors).
    ENDIF.

    DATA lt_create_raws TYPE TABLE FOR CREATE zi_rsh_kit\_RawMaterialCostingItem.

    LOOP AT lt_kits ASSIGNING <kit>.
      IF <kit>-BomComponent IS INITIAL.
        CONTINUE.
      ENDIF.
      IF line_exists( lt_existing_raws[ KitCostingUUID = <kit>-KitCostingUUID ] ).
        CONTINUE.
      ENDIF.

      READ TABLE lt_headers ASSIGNING <hdr>
        WITH KEY RateSheetUUID = <kit>-RateSheetUUID.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(lv_sr_no) = 0.
      APPEND INITIAL LINE TO lt_create_raws ASSIGNING FIELD-SYMBOL(<create_raw>).
      <create_raw>-%tky = <kit>-%tky.

      LOOP AT lt_raw_bom ASSIGNING <raw>
        WHERE material = <kit>-BomComponent
          AND plant    = <hdr>-Plant.

        IF lt_zroh_products IS NOT INITIAL.
          IF NOT line_exists( lt_zroh_products[ product = <raw>-billofmaterialcomponent ] ).
            CONTINUE.
          ENDIF.
        ENDIF.

        DATA(lv_qty_req) = CONV zrsh_raw-qty_required( <raw>-billofmaterialitemquantity * <kit>-VendorOrderQty ).
        IF lv_qty_req IS INITIAL.
          lv_qty_req = CONV zrsh_raw-qty_required( <raw>-billofmaterialitemquantity * <kit>-QtyRequired ).
        ENDIF.

        DATA(lv_vendor_found) = abap_false.

        LOOP AT lt_raw_vendors ASSIGNING FIELD-SYMBOL(<v>)
          WHERE material = <raw>-billofmaterialcomponent
            AND plant    = <hdr>-Plant.

          lv_vendor_found = abap_true.
          lv_sr_no += 1.

          APPEND VALUE #(
            %cid                 = |RAW_{ <kit>-KitCostingUUID }_{ lv_sr_no }|
            %is_draft            = <kit>-%is_draft
            RateSheetUUID        = <kit>-RateSheetUUID
            KitCostingUUID       = <kit>-KitCostingUUID
            SrNo                 = lv_sr_no
            BomComponent         = <raw>-billofmaterialcomponent
            VendorCode           = <v>-supplier
            InfoRecord           = <v>-purchasinginforecord
            TaxCode              = <v>-taxcode
            UoM                  = <raw>-billofmaterialitemunit
            Qty                  = <raw>-billofmaterialitemquantity
            QtyRequired          = lv_qty_req
            VendorOrderQty       = lv_qty_req
            IsSelectedForCosting = abap_false
          ) TO <create_raw>-%target.
        ENDLOOP.

        IF lv_vendor_found = abap_false.
          lv_sr_no += 1.
          APPEND VALUE #(
            %cid                 = |RAW_{ <kit>-KitCostingUUID }_{ lv_sr_no }|
            %is_draft            = <kit>-%is_draft
            RateSheetUUID        = <kit>-RateSheetUUID
            KitCostingUUID       = <kit>-KitCostingUUID
            SrNo                 = lv_sr_no
            BomComponent         = <raw>-billofmaterialcomponent
            UoM                  = <raw>-billofmaterialitemunit
            Qty                  = <raw>-billofmaterialitemquantity
            QtyRequired          = lv_qty_req
            VendorOrderQty       = lv_qty_req
            IsSelectedForCosting = abap_false
          ) TO <create_raw>-%target.
        ENDIF.
      ENDLOOP.

      IF <create_raw>-%target IS INITIAL.
        DELETE lt_create_raws INDEX lines( lt_create_raws ).
      ENDIF.
    ENDLOOP.

    IF lt_create_raws IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
        ENTITY KitCostingItem
          CREATE BY \_RawMaterialCostingItem
          FIELDS ( RateSheetUUID KitCostingUUID SrNo BomComponent VendorCode
                   InfoRecord TaxCode UoM Qty QtyRequired VendorOrderQty IsSelectedForCosting )
          WITH lt_create_raws.
    ENDIF.
  ENDMETHOD.

  METHOD rollUpKitToMainGrid.
    " P-102: legacy USER_COMMAND1 'PARK' (l.1949-1975). Only for parent
    " components with material group PK001..PK008 (packing):
    "   KBETR(parent) = quoted KBETR + SUM( PRODUCTCOSTPERPC of ticked kit rows )
    " GST amounts are not recomputed (E14). Other groups keep the vendor quote.
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY KitCostingItem
        FIELDS ( KitCostingUUID RateSheetItemUUID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_trigger_kits).

    IF lt_trigger_kits IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_item_keys TYPE TABLE FOR READ IMPORT zi_rsh_item.
    LOOP AT lt_trigger_kits ASSIGNING FIELD-SYMBOL(<trg>) WHERE RateSheetItemUUID IS NOT INITIAL.
      APPEND VALUE #( RateSheetItemUUID = <trg>-RateSheetItemUUID
                      %is_draft         = <trg>-%is_draft ) TO lt_item_keys.
    ENDLOOP.
    SORT lt_item_keys BY RateSheetItemUUID %is_draft.
    DELETE ADJACENT DUPLICATES FROM lt_item_keys COMPARING RateSheetItemUUID %is_draft.

    IF lt_item_keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetItem
        FIELDS ( RateSheetItemUUID RateSheetUUID BomComponent BasicRate QuotedBasicRate IsRateFromKit
                 TaxValue Modvat VendorOrderQty QtyRequired )
        WITH lt_item_keys
      RESULT DATA(lt_items).

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetItem BY \_KitCostingItem
        FIELDS ( KitCostingUUID RateSheetItemUUID Productcostperpc IsSelectedComponent )
        WITH CORRESPONDING #( lt_item_keys )
      RESULT DATA(lt_all_kits).

    TYPES: BEGIN OF ty_matkl,
             product      TYPE i_product-product,
             productgroup TYPE i_product-productgroup,
           END OF ty_matkl.
    DATA lt_prod_keys TYPE STANDARD TABLE OF ty_matkl WITH EMPTY KEY.
    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<i>) WHERE BomComponent IS NOT INITIAL.
      APPEND VALUE #( product = <i>-BomComponent ) TO lt_prod_keys.
    ENDLOOP.
    SORT lt_prod_keys BY product.
    DELETE ADJACENT DUPLICATES FROM lt_prod_keys COMPARING product.

    DATA lt_pk_products TYPE SORTED TABLE OF ty_matkl WITH UNIQUE KEY product.
    IF lt_prod_keys IS NOT INITIAL.
      SELECT product, productgroup
        FROM i_product
        FOR ALL ENTRIES IN @lt_prod_keys
        WHERE product      =  @lt_prod_keys-product
          AND productgroup BETWEEN 'PK001' AND 'PK008'
        INTO CORRESPONDING FIELDS OF TABLE @lt_pk_products.
    ENDIF.

    DATA lt_item_updates TYPE TABLE FOR UPDATE zi_rsh_item.

    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<itm>).
      DATA(lv_is_pk) = xsdbool( line_exists( lt_pk_products[ product = <itm>-BomComponent ] ) ).

      DATA(lv_kit_sum) = CONV zrsh_itm-basic_rate( 0 ).
      DATA(lv_has_sel) = abap_false.
      LOOP AT lt_all_kits ASSIGNING FIELD-SYMBOL(<kit>)
        WHERE RateSheetItemUUID   = <itm>-RateSheetItemUUID
          AND IsSelectedComponent = abap_true.
        lv_kit_sum += <kit>-Productcostperpc.
        lv_has_sel = abap_true.
      ENDLOOP.

      DATA(lv_quoted) = COND zrsh_itm-basic_rate(
        WHEN <itm>-IsRateFromKit = abap_true THEN <itm>-QuotedBasicRate
        ELSE <itm>-BasicRate ).

      DATA(lv_qty) = COND zrsh_itm-vendor_order_qty(
        WHEN <itm>-VendorOrderQty IS INITIAL THEN <itm>-QtyRequired
        ELSE <itm>-VendorOrderQty ).

      IF lv_is_pk = abap_true AND lv_has_sel = abap_true.
        DATA(lv_new_basic) = CONV zrsh_itm-basic_rate( lv_quoted + lv_kit_sum ).
        IF <itm>-IsRateFromKit = abap_true AND <itm>-BasicRate = lv_new_basic.
          CONTINUE.   " idempotency guard
        ENDIF.
        DATA(lv_new_total_price) = CONV zrsh_itm-total_price( lv_new_basic + <itm>-TaxValue ).
        DATA(lv_new_total_cost) = CONV zrsh_itm-total_cost( lv_new_total_price - <itm>-Modvat ).
        APPEND VALUE #(
          %tky            = <itm>-%tky
          BasicRate       = lv_new_basic
          QuotedBasicRate = lv_quoted
          IsRateFromKit   = abap_true
          TotalPrice      = lv_new_total_price
          TotalCost       = lv_new_total_cost
          TotalValue      = CONV zrsh_itm-total_value( lv_new_total_cost * lv_qty )
        ) TO lt_item_updates.

      ELSEIF <itm>-IsRateFromKit = abap_true.
        " no ticked kit rows any more (or not a packing group): restore quote
        DATA(lv_rest_total_price) = CONV zrsh_itm-total_price( lv_quoted + <itm>-TaxValue ).
        DATA(lv_rest_total_cost) = CONV zrsh_itm-total_cost( lv_rest_total_price - <itm>-Modvat ).
        APPEND VALUE #(
          %tky          = <itm>-%tky
          BasicRate     = lv_quoted
          IsRateFromKit = abap_false
          TotalPrice    = lv_rest_total_price
          TotalCost     = lv_rest_total_cost
          TotalValue    = CONV zrsh_itm-total_value( lv_rest_total_cost * lv_qty )
        ) TO lt_item_updates.
      ENDIF.
    ENDLOOP.

    " AverageRate is recomputed by deriveEligibleVendors (BasicRate is a trigger).
    IF lt_item_updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
        ENTITY RateSheetItem
          UPDATE FIELDS ( BasicRate QuotedBasicRate IsRateFromKit TotalPrice TotalCost TotalValue )
          WITH lt_item_updates.
    ENDIF.
  ENDMETHOD.

  METHOD parkdocument.
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY KitCostingItem
        FIELDS ( KitCostingUUID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_kits).

    result = VALUE #( FOR kit IN lt_kits (
      %tky   = kit-%tky
      %param = kit
    ) ).
  ENDMETHOD.

  METHOD checkkitqtyallocation.
    " P-102: legacy USER_COMMAND1 CHECK/SAVE1 (l.1990-2026, 2085): per kit
    " component, the ticked (TICK1) vendor order qty total must equal the
    " required qty ('Check vendor order qty for BOM Component ...').
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY KitCostingItem
        FIELDS ( RateSheetItemUUID RateSheetUUID BomComponent )
        WITH CORRESPONDING #( keys )
      RESULT DATA(trigger_kits).

    IF trigger_kits IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_parent_keys TYPE TABLE FOR READ IMPORT zi_rsh_item.
    LOOP AT trigger_kits ASSIGNING FIELD-SYMBOL(<tk>) WHERE RateSheetItemUUID IS NOT INITIAL.
      APPEND VALUE #( RateSheetItemUUID = <tk>-RateSheetItemUUID
                      %is_draft         = <tk>-%is_draft ) TO lt_parent_keys.
      APPEND VALUE #( %tky        = <tk>-%tky
                      %state_area = 'KIT_QTY_ALLOCATION' ) TO reported-kitcostingitem.
    ENDLOOP.
    SORT lt_parent_keys BY RateSheetItemUUID %is_draft.
    DELETE ADJACENT DUPLICATES FROM lt_parent_keys COMPARING RateSheetItemUUID %is_draft.

    IF lt_parent_keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetItem BY \_KitCostingItem
        FIELDS ( RateSheetItemUUID BomComponent QtyRequired VendorOrderQty IsSelectedComponent )
        WITH CORRESPONDING #( lt_parent_keys )
      RESULT DATA(all_kits).

    LOOP AT trigger_kits ASSIGNING <tk>.
      DATA(lv_required) = CONV zrsh_kit-qty_required( 0 ).
      DATA(lv_ticked)   = CONV zrsh_kit-vendor_order_qty( 0 ).
      DATA(lv_has_tick) = abap_false.
      LOOP AT all_kits ASSIGNING FIELD-SYMBOL(<k>)
        WHERE RateSheetItemUUID = <tk>-RateSheetItemUUID
          AND BomComponent      = <tk>-BomComponent.
        IF <k>-QtyRequired > lv_required.
          lv_required = <k>-QtyRequired.
        ENDIF.
        IF <k>-IsSelectedComponent = abap_true.
          lv_ticked  += <k>-VendorOrderQty.
          lv_has_tick = abap_true.
        ENDIF.
      ENDLOOP.

      IF lv_has_tick = abap_true AND lv_ticked <> lv_required.
        APPEND VALUE #( %tky = <tk>-%tky ) TO failed-kitcostingitem.
        APPEND VALUE #(
          %tky                    = <tk>-%tky
          %state_area             = 'KIT_QTY_ALLOCATION'
          %path                   = VALUE #( ratesheetheader = VALUE #(
                                               %is_draft     = <tk>-%is_draft
                                               RateSheetUUID = <tk>-RateSheetUUID ) )
          %element-VendorOrderQty = if_abap_behv=>mk-on
          %msg                    = new_message_with_text(
                                      severity = if_abap_behv_message=>severity-error
                                      text     = |Check vendor order qty for BOM Component { <tk>-BomComponent } (kit): ticked total { lv_ticked } <> qty required { lv_required }.| )
        ) TO reported-kitcostingitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_ratesheetheader DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS refreshratesheet FOR MODIFY
      IMPORTING keys FOR ACTION RateSheetHeader~refreshRateSheet RESULT result.


    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR ratesheetheader RESULT result.

    METHODS derivefrompurchreq FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ratesheetheader~derivefrompurchreq.

    METHODS explodebom FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ratesheetheader~explodebom.

    METHODS setdefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ratesheetheader~setdefaults.

    METHODS assignratesheetnumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR ratesheetheader~assignratesheetnumber.

    METHODS checkpurchreqstatus FOR VALIDATE ON SAVE
      IMPORTING keys FOR ratesheetheader~checkpurchreqstatus.

    METHODS checkbomdrift FOR VALIDATE ON SAVE
      IMPORTING keys FOR ratesheetheader~checkbomdrift.

    METHODS recreateratesheet FOR MODIFY
      IMPORTING keys FOR ACTION ratesheetheader~recreateRateSheet RESULT result.

    METHODS checkbom FOR MODIFY
      IMPORTING keys FOR ACTION ratesheetheader~checkBom RESULT result.

    METHODS acknowledgebomchanges FOR MODIFY
      IMPORTING keys FOR ACTION ratesheetheader~acknowledgeBomChanges RESULT result.

    METHODS copyfromreference FOR MODIFY
      IMPORTING keys FOR ACTION ratesheetheader~copyFromReference RESULT result.

    METHODS createcontract FOR MODIFY
      IMPORTING keys FOR ACTION ratesheetheader~createContract RESULT result.

    METHODS addmoreline FOR MODIFY
      IMPORTING keys FOR ACTION ratesheetheader~addMoreLine RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR ratesheetheader RESULT result.

ENDCLASS.

CLASS lhc_ratesheetheader IMPLEMENTATION.

  METHOD get_instance_authorizations.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      APPEND VALUE #(
        %tky    = <key>-%tky
        %update = if_abap_behv=>auth-allowed
        %delete = if_abap_behv=>auth-allowed
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

METHOD derivefrompurchreq.
  TYPES: BEGIN OF ty_pr_key,
           purchaserequisition     TYPE i_purchaserequisitionitemapi01-purchaserequisition,
           purchaserequisitionitem TYPE i_purchaserequisitionitemapi01-purchaserequisitionitem,
         END OF ty_pr_key.

  DATA: lt_pr_keys TYPE STANDARD TABLE OF ty_pr_key WITH DEFAULT KEY.

  READ ENTITIES OF zi_rsh_header IN LOCAL MODE
    ENTITY RateSheetHeader
      FIELDS ( PurchaseRequisition PurchReqItem Material RequestedQuantity BaseUoM )
      WITH CORRESPONDING #( keys )
    RESULT DATA(headers).

  LOOP AT headers ASSIGNING FIELD-SYMBOL(<header>).
    IF <header>-PurchaseRequisition IS NOT INITIAL.
      DATA(lv_pr_in)   = CONV i_purchaserequisitionitemapi01-purchaserequisition( |{ <header>-PurchaseRequisition ALPHA = IN }| ).
      DATA(lv_item_in) = CONV i_purchaserequisitionitemapi01-purchaserequisitionitem( |{ <header>-PurchReqItem ALPHA = IN }| ).
      APPEND VALUE #(
        purchaserequisition     = lv_pr_in
        purchaserequisitionitem = lv_item_in
      ) TO lt_pr_keys.
    ENDIF.
  ENDLOOP.

  IF lt_pr_keys IS NOT INITIAL.
    SELECT purchaserequisition,
           purchaserequisitionitem,
           material,
           requestedquantity,
           baseunit
      FROM i_purchaserequisitionitemapi01
      FOR ALL ENTRIES IN @lt_pr_keys
      WHERE purchaserequisition     = @lt_pr_keys-purchaserequisition
        AND purchaserequisitionitem = @lt_pr_keys-purchaserequisitionitem
      INTO TABLE @DATA(lt_pr_data).
  ENDIF.

  DATA: lt_updates TYPE TABLE FOR UPDATE zi_rsh_header.

  LOOP AT headers ASSIGNING <header>.
    IF <header>-PurchaseRequisition IS INITIAL.
      CONTINUE.
    ENDIF.
    DATA(lv_pr_key)   = CONV i_purchaserequisitionitemapi01-purchaserequisition( |{ <header>-PurchaseRequisition ALPHA = IN }| ).
    DATA(lv_item_key) = CONV i_purchaserequisitionitemapi01-purchaserequisitionitem( |{ <header>-PurchReqItem ALPHA = IN }| ).

    READ TABLE lt_pr_data ASSIGNING FIELD-SYMBOL(<pr>)
      WITH KEY purchaserequisition     = lv_pr_key
               purchaserequisitionitem = lv_item_key.
    IF sy-subrc = 0.
      IF <header>-Material <> <pr>-material
      OR <header>-RequestedQuantity <> <pr>-requestedquantity
      OR <header>-BaseUoM <> <pr>-baseunit.
        APPEND VALUE #(
          %tky              = <header>-%tky
          Material          = <pr>-material
          RequestedQuantity = <pr>-requestedquantity
          BaseUoM           = <pr>-baseunit
        ) TO lt_updates.
      ENDIF.
    ENDIF.
  ENDLOOP.

  IF lt_updates IS NOT INITIAL.
    MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        UPDATE FIELDS ( Material RequestedQuantity BaseUoM )
        WITH lt_updates.
  ENDIF.
ENDMETHOD.

METHOD explodebom.
  TYPES: BEGIN OF ty_mat_plant,
           material TYPE i_billofmaterialitemtp_2-material,
           plant    TYPE i_billofmaterialitemtp_2-plant,
         END OF ty_mat_plant.

  DATA lt_mat_plants TYPE STANDARD TABLE OF ty_mat_plant WITH DEFAULT KEY.

  READ ENTITIES OF zi_rsh_header IN LOCAL MODE
    ENTITY RateSheetHeader
      FIELDS ( PurchaseRequisition PurchReqItem Material Plant RequestedQuantity )
      WITH CORRESPONDING #( keys )
    RESULT DATA(headers).

  IF headers IS INITIAL.
    RETURN.
  ENDIF.

  " A determination can fire more than once in one draft. Keep the explosion
  " idempotent and preserve buyer-edited child rows once they exist.
  READ ENTITIES OF zi_rsh_header IN LOCAL MODE
    ENTITY RateSheetHeader BY \_Item
      FIELDS ( RateSheetUUID BomComponent BomItemNode )
      WITH CORRESPONDING #( headers )
    RESULT DATA(existing_items).

  lt_mat_plants = VALUE #( FOR h IN headers
    WHERE ( Material IS NOT INITIAL AND Plant IS NOT INITIAL )
    ( material = h-Material
      plant    = h-Plant ) ).
  SORT lt_mat_plants.
  DELETE ADJACENT DUPLICATES FROM lt_mat_plants.

  IF lt_mat_plants IS INITIAL.
    RETURN.
  ENDIF.

  " Match the production legacy selection: production-relevant, non-deleted
  " material BOM items only. Blank components are technical BOM rows and must
  " never become included costing lines.
  SELECT material,
         plant,
         billofmaterialcomponent,
         billofmaterialitemquantity,
         billofmaterialitemunit,
         billofmaterialitemnodenumber
    FROM i_billofmaterialitemtp_2
    FOR ALL ENTRIES IN @lt_mat_plants
    WHERE material                    = @lt_mat_plants-material
      AND plant                       = @lt_mat_plants-plant
      AND billofmaterialcomponent     IS NOT INITIAL
      AND isproductionrelevant        = @abap_true
      AND isdeleted                   = @abap_false
    INTO TABLE @DATA(lt_bom_items).

  IF lt_bom_items IS INITIAL.
    RETURN.
  ENDIF.

  SORT lt_bom_items BY material plant billofmaterialitemnodenumber
                       billofmaterialcomponent.
  DELETE ADJACENT DUPLICATES FROM lt_bom_items
    COMPARING material plant billofmaterialitemnodenumber
              billofmaterialcomponent.

  TYPES: BEGIN OF ty_comp_plant,
           component TYPE i_billofmaterialitemtp_2-material,
           plant     TYPE i_billofmaterialitemtp_2-plant,
         END OF ty_comp_plant.
  DATA lt_comp_plants TYPE STANDARD TABLE OF ty_comp_plant WITH DEFAULT KEY.

  lt_comp_plants = VALUE #( FOR b IN lt_bom_items
    ( component = b-billofmaterialcomponent
      plant     = b-plant ) ).
  SORT lt_comp_plants.
  DELETE ADJACENT DUPLICATES FROM lt_comp_plants.

  IF lt_comp_plants IS NOT INITIAL.
    SELECT DISTINCT material, plant
      FROM i_billofmaterialitemtp_2
      FOR ALL ENTRIES IN @lt_comp_plants
      WHERE material                    = @lt_comp_plants-component
        AND plant                       = @lt_comp_plants-plant
        AND billofmaterialcomponent     IS NOT INITIAL
        AND isproductionrelevant        = @abap_true
        AND isdeleted                   = @abap_false
      INTO TABLE @DATA(lt_sub_boms).
  ENDIF.

  DATA lt_create_items TYPE TABLE FOR CREATE zi_rsh_header\_Item.
  DATA lv_sr_no TYPE i.

  LOOP AT headers ASSIGNING FIELD-SYMBOL(<header>)
    WHERE Material IS NOT INITIAL AND Plant IS NOT INITIAL.

    " Existing draft/active children make this invocation a no-op. Recreate
    " will be a separate explicit destructive action, matching legacy UX.
    READ TABLE existing_items TRANSPORTING NO FIELDS
      WITH KEY RateSheetUUID = <header>-RateSheetUUID.
    IF sy-subrc = 0.
      CONTINUE.
    ENDIF.

    lv_sr_no = 0.
    APPEND INITIAL LINE TO lt_create_items ASSIGNING FIELD-SYMBOL(<create_hdr>).
    <create_hdr>-%tky = <header>-%tky.

    LOOP AT lt_bom_items ASSIGNING FIELD-SYMBOL(<bom>)
      WHERE material = <header>-Material
        AND plant    = <header>-Plant.
      lv_sr_no += 1.

      READ TABLE lt_sub_boms TRANSPORTING NO FIELDS
        WITH KEY material = <bom>-billofmaterialcomponent
                 plant    = <bom>-plant.
      DATA(lv_bom_status) = COND ze_bom_status(
        WHEN sy-subrc = 0 THEN 'G' ELSE 'Y' ).

      DATA(lv_qty_req) = CONV zrsh_itm-qty_required(
        <bom>-billofmaterialitemquantity * <header>-RequestedQuantity ).

      APPEND VALUE #(
        %cid           = |CID_{ <header>-PurchaseRequisition }_{ <header>-PurchReqItem }_{ lv_sr_no }|
        %is_draft      = <header>-%is_draft
        SrNo           = lv_sr_no
        BomStatus      = lv_bom_status
        BomComponent   = <bom>-billofmaterialcomponent
        BomQty         = <bom>-billofmaterialitemquantity
        BomUoM         = <bom>-billofmaterialitemunit
        QtyRequired    = lv_qty_req
        VendorOrderQty = lv_qty_req
        BomItemNode    = <bom>-billofmaterialitemnodenumber
        IsIncluded     = abap_true
        ItemStatus     = 'D'
      ) TO <create_hdr>-%target.
    ENDLOOP.
  ENDLOOP.

  DELETE lt_create_items WHERE %target IS INITIAL.

  IF lt_create_items IS NOT INITIAL.
    MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        CREATE BY \_Item
        FIELDS ( SrNo BomStatus BomComponent BomQty BomUoM QtyRequired
                 VendorOrderQty BomItemNode IsIncluded ItemStatus )
        WITH lt_create_items.
  ENDIF.
ENDMETHOD.

  METHOD setdefaults.
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        FIELDS ( RateSheetDate OverallStatus PurchasingOrg Currency )
        WITH CORRESPONDING #( keys )
      RESULT DATA(headers).

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        UPDATE FIELDS ( RateSheetDate OverallStatus PurchasingOrg Currency )
        WITH VALUE #( FOR h IN headers (
          %tky          = h-%tky
          RateSheetDate = COND #( WHEN h-RateSheetDate IS INITIAL THEN lv_today ELSE h-RateSheetDate )
          OverallStatus = COND #( WHEN h-OverallStatus IS INITIAL THEN 'N' ELSE h-OverallStatus )
          PurchasingOrg = COND #( WHEN h-PurchasingOrg IS INITIAL THEN '1001' ELSE h-PurchasingOrg )
          Currency      = COND #( WHEN h-Currency IS INITIAL THEN 'INR' ELSE h-Currency )
        ) ).
  ENDMETHOD.

METHOD assignratesheetnumber.
  READ ENTITIES OF zi_rsh_header IN LOCAL MODE
    ENTITY RateSheetHeader
      FIELDS ( RateSheetNumber PurchaseRequisition PurchReqItem )
      WITH CORRESPONDING #( keys )
    RESULT DATA(headers).

  DATA lt_updates TYPE TABLE FOR UPDATE zi_rsh_header.

  LOOP AT headers ASSIGNING FIELD-SYMBOL(<header>)
    WHERE RateSheetNumber IS INITIAL.
    " Strict legacy parity: RSNO is PR number + five-digit PR item,
    " with no independent number-range allocation.
    DATA(lv_rate_sheet_number) = CONV zrsh_hdr-rate_sheet_number(
      |{ <header>-PurchaseRequisition }{ <header>-PurchReqItem }| ).

    APPEND VALUE #(
      %tky            = <header>-%tky
      RateSheetNumber = lv_rate_sheet_number
    ) TO lt_updates.
  ENDLOOP.

  IF lt_updates IS NOT INITIAL.
    MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        UPDATE FIELDS ( RateSheetNumber )
        WITH lt_updates.
  ENDIF.
ENDMETHOD.

METHOD checkpurchreqstatus.
  TYPES: BEGIN OF ty_pr_key,
           purchaserequisition     TYPE i_purchaserequisitionitemapi01-purchaserequisition,
           purchaserequisitionitem TYPE i_purchaserequisitionitemapi01-purchaserequisitionitem,
         END OF ty_pr_key.

  DATA: lt_pr_keys TYPE STANDARD TABLE OF ty_pr_key WITH DEFAULT KEY.

  READ ENTITIES OF zi_rsh_header IN LOCAL MODE
    ENTITY RateSheetHeader
      FIELDS ( PurchaseRequisition PurchReqItem )
      WITH CORRESPONDING #( keys )
    RESULT DATA(headers).

  LOOP AT headers ASSIGNING FIELD-SYMBOL(<header>).
    IF <header>-PurchaseRequisition IS NOT INITIAL.
      DATA(lv_pr_in)   = CONV i_purchaserequisitionitemapi01-purchaserequisition( |{ <header>-PurchaseRequisition ALPHA = IN }| ).
      DATA(lv_item_in) = CONV i_purchaserequisitionitemapi01-purchaserequisitionitem( |{ <header>-PurchReqItem ALPHA = IN }| ).
      APPEND VALUE #(
        purchaserequisition     = lv_pr_in
        purchaserequisitionitem = lv_item_in
      ) TO lt_pr_keys.
    ENDIF.
  ENDLOOP.

  IF lt_pr_keys IS NOT INITIAL.
    SELECT purchaserequisition,
           purchaserequisitionitem,
           isdeleted,
           isclosed
      FROM i_purchaserequisitionitemapi01
      FOR ALL ENTRIES IN @lt_pr_keys
      WHERE purchaserequisition     = @lt_pr_keys-purchaserequisition
        AND purchaserequisitionitem = @lt_pr_keys-purchaserequisitionitem
      INTO TABLE @DATA(lt_pr_items).
  ENDIF.

  LOOP AT headers ASSIGNING <header>.
    IF <header>-PurchaseRequisition IS INITIAL.
      CONTINUE.
    ENDIF.
    DATA(lv_pr_key)   = CONV i_purchaserequisitionitemapi01-purchaserequisition( |{ <header>-PurchaseRequisition ALPHA = IN }| ).
    DATA(lv_item_key) = CONV i_purchaserequisitionitemapi01-purchaserequisitionitem( |{ <header>-PurchReqItem ALPHA = IN }| ).

    READ TABLE lt_pr_items ASSIGNING FIELD-SYMBOL(<pr_item>)
      WITH KEY purchaserequisition     = lv_pr_key
               purchaserequisitionitem = lv_item_key.
    IF sy-subrc <> 0.
      APPEND VALUE #( %tky = <header>-%tky ) TO failed-ratesheetheader.
      APPEND VALUE #(
        %tky                         = <header>-%tky
        %element-purchaserequisition = if_abap_behv=>mk-on
        %element-purchreqitem        = if_abap_behv=>mk-on
        %msg                         = new_message( id       = 'ZRATESHEET'
                                                    number   = '001'
                                                    severity = if_abap_behv_message=>severity-error
                                                    v1       = <header>-PurchaseRequisition
                                                    v2       = <header>-PurchReqItem )
      ) TO reported-ratesheetheader.
    ELSEIF <pr_item>-isdeleted = abap_true.
      APPEND VALUE #( %tky = <header>-%tky ) TO failed-ratesheetheader.
      APPEND VALUE #(
        %tky                         = <header>-%tky
        %element-purchaserequisition = if_abap_behv=>mk-on
        %element-purchreqitem        = if_abap_behv=>mk-on
        %msg                         = new_message( id       = 'ZRATESHEET'
                                                    number   = '001'
                                                    severity = if_abap_behv_message=>severity-error
                                                    v1       = <header>-PurchaseRequisition
                                                    v2       = <header>-PurchReqItem )
      ) TO reported-ratesheetheader.
    ELSEIF <pr_item>-isclosed = abap_true.
      APPEND VALUE #( %tky = <header>-%tky ) TO failed-ratesheetheader.
      APPEND VALUE #(
        %tky                         = <header>-%tky
        %element-purchaserequisition = if_abap_behv=>mk-on
        %element-purchreqitem        = if_abap_behv=>mk-on
        %msg                         = new_message( id       = 'ZRATESHEET'
                                                    number   = '002'
                                                    severity = if_abap_behv_message=>severity-error
                                                    v1       = <header>-PurchaseRequisition
                                                    v2       = <header>-PurchReqItem )
      ) TO reported-ratesheetheader.
    ENDIF.
  ENDLOOP.
ENDMETHOD.

  METHOD checkbomdrift.
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        FIELDS ( Material Plant BomExplodedAt BomCheckAck )
        WITH CORRESPONDING #( keys )
      RESULT DATA(headers).

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader BY \_Item
        FIELDS ( RateSheetUUID BomComponent IsManualLine )
        WITH CORRESPONDING #( headers )
      RESULT DATA(existing_items).

    " P-101: compare DISTINCT BOM components (legacy BOM button deletes
    " adjacent duplicates by IDNRK). Extra vendor rows and manual
    " 'More Line' rows must not count as BOM drift.
    DATA lt_drift_comps TYPE SORTED TABLE OF zrsh_itm-bom_component WITH UNIQUE KEY table_line.

    LOOP AT headers ASSIGNING FIELD-SYMBOL(<header>)
      WHERE Material IS NOT INITIAL AND Plant IS NOT INITIAL AND BomExplodedAt IS NOT INITIAL.

      CLEAR lt_drift_comps.
      LOOP AT existing_items ASSIGNING FIELD-SYMBOL(<drift_row>)
        WHERE RateSheetUUID = <header>-RateSheetUUID
          AND BomComponent IS NOT INITIAL
          AND IsManualLine = abap_false.
        INSERT <drift_row>-BomComponent INTO TABLE lt_drift_comps.
      ENDLOOP.
      DATA(lv_existing_count) = lines( lt_drift_comps ).

      SELECT COUNT( DISTINCT billofmaterialcomponent )
        FROM i_billofmaterialitemtp_2
        WHERE material               = @<header>-Material
          AND plant                  = @<header>-Plant
          AND billofmaterialcomponent IS NOT INITIAL
          AND isproductionrelevant   = @abap_true
          AND isdeleted              = @abap_false
        INTO @DATA(lv_live_count).

      IF lv_live_count <> lv_existing_count AND <header>-BomCheckAck <> abap_true.
        APPEND VALUE #( %tky = <header>-%tky ) TO failed-ratesheetheader.
        APPEND VALUE #(
          %tky = <header>-%tky
          %msg = new_message( id       = 'ZRATESHEET'
                              number   = '010'
                              severity = if_abap_behv_message=>severity-error )
        ) TO reported-ratesheetheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD recreateratesheet.
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        FIELDS ( RateSheetUUID Material Plant )
        WITH CORRESPONDING #( keys )
      RESULT DATA(headers).

    IF headers IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader BY \_Item
        FIELDS ( RateSheetItemUUID )
        WITH CORRESPONDING #( headers )
      RESULT DATA(existing_items).

    IF existing_items IS NOT INITIAL.
      DATA lt_item_deletes TYPE TABLE FOR DELETE zi_rsh_item.
      lt_item_deletes = CORRESPONDING #( existing_items ).

      MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
        ENTITY RateSheetItem
          DELETE
          FROM lt_item_deletes.
    ENDIF.

    DATA lt_reset TYPE TABLE FOR UPDATE zi_rsh_header.
    lt_reset = VALUE #( FOR h IN headers (
      %tky          = h-%tky
      BomExplodedAt = VALUE #( )
      BomCheckAck   = space
    ) ).

    MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        UPDATE FIELDS ( BomExplodedAt BomCheckAck )
        WITH lt_reset.

    " Re-trigger explodeBom/deriveEligibleVendors: the determination is
    " keyed off Material/Plant being set on modify, so re-supplying the
    " same values causes the framework to re-run it from scratch on the
    " now-empty _Item association.
    DATA lt_retrigger TYPE TABLE FOR UPDATE zi_rsh_header.
    lt_retrigger = VALUE #( FOR h IN headers (
      %tky     = h-%tky
      Material = h-Material
      Plant    = h-Plant
    ) ).

    MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        UPDATE FIELDS ( Material Plant )
        WITH lt_retrigger.

    result = VALUE #( FOR h IN headers (
      %tky   = h-%tky
      %param = CORRESPONDING #( h )
    ) ).

    reported-ratesheetheader = VALUE #( FOR h IN headers (
      %tky = h-%tky
      %msg = new_message( id       = 'ZRATESHEET'
                          number   = '019'
                          severity = if_abap_behv_message=>severity-information )
    ) ).
  ENDMETHOD.

  METHOD checkbom.
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        FIELDS ( RateSheetUUID Material Plant )
        WITH CORRESPONDING #( keys )
      RESULT DATA(headers).

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader BY \_Item
        FIELDS ( RateSheetUUID BomComponent IsIncluded IsManualLine )
        WITH CORRESPONDING #( headers )
      RESULT DATA(existing_items).

    " P-101: legacy BOM button - number of DISTINCT BOM components (STPO,
    " duplicates by IDNRK removed) must equal number of DISTINCT TICKED
    " rate-sheet components ('Cong !!! BOM MATCHED'). Manual lines excluded.
    DATA lt_check_comps TYPE SORTED TABLE OF zrsh_itm-bom_component WITH UNIQUE KEY table_line.

    LOOP AT headers ASSIGNING FIELD-SYMBOL(<header>).
      CLEAR lt_check_comps.
      LOOP AT existing_items ASSIGNING FIELD-SYMBOL(<check_row>)
        WHERE RateSheetUUID = <header>-RateSheetUUID
          AND BomComponent IS NOT INITIAL
          AND IsIncluded = abap_true
          AND IsManualLine = abap_false.
        INSERT <check_row>-BomComponent INTO TABLE lt_check_comps.
      ENDLOOP.
      DATA(lv_existing_count) = lines( lt_check_comps ).

      DATA(lv_live_count) = 0.
      IF <header>-Material IS NOT INITIAL AND <header>-Plant IS NOT INITIAL.
        SELECT COUNT( DISTINCT billofmaterialcomponent )
          FROM i_billofmaterialitemtp_2
          WHERE material               = @<header>-Material
            AND plant                  = @<header>-Plant
            AND billofmaterialcomponent IS NOT INITIAL
            AND isproductionrelevant   = @abap_true
            AND isdeleted              = @abap_false
          INTO @lv_live_count.
      ENDIF.

      result = VALUE #( BASE result (
        %tky   = <header>-%tky
        %param = CORRESPONDING #( <header> ) ) ).

      IF lv_live_count <> lv_existing_count.
        reported-ratesheetheader = VALUE #( BASE reported-ratesheetheader (
          %tky = <header>-%tky
          %msg = new_message( id       = 'ZRATESHEET'
                              number   = '010'
                              severity = if_abap_behv_message=>severity-warning ) ) ).
      ELSE.
        reported-ratesheetheader = VALUE #( BASE reported-ratesheetheader (
          %tky = <header>-%tky
          %msg = new_message( id       = 'ZRATESHEET'
                              number   = '022'
                              v1       = <header>-RateSheetUUID
                              severity = if_abap_behv_message=>severity-success ) ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD acknowledgebomchanges.
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        FIELDS ( RateSheetUUID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(headers).

    DATA lt_updates TYPE TABLE FOR UPDATE zi_rsh_header.
    lt_updates = VALUE #( FOR h IN headers (
      %tky        = h-%tky
      BomCheckAck = abap_true
    ) ).

    IF lt_updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
        ENTITY RateSheetHeader
          UPDATE FIELDS ( BomCheckAck )
          WITH lt_updates.
    ENDIF.

    result = VALUE #( FOR h IN headers (
      %tky   = h-%tky
      %param = CORRESPONDING #( h )
    ) ).
  ENDMETHOD.

  METHOD copyfromreference.
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        FIELDS ( RateSheetUUID ReferenceRateSheetNumber )
        WITH CORRESPONDING #( keys )
      RESULT DATA(headers).

    DATA lv_ref_uuid TYPE zrsh_hdr-rate_sheet_uuid.
    TYPES: BEGIN OF ty_ref_tick,
             bom_component TYPE zrsh_itm-bom_component,
             is_included   TYPE zrsh_itm-is_included,
           END OF ty_ref_tick.
    DATA lt_ref_ticks TYPE STANDARD TABLE OF ty_ref_tick WITH EMPTY KEY.

    LOOP AT headers ASSIGNING FIELD-SYMBOL(<header>).
      APPEND VALUE #(
        %tky   = <header>-%tky
        %param = CORRESPONDING #( <header> )
      ) TO result.

      IF <header>-ReferenceRateSheetNumber IS INITIAL.
        APPEND VALUE #(
          %tky = <header>-%tky
          %msg = new_message( id       = 'ZRATESHEET'
                              number   = '023'
                              severity = if_abap_behv_message=>severity-error )
        ) TO reported-ratesheetheader.
        CONTINUE.
      ENDIF.

      CLEAR lv_ref_uuid.
      SELECT rate_sheet_uuid
        FROM zrsh_hdr
        WHERE rate_sheet_number = @<header>-ReferenceRateSheetNumber
        ORDER BY rate_sheet_uuid
        INTO @lv_ref_uuid
        UP TO 1 ROWS.
      ENDSELECT.

      IF sy-subrc <> 0.
        APPEND VALUE #(
          %tky = <header>-%tky
          %msg = new_message( id       = 'ZRATESHEET'
                              number   = '024'
                              v1       = <header>-ReferenceRateSheetNumber
                              severity = if_abap_behv_message=>severity-error )
        ) TO reported-ratesheetheader.
        CONTINUE.
      ENDIF.

      CLEAR lt_ref_ticks.
      SELECT bom_component, is_included
        FROM zrsh_itm
        WHERE rate_sheet_uuid = @lv_ref_uuid
        INTO TABLE @lt_ref_ticks.

      IF lt_ref_ticks IS INITIAL.
        CONTINUE.
      ENDIF.

      READ ENTITIES OF zi_rsh_header IN LOCAL MODE
        ENTITY RateSheetHeader BY \_Item
          FIELDS ( RateSheetItemUUID BomComponent IsIncluded )
          WITH VALUE #( ( RateSheetUUID = <header>-RateSheetUUID ) )
        RESULT DATA(lt_current_items).

      DATA lt_tick_updates TYPE TABLE FOR UPDATE zi_rsh_item.
      CLEAR lt_tick_updates.

      LOOP AT lt_current_items ASSIGNING FIELD-SYMBOL(<cur_item>)
        WHERE BomComponent IS NOT INITIAL.
        READ TABLE lt_ref_ticks ASSIGNING FIELD-SYMBOL(<ref_tick>)
          WITH KEY bom_component = <cur_item>-BomComponent.
        IF sy-subrc = 0.
          APPEND VALUE #(
            %tky       = <cur_item>-%tky
            IsIncluded = <ref_tick>-is_included
          ) TO lt_tick_updates.
        ENDIF.
      ENDLOOP.

      IF lt_tick_updates IS NOT INITIAL.
        MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
          ENTITY RateSheetItem
            UPDATE FIELDS ( IsIncluded )
            WITH lt_tick_updates.
      ENDIF.

      APPEND VALUE #(
        %tky = <header>-%tky
        %msg = new_message( id       = 'ZRATESHEET'
                            number   = '021'
                            v1       = <header>-ReferenceRateSheetNumber
                            severity = if_abap_behv_message=>severity-success )
      ) TO reported-ratesheetheader.
    ENDLOOP.
  ENDMETHOD.

  METHOD createcontract.
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        FIELDS ( RateSheetUUID Plant )
        WITH CORRESPONDING #( keys )
      RESULT DATA(headers).

    IF headers IS NOT INITIAL.
      SELECT plant, auto_contract_create
        FROM zrsh_apopl
        FOR ALL ENTRIES IN @headers
        WHERE plant = @headers-Plant
        INTO TABLE @DATA(lt_apopl).
    ENDIF.

    LOOP AT headers ASSIGNING FIELD-SYMBOL(<header>).
      result = VALUE #( BASE result (
        %tky   = <header>-%tky
        %param = CORRESPONDING #( <header> ) ) ).

      READ TABLE lt_apopl ASSIGNING FIELD-SYMBOL(<apopl>)
        WITH KEY plant = <header>-Plant.
      IF sy-subrc = 0 AND <apopl>-auto_contract_create = abap_true.
        " Stub only - Q-038 (contract type/API/plant list) not yet confirmed.
        " Intentionally does not call a purchasing contract API and does not
        " write ContractNo, to avoid fabricating a contract number.
        reported-ratesheetheader = VALUE #( BASE reported-ratesheetheader (
          %tky = <header>-%tky
          %msg = new_message( id       = 'ZRATESHEET'
                              number   = '020'
                              severity = if_abap_behv_message=>severity-information ) ) ).
      ELSE.
        reported-ratesheetheader = VALUE #( BASE reported-ratesheetheader (
          %tky = <header>-%tky
          %msg = new_message( id       = 'ZRATESHEET'
                              number   = '025'
                              v1       = <header>-Plant
                              severity = if_abap_behv_message=>severity-information ) ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_features.
    " P-100/P-102: 'Add More Line' and 'Refresh' only while editing (draft), as in legacy ZR01.
    result = VALUE #( FOR key IN keys (
      %tky                = key-%tky
      %action-addMoreLine = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                    THEN if_abap_behv=>fc-o-enabled
                                    ELSE if_abap_behv=>fc-o-disabled )
      %action-refreshRateSheet = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                         THEN if_abap_behv=>fc-o-enabled
                                         ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD addmoreline.
    " P-100: legacy parity for ZMM_R_RATESHEET 'Add More Line' (&XPA, FORM
    " FLDCAT_INSERT) + 'Save More Line' (&ML):
    "   - user enters BOM Component, Qty (per assembly), UoM, Basic Amount
    "   - no vendor, no GST: Total Price = Total Cost = Basic Amount
    "   - Qty Required = Qty * PR qty, Vend. Ord. Qty = Qty Required
    "   - line is flagged manual (legacy red icon C_RED) -> BomStatus 'R'
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        FIELDS ( RateSheetUUID RequestedQuantity Currency )
        WITH CORRESPONDING #( keys )
      RESULT DATA(headers).

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader BY \_Item
        FIELDS ( RateSheetUUID SrNo BomComponent )
        WITH CORRESPONDING #( headers )
      RESULT DATA(items).

    DATA lt_create TYPE TABLE FOR CREATE zi_rsh_header\_Item.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      READ TABLE headers ASSIGNING FIELD-SYMBOL(<hdr>) WITH KEY %tky = <key>-%tky.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(lv_comp) = CONV zrsh_itm-bom_component(
        to_upper( condense( val = CONV string( <key>-%param-BomComponent ) ) ) ).
      DATA(lv_error) = VALUE string( ).

      IF lv_comp IS INITIAL OR <key>-%param-Qty <= 0.
        lv_error = 'Enter BOM Component and Qty.'.
      ELSEIF line_exists( items[ RateSheetUUID = <hdr>-RateSheetUUID BomComponent = lv_comp ] ).
        lv_error = |{ lv_comp } is already in the Price Engine. Split its quantity across vendors instead.|.
      ELSE.
        SELECT SINGLE product, baseunit
          FROM i_product
          WHERE product = @lv_comp
          INTO @DATA(ls_product).
        IF sy-subrc <> 0.
          lv_error = |Material { lv_comp } does not exist.|.
        ENDIF.
      ENDIF.

      IF lv_error IS NOT INITIAL.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-ratesheetheader.
        APPEND VALUE #( %tky = <key>-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = lv_error ) ) TO reported-ratesheetheader.
        CONTINUE.
      ENDIF.

      DATA(lv_next_sr) = REDUCE i( INIT m = 0
        FOR row IN items WHERE ( RateSheetUUID = <hdr>-RateSheetUUID )
        NEXT m = COND #( WHEN row-SrNo > m THEN row-SrNo ELSE m ) ) + 1.
      " keep SR NO / duplicate checks correct for further keys in this request
      APPEND VALUE #( RateSheetUUID = <hdr>-RateSheetUUID SrNo = lv_next_sr
                      BomComponent  = lv_comp ) TO items.

      DATA(lv_qty_req) = CONV zrsh_itm-qty_required( <key>-%param-Qty * <hdr>-RequestedQuantity ).

      READ TABLE lt_create ASSIGNING FIELD-SYMBOL(<create>) WITH KEY %tky = <hdr>-%tky.
      IF sy-subrc <> 0.
        APPEND INITIAL LINE TO lt_create ASSIGNING <create>.
        <create>-%tky = <hdr>-%tky.
      ENDIF.

      APPEND VALUE #(
        %cid           = |ML_{ lv_next_sr }_{ lv_comp }|
        %is_draft      = <hdr>-%is_draft
        SrNo           = lv_next_sr
        BomStatus      = 'R'
        BomComponent   = lv_comp
        BomQty         = CONV zrsh_itm-bom_qty( <key>-%param-Qty )
        BomUoM         = COND #( WHEN <key>-%param-UoM IS NOT INITIAL
                                 THEN <key>-%param-UoM ELSE ls_product-baseunit )
        QtyRequired    = lv_qty_req
        VendorOrderQty = lv_qty_req
        Currency       = COND #( WHEN <hdr>-Currency IS INITIAL THEN 'INR' ELSE <hdr>-Currency )
        BasicRate      = CONV zrsh_itm-basic_rate( <key>-%param-BasicAmount )
        ManualText     = <key>-%param-Description
        IsIncluded     = abap_true
        IsManualLine   = abap_true
        ItemStatus     = 'D'
      ) TO <create>-%target.

      APPEND VALUE #( %tky = <key>-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-success
                               text     = |More line { lv_comp } added (SR NO { lv_next_sr }).| ) )
        TO reported-ratesheetheader.
    ENDLOOP.

    IF lt_create IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
        ENTITY RateSheetHeader
          CREATE BY \_Item
          FIELDS ( SrNo BomStatus BomComponent BomQty BomUoM QtyRequired VendorOrderQty
                   Currency BasicRate ManualText IsIncluded IsManualLine ItemStatus )
          WITH lt_create
        FAILED DATA(ls_create_failed)
        REPORTED DATA(ls_create_reported).
    ENDIF.

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(result_headers).

    result = VALUE #( FOR h IN result_headers ( %tky = h-%tky %param = CORRESPONDING #( h ) ) ).
  ENDMETHOD.

  METHOD refreshratesheet.
    " P-102: legacy REFRESH (l.1224 / 2101): DELETE IT_FINAL WHERE TICK NE 'X'.
    " Removes unticked vendor rows (and their kit/raw children via the
    " composition) from the draft Price Engine.
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(headers).

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader BY \_Item
        FIELDS ( RateSheetItemUUID IsIncluded )
        WITH CORRESPONDING #( headers )
      RESULT DATA(items).

    DATA lt_deletes TYPE TABLE FOR DELETE zi_rsh_item.
    LOOP AT items ASSIGNING FIELD-SYMBOL(<it>) WHERE IsIncluded = abap_false.
      APPEND VALUE #( %tky = <it>-%tky ) TO lt_deletes.
    ENDLOOP.

    IF lt_deletes IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
        ENTITY RateSheetItem DELETE FROM lt_deletes.
    ENDIF.

    result = VALUE #( FOR h IN headers ( %tky = h-%tky %param = CORRESPONDING #( h ) ) ).
    reported-ratesheetheader = VALUE #( FOR h IN headers (
      %tky = h-%tky
      %msg = new_message_with_text(
               severity = if_abap_behv_message=>severity-success
               text     = |{ lines( lt_deletes ) } unticked row(s) removed from the Price Engine.| ) ) ).
  ENDMETHOD.

ENDCLASS.

CLASS lhc_ratesheetitem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS dropuntickedrows FOR DETERMINE ON SAVE
      IMPORTING keys FOR RateSheetItem~dropUntickedRows.

    METHODS checkvendorqtyallocation FOR VALIDATE ON SAVE
      IMPORTING keys FOR RateSheetItem~checkVendorQtyAllocation.


    METHODS deriveeligiblevendors FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ratesheetitem~deriveeligiblevendors.
    METHODS explodekitbom FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ratesheetitem~explodekitbom.

ENDCLASS.

CLASS lhc_ratesheetitem IMPLEMENTATION.

  METHOD deriveeligiblevendors.
  READ ENTITIES OF zi_rsh_header IN LOCAL MODE
    ENTITY RateSheetItem
      FIELDS ( RateSheetUUID SrNo BomStatus BomComponent BomUoM BomQty QtyRequired
               VendorCode VendorName VendorOrderQty Currency BasicRate
               IgstPct IgstAmt CgstPct CgstAmt SgstPct SgstAmt UgstPct UgstAmt
               TaxValue TotalPrice PayDay Modvat TotalCost TotalValue AverageRate
               IsIncluded IsManualLine ManualText ItemStatus BomItemNode
               IsRateFromKit QuotedBasicRate TaxCode InfoRecord IsAvgRateRow )
      WITH CORRESPONDING #( keys )
    RESULT DATA(trigger_items).

  IF trigger_items IS INITIAL.
    RETURN.
  ENDIF.

  READ ENTITIES OF zi_rsh_header IN LOCAL MODE
    ENTITY RateSheetItem BY \_Header
      FIELDS ( RateSheetUUID Plant PurchasingOrg RequestedQuantity Currency )
      WITH CORRESPONDING #( trigger_items )
    RESULT DATA(headers).

  IF headers IS INITIAL.
    RETURN.
  ENDIF.

  READ ENTITIES OF zi_rsh_header IN LOCAL MODE
    ENTITY RateSheetHeader BY \_Item
      FIELDS ( RateSheetUUID SrNo BomStatus BomComponent BomUoM BomQty QtyRequired
               VendorCode VendorName VendorOrderQty Currency BasicRate
               IgstPct IgstAmt CgstPct CgstAmt SgstPct SgstAmt UgstPct UgstAmt
               TaxValue TotalPrice PayDay Modvat TotalCost TotalValue AverageRate
               IsIncluded IsManualLine ManualText ItemStatus BomItemNode
               IsRateFromKit QuotedBasicRate TaxCode InfoRecord IsAvgRateRow )
      WITH CORRESPONDING #( headers )
    RESULT DATA(all_items).

  TYPES: BEGIN OF ty_comp_plant,
           material TYPE i_purchasinginforecordapi01-material,
           plant    TYPE i_purginforecdorgplntdataapi01-plant,
         END OF ty_comp_plant.
  DATA lt_comp_plants TYPE SORTED TABLE OF ty_comp_plant
    WITH UNIQUE KEY material plant.

  LOOP AT all_items ASSIGNING FIELD-SYMBOL(<item>)
    WHERE BomComponent IS NOT INITIAL.
    READ TABLE headers ASSIGNING FIELD-SYMBOL(<header>)
      WITH KEY RateSheetUUID = <item>-RateSheetUUID.
    IF sy-subrc = 0 AND <header>-Plant IS NOT INITIAL.
      INSERT VALUE #(
        material = <item>-BomComponent
        plant    = <header>-Plant ) INTO TABLE lt_comp_plants.
    ENDIF.
  ENDLOOP.

  TYPES: BEGIN OF ty_vendor,
           material             TYPE i_purchasinginforecordapi01-material,
           plant                TYPE i_purginforecdorgplntdataapi01-plant,
           supplier             TYPE i_purchasinginforecordapi01-supplier,
           suppliername         TYPE i_supplier-suppliername,
           nodaysreminder1      TYPE i_purchasinginforecordapi01-nodaysreminder1,
           currency             TYPE i_purginforecdorgplntdataapi01-currency,
           taxcode              TYPE i_purginforecdorgplntdataapi01-taxcode,
           purchasinginforecord TYPE i_purchasinginforecordapi01-purchasinginforecord,
         END OF ty_vendor.
  DATA lt_vendors TYPE STANDARD TABLE OF ty_vendor WITH DEFAULT KEY.

  IF lt_comp_plants IS NOT INITIAL.
    SELECT info~material,
           org~plant,
           info~supplier,
           sup~suppliername,
           info~nodaysreminder1,
           org~currency,
           org~taxcode,
           info~purchasinginforecord
      FROM i_purchasinginforecordapi01 AS info
      INNER JOIN i_purginforecdorgplntdataapi01 AS org
        ON info~purchasinginforecord = org~purchasinginforecord
      LEFT OUTER JOIN i_supplier AS sup
        ON info~supplier = sup~supplier
      FOR ALL ENTRIES IN @lt_comp_plants
      WHERE info~material             = @lt_comp_plants-material
        AND org~plant                 = @lt_comp_plants-plant
        AND info~isdeleted            = @abap_false
        AND org~ismarkedfordeletion   = @abap_false
      INTO TABLE @lt_vendors.
  ENDIF.

  SORT lt_vendors BY material plant purchasinginforecord supplier.
  DELETE ADJACENT DUPLICATES FROM lt_vendors
    COMPARING material plant supplier purchasinginforecord.

  DATA lt_identity_updates TYPE TABLE FOR UPDATE zi_rsh_item.
  DATA lt_create_items TYPE TABLE FOR CREATE zi_rsh_header\_Item.
  DATA lv_next_sr_no TYPE i.

  " This loop is scoped to items whose VendorCode is still blank - once set,
  " this loop can never re-fire for the same item (WHERE VendorCode IS INITIAL),
  " so no recursion risk from this part of the method.
  LOOP AT all_items ASSIGNING <item> WHERE VendorCode IS INITIAL
                                      AND BomComponent IS NOT INITIAL
                                      AND IsManualLine = abap_false.
    READ TABLE headers ASSIGNING <header>
      WITH KEY RateSheetUUID = <item>-RateSheetUUID.
    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    lv_next_sr_no = REDUCE i( INIT maximum = 0
      FOR sibling IN all_items
      WHERE ( RateSheetUUID = <item>-RateSheetUUID )
      NEXT maximum = COND #( WHEN sibling-SrNo > maximum
                             THEN sibling-SrNo ELSE maximum ) ).

    DATA(lv_candidate_index) = 0.
    LOOP AT lt_vendors ASSIGNING FIELD-SYMBOL(<vendor>)
      WHERE material = <item>-BomComponent
        AND plant    = <header>-Plant.
      lv_candidate_index += 1.

      IF lv_candidate_index = 1.
        APPEND VALUE #(
          %tky        = <item>-%tky
          VendorCode  = <vendor>-supplier
          VendorName  = <vendor>-suppliername
          PayDay      = <vendor>-nodaysreminder1
          InfoRecord  = <vendor>-purchasinginforecord
          TaxCode     = <vendor>-taxcode
          Currency    = COND #( WHEN <vendor>-currency IS INITIAL
                                THEN <header>-Currency ELSE <vendor>-currency )
        ) TO lt_identity_updates.
      ELSE.
        READ TABLE all_items TRANSPORTING NO FIELDS
          WITH KEY RateSheetUUID = <item>-RateSheetUUID
                   BomComponent  = <item>-BomComponent
                   VendorCode    = <vendor>-supplier.
        IF sy-subrc = 0.
          CONTINUE.
        ENDIF.

        lv_next_sr_no += 1.
        READ TABLE lt_create_items ASSIGNING FIELD-SYMBOL(<create_header>)
          WITH KEY %tky = <header>-%tky.
        IF sy-subrc <> 0.
          APPEND INITIAL LINE TO lt_create_items ASSIGNING <create_header>.
          <create_header>-%tky = <header>-%tky.
        ENDIF.

        APPEND VALUE #(
          %cid           = |VENDOR_{ <item>-BomItemNode }_{ <vendor>-purchasinginforecord }|
          %is_draft      = <header>-%is_draft
          SrNo           = lv_next_sr_no
          BomStatus      = <item>-BomStatus
          BomComponent   = <item>-BomComponent
          BomQty         = <item>-BomQty
          BomUoM         = <item>-BomUoM
          QtyRequired    = <item>-QtyRequired
          VendorCode     = <vendor>-supplier
          VendorName     = <vendor>-suppliername
          VendorOrderQty = 0
          Currency       = COND #( WHEN <vendor>-currency IS INITIAL
                                   THEN <header>-Currency ELSE <vendor>-currency )
          PayDay         = <vendor>-nodaysreminder1
          InfoRecord     = <vendor>-purchasinginforecord
          TaxCode        = <vendor>-taxcode
          BomItemNode    = <item>-BomItemNode
          IsIncluded     = abap_true
          ItemStatus     = 'D'
        ) TO <create_header>-%target.
      ENDIF.
    ENDLOOP.
  ENDLOOP.

  IF lt_identity_updates IS NOT INITIAL.
    MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetItem
        UPDATE FIELDS ( VendorCode VendorName PayDay InfoRecord TaxCode Currency )
        WITH lt_identity_updates.
  ENDIF.

  DELETE lt_create_items WHERE %target IS INITIAL.
  IF lt_create_items IS NOT INITIAL.
    MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        CREATE BY \_Item
        FIELDS ( SrNo BomStatus BomComponent BomQty BomUoM QtyRequired
                 VendorCode VendorName VendorOrderQty Currency PayDay InfoRecord
                 TaxCode BomItemNode IsIncluded ItemStatus )
        WITH lt_create_items.
  ENDIF.

  " Re-read the current persisted calculation fields too, so the idempotency
  " comparison below has a genuine "before" snapshot to compare against.
  READ ENTITIES OF zi_rsh_header IN LOCAL MODE
    ENTITY RateSheetHeader BY \_Item
      FIELDS ( RateSheetUUID SrNo BomComponent VendorCode VendorOrderQty QtyRequired
               Currency IsIncluded IsRateFromKit QuotedBasicRate TaxCode InfoRecord
               BasicRate IgstPct IgstAmt CgstPct CgstAmt SgstPct SgstAmt UgstPct UgstAmt
               TaxValue TotalPrice Modvat TotalCost TotalValue AverageRate IsAvgRateRow
               IsManualLine )
      WITH CORRESPONDING #( headers )
    RESULT DATA(pricing_items).

  TYPES: BEGIN OF ty_info_key,
           purchasinginforecord TYPE i_purginforecdorgplntdataapi01-purchasinginforecord,
           plant                TYPE i_purginforecdorgplntdataapi01-plant,
         END OF ty_info_key.
  DATA lt_info_keys TYPE SORTED TABLE OF ty_info_key
    WITH UNIQUE KEY purchasinginforecord plant.

  LOOP AT pricing_items ASSIGNING FIELD-SYMBOL(<pricing_item>)
    WHERE InfoRecord IS NOT INITIAL.
    READ TABLE headers ASSIGNING <header>
      WITH KEY RateSheetUUID = <pricing_item>-RateSheetUUID.
    IF sy-subrc = 0.
      INSERT VALUE #(
        purchasinginforecord = <pricing_item>-InfoRecord
        plant                = <header>-Plant ) INTO TABLE lt_info_keys.
    ENDIF.
  ENDLOOP.

  IF lt_info_keys IS NOT INITIAL.
    SELECT purchasinginforecord,
           plant,
           conditionrecord,
           conditiontype,
           conditionratevalue,
           conditionratevalueunit
      FROM i_purginforecdCndnRecordTP
      FOR ALL ENTRIES IN @lt_info_keys
      WHERE purchasinginforecord = @lt_info_keys-purchasinginforecord
        AND plant                = @lt_info_keys-plant
        AND conditionvalidityenddate = '99991231'
        AND conditionisdeleted   = @abap_false
      INTO TABLE @DATA(lt_conditions).
  ENDIF.

  SORT lt_conditions BY conditiontype purchasinginforecord plant conditionrecord.

  DATA lt_calculations TYPE TABLE FOR UPDATE zi_rsh_item.

  LOOP AT pricing_items ASSIGNING <pricing_item>.
    DATA(lv_currency) = <pricing_item>-Currency.
    DATA(lv_basic_rate) = CONV zrsh_itm-basic_rate( 0 ).
    DATA(lv_igst_pct) = CONV zrsh_itm-igst_pct( 0 ).
    DATA(lv_cgst_pct) = CONV zrsh_itm-cgst_pct( 0 ).
    DATA(lv_sgst_pct) = CONV zrsh_itm-sgst_pct( 0 ).
    DATA(lv_ugst_pct) = CONV zrsh_itm-ugst_pct( 0 ).
    " P-101: legacy KSCHL4 - ZE20 freight rate added flat to T_COST
    " (legacy line 570: T_COST = T_PRI - M_AMT + KSCHL4), see Q-039
    DATA(lv_freight) = CONV zrsh_itm-total_cost( 0 ).
    DATA(lv_keep_tax) = abap_false.

    IF <pricing_item>-IsManualLine = abap_false.
      LOOP AT lt_conditions ASSIGNING FIELD-SYMBOL(<condition>)
        WHERE purchasinginforecord = <pricing_item>-InfoRecord.
        CASE <condition>-conditiontype.
          WHEN 'ZP00'.
            lv_basic_rate = <condition>-conditionratevalue.
            IF <condition>-conditionratevalueunit IS NOT INITIAL.
              lv_currency = <condition>-conditionratevalueunit.
            ENDIF.
          WHEN 'ZE01' OR 'ZE02' OR 'ZE43' OR 'ZE47'.
            lv_igst_pct = <condition>-conditionratevalue / 10.
          WHEN 'ZE05' OR 'ZE06' OR 'ZE42' OR 'ZE46'.
            lv_cgst_pct = <condition>-conditionratevalue / 10.
          WHEN 'ZE10' OR 'ZE11' OR 'ZE41' OR 'ZE45'.
            lv_sgst_pct = <condition>-conditionratevalue / 10.
          WHEN 'ZE44' OR 'ZE48'.
            lv_ugst_pct = <condition>-conditionratevalue / 10.
          WHEN 'ZE20'.
            lv_freight = <condition>-conditionratevalue.
        ENDCASE.
      ENDLOOP.
    ENDIF.

    IF <pricing_item>-IsManualLine = abap_true.
      " P-100: legacy 'More Line' - Basic Amount as entered, no GST
      lv_basic_rate = <pricing_item>-BasicRate.
    ELSEIF <pricing_item>-IsRateFromKit = abap_true.
      " P-101 fix: BasicRate already holds the rolled-up kit cost
      " (rollUpKitToMainGrid); QuotedBasicRate is only the snapshot of the
      " original quote. Legacy PARK/E14: GST is NOT recomputed on roll-up.
      lv_basic_rate = <pricing_item>-BasicRate.
      lv_keep_tax   = abap_true.
    ENDIF.

    DATA(lv_igst_amt) = CONV zrsh_itm-igst_amt(
      lv_basic_rate * lv_igst_pct / 100 ).
    DATA(lv_cgst_amt) = CONV zrsh_itm-cgst_amt(
      lv_basic_rate * lv_cgst_pct / 100 ).
    DATA(lv_sgst_amt) = CONV zrsh_itm-sgst_amt(
      lv_basic_rate * lv_sgst_pct / 100 ).
    DATA(lv_ugst_amt) = CONV zrsh_itm-ugst_amt(
      lv_basic_rate * lv_ugst_pct / 100 ).

    IF lv_cgst_pct IS NOT INITIAL.
      lv_cgst_amt = ( lv_basic_rate + lv_igst_amt ) * lv_cgst_pct / 100.
    ELSEIF lv_sgst_pct IS NOT INITIAL.
      lv_sgst_amt = ( lv_basic_rate + lv_igst_amt ) * lv_sgst_pct / 100.
    ENDIF.

    IF lv_keep_tax = abap_true.
      lv_igst_pct = <pricing_item>-IgstPct.
      lv_cgst_pct = <pricing_item>-CgstPct.
      lv_sgst_pct = <pricing_item>-SgstPct.
      lv_ugst_pct = <pricing_item>-UgstPct.
      lv_igst_amt = <pricing_item>-IgstAmt.
      lv_cgst_amt = <pricing_item>-CgstAmt.
      lv_sgst_amt = <pricing_item>-SgstAmt.
      lv_ugst_amt = <pricing_item>-UgstAmt.
    ENDIF.

    DATA(lv_tax_value) = CONV zrsh_itm-tax_value(
      lv_igst_amt + lv_cgst_amt + lv_sgst_amt + lv_ugst_amt ).
    DATA(lv_total_price) = CONV zrsh_itm-total_price(
      lv_basic_rate + lv_tax_value ).
    DATA(lv_modvat) = CONV zrsh_itm-modvat(
      lv_igst_amt + lv_cgst_amt + lv_sgst_amt + lv_ugst_amt ).
    DATA(lv_total_cost) = CONV zrsh_itm-total_cost(
      lv_total_price - lv_modvat + lv_freight ).
    DATA(lv_order_qty) = COND zrsh_itm-vendor_order_qty(
      WHEN <pricing_item>-VendorOrderQty IS INITIAL
       AND <pricing_item>-VendorCode IS INITIAL
      THEN <pricing_item>-QtyRequired
      ELSE <pricing_item>-VendorOrderQty ).
    DATA(lv_total_value) = CONV zrsh_itm-total_value(
      lv_total_cost * lv_order_qty ).

    APPEND VALUE #(
      %tky          = <pricing_item>-%tky
      RateSheetUUID = <pricing_item>-RateSheetUUID
      BomComponent  = <pricing_item>-BomComponent
      SrNo          = <pricing_item>-SrNo
      IsIncluded    = <pricing_item>-IsIncluded
      IsManualLine  = <pricing_item>-IsManualLine
      Currency      = COND #( WHEN lv_currency IS INITIAL THEN 'INR' ELSE lv_currency )
      BasicRate     = lv_basic_rate
      IgstPct       = lv_igst_pct
      IgstAmt       = lv_igst_amt
      CgstPct       = lv_cgst_pct
      CgstAmt       = lv_cgst_amt
      SgstPct       = lv_sgst_pct
      SgstAmt       = lv_sgst_amt
      UgstPct       = lv_ugst_pct
      UgstAmt       = lv_ugst_amt
      TaxValue      = lv_tax_value
      TotalPrice    = lv_total_price
      Modvat        = lv_modvat
      TotalCost     = lv_total_cost
      TotalValue    = lv_total_value
    ) TO lt_calculations.
  ENDLOOP.

  SORT lt_calculations BY RateSheetUUID BomComponent SrNo.
  LOOP AT lt_calculations ASSIGNING FIELD-SYMBOL(<calculation>).
    READ TABLE headers ASSIGNING <header>
      WITH KEY RateSheetUUID = <calculation>-RateSheetUUID.
    IF sy-subrc <> 0 OR <header>-RequestedQuantity IS INITIAL.
      CONTINUE.
    ENDIF.

    READ TABLE lt_calculations TRANSPORTING NO FIELDS
      WITH KEY RateSheetUUID = <calculation>-RateSheetUUID
               BomComponent  = <calculation>-BomComponent
               IsAvgRateRow  = abap_true.
    IF sy-subrc = 0.
      CONTINUE.
    ENDIF.

    DATA(lv_group_total) = REDUCE zrsh_itm-total_value(
      INIT total = CONV zrsh_itm-total_value( 0 )
      FOR row IN lt_calculations
      WHERE ( RateSheetUUID = <calculation>-RateSheetUUID
              AND BomComponent = <calculation>-BomComponent
              AND IsIncluded = abap_true
              " P-101: legacy ZAVG excludes red-icon (manual) rows
              " (ICON NE '@0A@'); a manual line averages only itself (&ML)
              AND IsManualLine = <calculation>-IsManualLine )
      NEXT total = total + row-TotalValue ).

    <calculation>-AverageRate = lv_group_total / <header>-RequestedQuantity.
    <calculation>-IsAvgRateRow = abap_true.
  ENDLOOP.

  " Idempotency guard (fixes P-034): BasicRate/TaxValue/etc are on-modify
  " trigger fields. Writing them even with an unchanged value re-triggers
  " this very determination, and for components with multiple vendor rows
  " the framework's recursion-depth guard eventually aborts with
  " LCX_ABAP_BEHV_DETVAL_ERROR ("stack of on-modify determinations too
  " deep"). Only issue the UPDATE for rows whose computed values actually
  " differ from what is already persisted, so a second/third invocation of
  " this determination (triggered by its own prior write) converges to a
  " true no-op and the recursion stops.
  DATA lt_real_updates TYPE TABLE FOR UPDATE zi_rsh_item.

  LOOP AT lt_calculations ASSIGNING <calculation>.
    READ TABLE pricing_items ASSIGNING <pricing_item>
      WITH KEY %tky = <calculation>-%tky.
    IF sy-subrc <> 0.
      APPEND <calculation> TO lt_real_updates.
      CONTINUE.
    ENDIF.

    IF <pricing_item>-Currency     <> <calculation>-Currency
      OR <pricing_item>-BasicRate    <> <calculation>-BasicRate
      OR <pricing_item>-IgstPct      <> <calculation>-IgstPct
      OR <pricing_item>-IgstAmt      <> <calculation>-IgstAmt
      OR <pricing_item>-CgstPct      <> <calculation>-CgstPct
      OR <pricing_item>-CgstAmt      <> <calculation>-CgstAmt
      OR <pricing_item>-SgstPct      <> <calculation>-SgstPct
      OR <pricing_item>-SgstAmt      <> <calculation>-SgstAmt
      OR <pricing_item>-UgstPct      <> <calculation>-UgstPct
      OR <pricing_item>-UgstAmt      <> <calculation>-UgstAmt
      OR <pricing_item>-TaxValue     <> <calculation>-TaxValue
      OR <pricing_item>-TotalPrice   <> <calculation>-TotalPrice
      OR <pricing_item>-Modvat       <> <calculation>-Modvat
      OR <pricing_item>-TotalCost    <> <calculation>-TotalCost
      OR <pricing_item>-TotalValue   <> <calculation>-TotalValue
      OR <pricing_item>-AverageRate  <> <calculation>-AverageRate
      OR <pricing_item>-IsAvgRateRow <> <calculation>-IsAvgRateRow.
      APPEND <calculation> TO lt_real_updates.
    ENDIF.
  ENDLOOP.

  IF lt_real_updates IS NOT INITIAL.
    MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetItem
        UPDATE FIELDS ( Currency BasicRate IgstPct IgstAmt CgstPct CgstAmt
                        SgstPct SgstAmt UgstPct UgstAmt TaxValue TotalPrice
                        Modvat TotalCost TotalValue AverageRate IsAvgRateRow )
        WITH lt_real_updates.
  ENDIF.
  ENDMETHOD.

METHOD explodeKitBom.
READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetItem
        FIELDS ( RateSheetUUID RateSheetItemUUID BomComponent BomStatus QtyRequired VendorOrderQty IsManualLine )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_header_keys TYPE TABLE FOR READ IMPORT zi_rsh_header.
    lt_header_keys = CORRESPONDING #( lt_items MAPPING RateSheetUUID = RateSheetUUID ).
    SORT lt_header_keys BY RateSheetUUID.
    DELETE ADJACENT DUPLICATES FROM lt_header_keys COMPARING RateSheetUUID.

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader
        FIELDS ( RateSheetUUID Plant )
        WITH lt_header_keys
      RESULT DATA(lt_headers).

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetItem BY \_KitCostingItem
        FIELDS ( RateSheetItemUUID BomComponent )
        WITH CORRESPONDING #( lt_items )
      RESULT DATA(lt_existing_kits).

    TYPES: BEGIN OF ty_mat_plant,
             material TYPE i_billofmaterialitemtp_2-material,
             plant    TYPE i_billofmaterialitemtp_2-plant,
           END OF ty_mat_plant.

    DATA lt_mat_plant TYPE STANDARD TABLE OF ty_mat_plant WITH EMPTY KEY.

    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<item>).
      IF <item>-BomComponent IS INITIAL OR <item>-IsManualLine = abap_true.
        CONTINUE.
      ENDIF.
      IF line_exists( lt_existing_kits[ RateSheetItemUUID = <item>-RateSheetItemUUID ] ).
        CONTINUE.
      ENDIF.

      READ TABLE lt_headers ASSIGNING FIELD-SYMBOL(<hdr>)
        WITH KEY RateSheetUUID = <item>-RateSheetUUID.
      IF sy-subrc = 0 AND <hdr>-Plant IS NOT INITIAL.
        APPEND VALUE #( material = <item>-BomComponent plant = <hdr>-Plant ) TO lt_mat_plant.
      ENDIF.
    ENDLOOP.

    IF lt_mat_plant IS INITIAL.
      RETURN.
    ENDIF.

    SORT lt_mat_plant BY material plant.
    DELETE ADJACENT DUPLICATES FROM lt_mat_plant COMPARING material plant.

    SELECT material, plant, billofmaterialcomponent, billofmaterialitemquantity,
           billofmaterialitemunit
      FROM i_billofmaterialitemtp_2
      FOR ALL ENTRIES IN @lt_mat_plant
      WHERE material               = @lt_mat_plant-material
        AND plant                  = @lt_mat_plant-plant
        AND billofmaterialcomponent IS NOT INITIAL
        AND isproductionrelevant   = @abap_true
        AND isdeleted              = @abap_false
      INTO TABLE @DATA(lt_bom_children).

    IF lt_bom_children IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_child_mat,
             material TYPE i_billofmaterialitemtp_2-material,
             plant    TYPE i_billofmaterialitemtp_2-plant,
           END OF ty_child_mat.
    DATA lt_child_mats TYPE STANDARD TABLE OF ty_child_mat WITH EMPTY KEY.

    LOOP AT lt_bom_children ASSIGNING FIELD-SYMBOL(<child>).
      APPEND VALUE #( material = <child>-billofmaterialcomponent plant = <child>-plant ) TO lt_child_mats.
    ENDLOOP.
    SORT lt_child_mats BY material plant.
    DELETE ADJACENT DUPLICATES FROM lt_child_mats COMPARING material plant.

    IF lt_child_mats IS NOT INITIAL.
      SELECT DISTINCT material, plant
        FROM i_billofmaterialitemtp_2
        FOR ALL ENTRIES IN @lt_child_mats
        WHERE material               = @lt_child_mats-material
          AND plant                  = @lt_child_mats-plant
          AND billofmaterialcomponent IS NOT INITIAL
          AND isproductionrelevant   = @abap_true
          AND isdeleted              = @abap_false
        INTO TABLE @DATA(lt_sub_boms).
    ENDIF.

    DATA lt_create_kits TYPE TABLE FOR CREATE zi_rsh_item\_KitCostingItem.

    LOOP AT lt_items ASSIGNING <item>.
      IF <item>-BomComponent IS INITIAL OR <item>-IsManualLine = abap_true.
        CONTINUE.
      ENDIF.
      IF line_exists( lt_existing_kits[ RateSheetItemUUID = <item>-RateSheetItemUUID ] ).
        CONTINUE.
      ENDIF.

      READ TABLE lt_headers ASSIGNING <hdr>
        WITH KEY RateSheetUUID = <item>-RateSheetUUID.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(lv_sr_no) = 0.
      APPEND INITIAL LINE TO lt_create_kits ASSIGNING FIELD-SYMBOL(<create_kit>).
      <create_kit>-%tky = <item>-%tky.

      LOOP AT lt_bom_children ASSIGNING <child>
        WHERE material = <item>-BomComponent
          AND plant    = <hdr>-Plant.

        lv_sr_no += 1.

        DATA(lv_qty_req) = CONV zrsh_kit-qty_required( <child>-billofmaterialitemquantity * <item>-VendorOrderQty ).
        IF lv_qty_req IS INITIAL.
          lv_qty_req = CONV zrsh_kit-qty_required( <child>-billofmaterialitemquantity * <item>-QtyRequired ).
        ENDIF.

        DATA(lv_has_sub) = COND abap_boolean(
          WHEN line_exists( lt_sub_boms[ material = <child>-billofmaterialcomponent plant = <child>-plant ] )
          THEN abap_true ELSE abap_false ).

        APPEND VALUE #(
          %cid                = |KIT_{ <item>-RateSheetItemUUID }_{ lv_sr_no }|
          %is_draft           = <item>-%is_draft
          RateSheetUUID       = <item>-RateSheetUUID
          RateSheetItemUUID   = <item>-RateSheetItemUUID
          SrNo                = lv_sr_no
          BomComponent        = <child>-billofmaterialcomponent
          UoM                 = <child>-billofmaterialitemunit
          Qty                 = <child>-billofmaterialitemquantity
          QtyRequired         = lv_qty_req
          VendorOrderQty      = lv_qty_req
          Pcwtgms             = <child>-billofmaterialitemquantity
          Rcost               = '1.00'
          WeightFactor        = 1000
          HasFurtherBom       = lv_has_sub
          IsSelectedComponent = abap_false
        ) TO <create_kit>-%target.
      ENDLOOP.

      IF <create_kit>-%target IS INITIAL.
        DELETE lt_create_kits INDEX lines( lt_create_kits ).
      ENDIF.
    ENDLOOP.

    IF lt_create_kits IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
        ENTITY RateSheetItem
          CREATE BY \_KitCostingItem
          FIELDS ( RateSheetUUID RateSheetItemUUID SrNo BomComponent UoM Qty QtyRequired
                   VendorOrderQty Pcwtgms Rcost WeightFactor HasFurtherBom IsSelectedComponent )
          WITH lt_create_kits.
    ENDIF.
  ENDMETHOD.

  METHOD checkvendorqtyallocation.
    " P-100: legacy parity for ZMM_R_RATESHEET CHECK / SAVE1:
    "   - sum of Vend. Ord. Qty of all vendor rows of a component must not
    "     exceed Qty Required ('No Change in quantity of <component>')
    "   - ticked total must equal Qty Required ('Check vendor order qty for
    "     BOM Component <component>'); legacy refused to save such rows
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetItem
        FIELDS ( RateSheetUUID BomComponent )
        WITH CORRESPONDING #( keys )
      RESULT DATA(trigger_items).

    IF trigger_items IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetItem BY \_Header
        FIELDS ( RateSheetUUID )
        WITH CORRESPONDING #( trigger_items )
      RESULT DATA(headers).

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader BY \_Item
        FIELDS ( RateSheetUUID BomComponent QtyRequired VendorOrderQty IsIncluded )
        WITH CORRESPONDING #( headers )
      RESULT DATA(all_items).

    TYPES: BEGIN OF ty_comp,
             rate_sheet_uuid TYPE zrsh_itm-rate_sheet_uuid,
             bom_component   TYPE zrsh_itm-bom_component,
           END OF ty_comp.
    DATA lt_comps TYPE SORTED TABLE OF ty_comp WITH UNIQUE KEY rate_sheet_uuid bom_component.

    LOOP AT trigger_items ASSIGNING FIELD-SYMBOL(<trigger>) WHERE BomComponent IS NOT INITIAL.
      INSERT VALUE #( rate_sheet_uuid = <trigger>-RateSheetUUID
                      bom_component   = <trigger>-BomComponent ) INTO TABLE lt_comps.
      " clear previous state messages of this check
      APPEND VALUE #( %tky        = <trigger>-%tky
                      %state_area = 'QTY_ALLOCATION' ) TO reported-ratesheetitem.
    ENDLOOP.

    LOOP AT lt_comps ASSIGNING FIELD-SYMBOL(<comp>).
      DATA(lv_required)  = CONV zrsh_itm-qty_required( 0 ).
      DATA(lv_all_qty)   = CONV zrsh_itm-vendor_order_qty( 0 ).
      DATA(lv_ticked)    = CONV zrsh_itm-vendor_order_qty( 0 ).
      DATA(lv_has_tick)  = abap_false.

      LOOP AT all_items ASSIGNING FIELD-SYMBOL(<row>)
        WHERE RateSheetUUID = <comp>-rate_sheet_uuid
          AND BomComponent  = <comp>-bom_component.
        IF <row>-QtyRequired > lv_required.
          lv_required = <row>-QtyRequired.
        ENDIF.
        lv_all_qty += <row>-VendorOrderQty.
        IF <row>-IsIncluded = abap_true.
          lv_ticked  += <row>-VendorOrderQty.
          lv_has_tick = abap_true.
        ENDIF.
      ENDLOOP.

      DATA(lv_text) = VALUE string( ).
      IF lv_all_qty > lv_required.
        lv_text = |No change in quantity of { <comp>-bom_component }: vendor order qty { lv_all_qty } exceeds qty required { lv_required }.|.
      ELSEIF lv_has_tick = abap_true AND lv_ticked <> lv_required.
        lv_text = |Check vendor order qty for BOM Component { <comp>-bom_component }: ticked total { lv_ticked } <> qty required { lv_required }.|.
      ENDIF.

      IF lv_text IS INITIAL.
        CONTINUE.
      ENDIF.

      LOOP AT trigger_items ASSIGNING <trigger>
        WHERE RateSheetUUID = <comp>-rate_sheet_uuid
          AND BomComponent  = <comp>-bom_component.
        APPEND VALUE #( %tky = <trigger>-%tky ) TO failed-ratesheetitem.
        APPEND VALUE #(
          %tky                    = <trigger>-%tky
          %state_area             = 'QTY_ALLOCATION'
          %path                   = VALUE #( ratesheetheader = VALUE #(
                                               %is_draft     = <trigger>-%is_draft
                                               RateSheetUUID = <trigger>-RateSheetUUID ) )
          %element-VendorOrderQty = if_abap_behv=>mk-on
          %msg                    = new_message_with_text(
                                      severity = if_abap_behv_message=>severity-error
                                      text     = lv_text )
        ) TO reported-ratesheetitem.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD dropuntickedrows.
    " P-102: legacy SAVE1 (l.1106) persists only ticked rows
    " (LOOP AT IT_FINAL WHERE TICK = 'X' -> MODIFY ZPR_ALV_UPDATE).
    " Unticked vendor rows are removed at save. Components are never
    " emptied: if no row of a component is ticked, its rows are kept.
    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetItem
        FIELDS ( RateSheetUUID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(trigger_items).

    IF trigger_items IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetItem BY \_Header
        FIELDS ( RateSheetUUID )
        WITH CORRESPONDING #( trigger_items )
      RESULT DATA(headers).

    READ ENTITIES OF zi_rsh_header IN LOCAL MODE
      ENTITY RateSheetHeader BY \_Item
        FIELDS ( RateSheetUUID BomComponent IsIncluded )
        WITH CORRESPONDING #( headers )
      RESULT DATA(all_items).

    DATA lt_deletes TYPE TABLE FOR DELETE zi_rsh_item.
    LOOP AT all_items ASSIGNING FIELD-SYMBOL(<row>) WHERE IsIncluded = abap_false.
      IF line_exists( all_items[ RateSheetUUID = <row>-RateSheetUUID
                                 BomComponent  = <row>-BomComponent
                                 IsIncluded    = abap_true ] ).
        APPEND VALUE #( %tky = <row>-%tky ) TO lt_deletes.
      ENDIF.
    ENDLOOP.

    IF lt_deletes IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rsh_header IN LOCAL MODE
        ENTITY RateSheetItem DELETE FROM lt_deletes.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
