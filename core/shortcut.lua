select(2, ...) 'aux.core.shortcut'

local aux = require 'aux'
local info = require 'aux.util.info'

do
    local orig = SetItemRef
    function _G.SetItemRef(...)
        local item_id = select(3, strfind(..., '^item:(%d+)'))
        if select(3, ...) ~= 'RightButton' or not aux.index(aux.get_tab(), 'CLICK_LINK') or not item_id then
            return orig(...)
        end
        local item_info = info.item(tonumber(item_id))
        if item_info then
            return aux.get_tab().CLICK_LINK(item_info)
        end
    end
end

do
    local orig = HandleModifiedItemClick
    function _G.HandleModifiedItemClick(...)
        if not IsAltKeyDown() or not aux.index(aux.get_tab(), 'USE_ITEM') then
            return orig(...)
        end
        aux.get_tab().USE_ITEM(info.parse_link(select(1, ...)))
    end
end