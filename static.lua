private, public = {}, {}
aux_auctionable_items = public

aux_auctionable_items = {}

function public.find_auctionable_items(i)
    for j=i, i+1 do
        local name = GetItemInfo('item:'..j)
        if name then
            local tooltip = Aux.info.tooltip(function(tt) tt:SetHyperlink('item:'..j) end)
            Aux.log(name)
            if not Aux.info.tooltip_match({'binds when picked up'}, tooltip) and not Aux.info.tooltip_match({'quest item'}, tooltip) then
                Aux.log(j)
                tinsert(aux_auctionable_items, j)
            end
        end
    end
    if i+1000 > 30000 then
        Aux.log(getn(aux_auctionable_items))
    else
        local t0 = time()
        Aux.control.as_soon_as(function() return time() - t0 > 1 end, function()
            return find_auctionable_items(i+1000)
        end)
    end
end

public.items = {
}