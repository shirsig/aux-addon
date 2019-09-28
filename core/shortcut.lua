select(2, ...) 'aux.core.shortcut'

local aux = require 'aux'
local info = require 'aux.util.info'

hooksecurefunc('HandleModifiedItemClick', function(...)
    if IsAltKeyDown() and aux.index(aux.get_tab(), 'USE_ITEM') then
        aux.get_tab().USE_ITEM(info.parse_link(select(1, ...)))
    end
end)
