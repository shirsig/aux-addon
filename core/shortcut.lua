select(2, ...) 'aux.core.shortcut'

local aux = require 'aux'
local info = require 'aux.util.info'

hooksecurefunc('HandleModifiedItemClick', function(item_link)
    if item_link and IsAltKeyDown() and aux.index(aux.get_tab(), 'USE_ITEM') then
        aux.get_tab().USE_ITEM(info.parse_link(item_link))
    end
end)
