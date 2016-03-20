local private, public = {}, {}
Aux.merchant = public

local sell_data = {}
local buy_data = {}

function public.on_load()
    Aux.control.event_listener('MERCHANT_SHOW', private.scan_merchant).start()
end

function private.scan_merchant()
    Aux.util.loop_inventory(function(bag, slot)
        local item_info = Aux.info.container_item(bag, slot)
        if item_info then
            sell_data[item_info.item_id] = item_info.tooltip.money / item_info.aux_quantity
        end
    end)

--    local merchant_name = UnitName('npc')
    local merchant_item_count = GetMerchantNumItems()
    for i=1,merchant_item_count do
        local item_id = Aux.info.parse_hyperlink(GetMerchantItemLink(i))
        local _, _, price, count, stock = GetMerchantItemInfo(i)
        buy_data[item_id] = Aux.util.join({price / count, stock}, '#')
    end
end