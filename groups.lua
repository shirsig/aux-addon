local m = {}
Aux.groups = m


function m.parse_group(datastring)
    return Aux.persistence.deserialize(datastring, ',')
end

function m.parse_item_key(item_key)
    local _, _, item_id, suffix_id = strfind(item_key, '(%d+):?(%d*)')
    return tonumber(item_id), suffix_id == '' and 0 or tonumber(suffix_id)
end

m.test_group = '13127,9510,4438,16254,12006,13131,13012,4413,1482'


--function private:StartFilterSearch()
--    local filter = private.frame.filter.filterInputBox:GetText()
--
--    local minLevel = private.frame.filter.levelMinBox:GetNumber()
--    local maxLevel = private.frame.filter.levelMaxBox:GetNumber()
--    if maxLevel > 0 then
--        filter = format("%s/%d/%d", filter, minLevel, maxLevel)
--    elseif minLevel > 0 then
--        filter = format("%s/%d", filter, minLevel)
--    end
--
--    local minItemLevel = private.frame.filter.itemLevelMinBox:GetNumber()
--    local maxItemLevel = private.frame.filter.itemLevelMaxBox:GetNumber()
--    if maxItemLevel > 0 then
--        filter = format("%s/i%d/i%d", filter, minItemLevel, maxItemLevel)
--    elseif minItemLevel > 0 then
--        filter = format("%s/i%d", filter, minItemLevel)
--    end
--
--    local class = private.frame.filter.classDropdown:GetValue()
--    if class then
--        local classes = {GetAuctionItemClasses()}
--        filter = format("%s/%s", filter, classes[class])
--        local subClass = private.frame.filter.subClassDropdown:GetValue()
--        if subClass then
--            local subClasses = {GetAuctionItemSubClasses(class)}
--            filter = format("%s/%s", filter, subClasses[subClass])
--        end
--    end
--
--    local rarity = private.frame.filter.rarityDropdown:GetValue()
--    if rarity then
--        filter = format("%s/%s", filter,  _G["ITEM_QUALITY"..rarity.."_DESC"])
--    end
--
--    if private.frame.filter.usableCheckBox:GetValue() then
--        filter = format("%s/usable", filter)
--    end
--
--    if private.frame.filter.exactCheckBox:GetValue() then
--        filter = format("%s/exact", filter)
--    end
--
--    local maxQty = private.frame.filter.maxQtyBox:GetNumber()
--    if maxQty > 0 then
--        filter = format("%s/x%d", filter, maxQty)
--    end
--
--    local searchInfo = {searchMode="normal", extraInfo={searchType="filter"}, filter=filter}
--    TSM.AuctionTab:StartSearch(searchInfo)
--end