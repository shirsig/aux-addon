local m = {}
Aux.groups = m


function m.parse_group(datastring)
    return Aux.persistence.deserialize(datastring, ',')
end

function m.parse_item_key(item_key)
    local _, _, item_id, suffix_id = strfind(item_key, '(%d+):?(%d*)')
    return tonumber(item_id), suffix_id == '' and 0 or tonumber(suffix_id)
end

m.test_group = '13127;9510;4438;16254;12006;13131;13012;4413;1482'


function m.test()
    local array = Aux.persistence.deserialize(';', ';')
    snipe.log(getn(array))
end

function on_char()
    for _, data in ipairs(TSM.db.global.savedSearches) do
        if data.searchMode == "normal" then
            local prevSearch = strlower(data.filter)
            if strsub(prevSearch, 1, textLen) == text then
                self:SetText(prevSearch)
                self:HighlightText(textLen, -1)
                break
            end
        end
    end
end