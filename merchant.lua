local private, public = {}, {}
Aux.merchant = public

aux_merchant_buy, aux_merchant_sell = {}, {}

function public.on_load()
    Aux.control.event_listener('MERCHANT_SHOW', private.scan_merchant).start()
end

function public.info(item_id)
    local unit_price, unlimited
    if aux_merchant_buy[item_id] then
        local buy_fields = Aux.util.split(aux_merchant_buy[item_id], '#')
        unit_price, unlimited = tonumber(buy_fields[1]), not not tonumber(buy_fields[2])
    end

    return aux_merchant_sell[item_id], unit_price, unlimited
end

function private.scan_merchant()
    Aux.util.loop_inventory(function(bag, slot)
        local item_info = Aux.info.container_item(bag, slot)
        if item_info then
            aux_merchant_sell[item_info.item_id] = item_info.tooltip.money / item_info.aux_quantity
        end
    end)

--    local merchant_name = UnitName('npc')
    local merchant_item_count = GetMerchantNumItems()
    for i=1,merchant_item_count do
        local item_id = Aux.info.parse_hyperlink(GetMerchantItemLink(i))
        local _, _, price, count, stock = GetMerchantItemInfo(i)
        local new_unit_price, new_unlimited = price / count, Aux.persistence.blizzard_boolean(stock == -1)
        if aux_merchant_buy[item_id] then
            local fields = Aux.util.split(aux_merchant_buy[item_id], '#')
            local old_unit_price, old_unlimited = tonumber(fields[1]), tonumber(fields[2])

            local unit_price
            if old_unlimited and not new_unlimited then
                unit_price = old_unit_price
            elseif new_unlimited and not old_unlimited then
                unit_price = new_unit_price
            else
                unit_price = min(old_unit_price, new_unit_price)
            end

            aux_merchant_buy[item_id] = Aux.util.join({
                unit_price,
                old_unlimited or new_unlimited,
            }, '#')
        else
            aux_merchant_buy[item_id] = Aux.util.join({
                new_unit_price,
                new_unlimited,
            }, '#')
        end
    end
end