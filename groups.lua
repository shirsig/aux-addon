local m = {}
Aux.test = m

function m.on_char()
    for _, data in ipairs(TSM.db.global.savedSearches) do
        if data.searchMode == 'normal' then
            local prevSearch = strlower(data.filter)
            if strsub(prevSearch, 1, textLen) == text then
                self:SetText(prevSearch)
                self:HighlightText(textLen, -1)
                break
            end
        end
    end
end

function m.prettify_search(search)
    local item_pattern = '([^/;]+)([^;]*)/exact'
    while true do
        local _, _, name, in_between = strfind(search, item_pattern)
        if name then
            search = gsub(search, item_pattern, m.display_name(Aux.static.auctionable_items[strupper(name)])..in_between, 1)
        else
            return search
        end
    end
end

function m.display_name(item_id)
    local item_info = Aux.static.item_info(item_id)
    return '|c'..Aux.quality_color(item_info.quality)..'['..item_info.name..']'..'|r'
end

function m:complete()
    local options = {'exact', 'even', 'discard' }

    for _, class in ipairs({ GetAuctionItemClasses() }) do
        tinsert(options, class)
    end

    local filter_string = this:GetText()
    local start_index, _, current_modifier = strfind(filter_string, '([^/;]*)$')
    current_modifier = current_modifier or ''

    for _, option in ipairs(options) do
        if strfind(strupper(option), '^'..strupper(current_modifier)) then
            this:SetText(string.sub(filter_string, 1, start_index - 1)..option)
            this:HighlightText(strlen(filter_string), -1)
            return
        end
    end
end