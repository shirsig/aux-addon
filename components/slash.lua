SLASH_AUX1 = '/aux'
function SlashCmdList.AUX(command)
	if not command then return end
	local arguments = tokenize(command)
    if arguments[1] == 'clear' and arguments[2] == 'history' then
        persistence.load_dataset().history = nil
        log 'History cleared.'
    elseif arguments[1] == 'clear' and arguments[2] == 'post' then
        persistence.load_dataset().post = nil
        log 'Post settings cleared.'
    elseif arguments[1] == 'clear' and arguments[2] == 'datasets' then
        _g.aux_datasets = {}
        log 'Datasets cleared.'
    elseif arguments[1] == 'clear' and arguments[2] == 'merchant' and arguments[3] == 'buy' then
	    _g.aux_merchant_buy = {}
        log 'Merchant buy prices cleared.'
    elseif arguments[1] == 'clear' and arguments[2] == 'merchant' and arguments[3] == 'sell' then
	    _g.aux_merchant_sell = {}
        log 'Merchant sell prices cleared.'
    elseif arguments[1] == 'clear' and arguments[2] == 'item' and arguments[3] == 'cache' then
	    _g.aux_items = {}
	    _g.aux_item_ids = {}
	    _g.aux_auctionable_items = {}
        log 'Item cache cleared.'
    elseif arguments[1] == 'populate' and arguments[2] == 'wdb' then
        cache.populate_wdb()
    elseif arguments[1] == 'tooltip' and arguments[2] == 'value' then
	    _g.aux_tooltip_value = not _g.aux_tooltip_value
        log('Historical value in tooltip '..(_g.aux_tooltip_value and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'daily' then
	    _g.aux_tooltip_daily = not _g.aux_tooltip_daily
        log('Market value in tooltip '..(_g.aux_tooltip_daily and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'vendor' and arguments[3] == 'buy' then
	    _g.aux_tooltip_vendor_buy = not _g.aux_tooltip_vendor_buy
        log('Vendor buy price in tooltip '..(_g.aux_tooltip_vendor_buy and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'vendor' and arguments[3] == 'sell' then
	    _g.aux_tooltip_vendor_sell = not _g.aux_tooltip_vendor_sell
        log('Vendor sell price in tooltip '..(_g.aux_tooltip_vendor_sell and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'value' then
	    _g.aux_tooltip_disenchant_value = not _g.aux_tooltip_disenchant_value
        log('Disenchant value in tooltip '..(_g.aux_tooltip_disenchant_value and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'distribution' then
	    _g.aux_tooltip_disenchant_distribution = not _g.aux_tooltip_disenchant_distribution
        log('Disenchant distribution in tooltip '..(_g.aux_tooltip_disenchant_distribution and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'source' then
	    _g.aux_tooltip_disenchant_source = not _g.aux_tooltip_disenchant_source
        log('Disenchant source in tooltip '..(_g.aux_tooltip_disenchant_source and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'ignore' and arguments[2] == 'owner' then
	    _g.aux_ignore_owner = not _g.aux_ignore_owner
        log('Ignoring of owner '..(_g.aux_ignore_owner and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'chars' and arguments[2] == 'add' then
		local realm = GetCVar 'realmName'
		_g.aux_characters[realm] = _g.aux_characters[realm] or {}
		for i=3,getn(arguments) do
			local name = string.gsub(strlower(arguments[i]), '^%l', strupper)
			if not _g.aux_characters[realm][name] then
				_g.aux_characters[realm][name] = true
				log('Character "'..name..'" added.')
			end
		end
	elseif arguments[1] == 'chars' and arguments[2] == 'remove' then
		local realm = GetCVar 'realmName'
		if not _g.aux_characters[realm] then
			return
		end
		for i=3,getn(arguments) do
			local name = string.gsub(strlower(arguments[i]), '^%l', strupper)
			if _g.aux_characters[realm][name] then
				_g.aux_characters[realm][name] = nil
				log('Character "'..name..'" removed.')
			end
		end
	elseif arguments[1] == 'chars' then
		local realm = GetCVar 'realmName'
		local chars = {}
		for name in _g.aux_characters[realm] or {} do
			tinsert(chars, name)
		end
		if getn(chars) > 0 then
			log('Your characters: "'..table.concat(chars, ', ')..'".')
		else
			log 'You don\'t have any additional characters. To add your characters type "/aux chars add NAME1 NAME2 NAME3...".'
		end
	else
		log('Unknown command: "'..command..'"')
	end
end