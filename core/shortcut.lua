module 'aux.core.shortcut'

include 'aux'

local T = require 'T'

local info = require 'aux.util.info'

do
    local orig = SetItemRef
    _G.SetItemRef = T.vararg-function(arg)
        if arg[3] ~= 'RightButton' or not index(get_active_tab(), 'CLICK_LINK') or not strfind(arg[1], '^item:%d+') then
            return orig(unpack(arg))
        end
        local item_info = info.item(tonumber(select(3, strfind(arg[1], '^item:(%d+)'))))
        if item_info then
            return get_active_tab().CLICK_LINK(item_info)
        end
    end
end

do
    local orig = UseContainerItem
    _G.UseContainerItem = T.vararg-function(arg)
        if modified() or not get_active_tab() then
            return orig(unpack(arg))
        end
        local item_info = info.container_item(arg[1], arg[2])
        if item_info and get_active_tab().USE_ITEM then
            get_active_tab().USE_ITEM(item_info)
        end
    end
end