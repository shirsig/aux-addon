local m = {}
Aux.test = m

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

    local filter_string = this:GetText()

    local completed_filter_string = ({strfind(filter_string, '([^;]*)/[^/]*$')})[3]
    local current_filter = completed_filter_string and Aux.scan_util.filter_from_string(completed_filter_string)

    local options = {}

    if current_filter or not completed_filter_string then
        current_filter = current_filter or {}

        if current_filter.name
                and Aux.static.auctionable_items[strupper(current_filter.name)]
                and not current_filter.min_level
                and not current_filter.max_level
                and not current_filter.class
                and not current_filter.subclass
                and not current_filter.slot
                and not current_filter.quality
                and not current_filter.usable
        then
            tinsert(options, 'exact')
        end

        -- classes
        if not current_filter.class and not current_filter.exact then
            for _, class in ipairs({ GetAuctionItemClasses() }) do
                tinsert(options, class)
            end
        end

        -- subclasses
        if current_filter.class and not current_filter.subclass then
            for _, class in ipairs({ GetAuctionItemSubClasses(current_filter.class) }) do
                tinsert(options, class)
            end
        end

        -- slots
        if current_filter.class and current_filter.subclass then
            for _, invtype in ipairs({ GetAuctionInvTypes(current_filter.class, current_filter.subclass) }) do
                tinsert(options, getglobal(invtype))
            end
        end

        -- usable
        if not current_filter.usable and not current_filter.exact then
            tinsert(options, 'usable')
        end

        -- rarities
        if not current_filter.quality and not current_filter.exact then
            for i=0,4 do
                tinsert(options, getglobal('ITEM_QUALITY'..i..'_DESC'))
            end
        end

        -- discard
        if not current_filter.discard then
            tinsert(options, 'discard')
        end

        -- item names
        snipe.log(key_count)
        if not completed_filter_string then
            local item_names = {}
            for key, value in Aux.static.auctionable_items do
                if type(key) == 'number' then
                    tinsert(item_names, value.name)
                end
            end
            sort(item_names)
            for _, item_name in ipairs(item_names) do
                tinsert(options, item_name)
            end
        end

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
end