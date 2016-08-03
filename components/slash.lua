SLASH_AUX1 = '/aux'
function SlashCmdList.AUX(command)
	if not command then return end
	local arguments = Aux.util.tokenize(command)
    if arguments[1] == 'clear' and arguments[2] == 'history' then
        Aux.persistence.load_dataset().history = nil
        Aux.log('History cleared.')
    elseif arguments[1] == 'clear' and arguments[2] == 'post' then
        Aux.persistence.load_dataset().post = nil
        Aux.log('Post settings cleared.')
    elseif arguments[1] == 'clear' and arguments[2] == 'datasets' then
        aux_datasets = {}
        Aux.log('Datasets cleared.')
    elseif arguments[1] == 'clear' and arguments[2] == 'merchant' and arguments[3] == 'buy' then
        aux_merchant_buy = {}
        Aux.log('Merchant buy prices cleared.')
    elseif arguments[1] == 'clear' and arguments[2] == 'merchant' and arguments[3] == 'sell' then
        aux_merchant_sell = {}
        Aux.log('Merchant sell prices cleared.')
    elseif arguments[1] == 'clear' and arguments[2] == 'item' and arguments[3] == 'cache' then
        aux_items = {}
        aux_item_ids = {}
        aux_auctionable_items = {}
        Aux.log('Item cache cleared.')
    elseif arguments[1] == 'populate' and arguments[2] == 'wdb' then
        Aux.cache.populate_wdb()
    elseif arguments[1] == 'tooltip' and arguments[2] == 'value' then
        aux_tooltip_value = not aux_tooltip_value
        Aux.log('Historical value in tooltip '..(aux_tooltip_value and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'daily' then
        aux_tooltip_daily = not aux_tooltip_daily
        Aux.log('Market value in tooltip '..(aux_tooltip_daily and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'vendor' and arguments[3] == 'buy' then
        aux_tooltip_vendor_buy = not aux_tooltip_vendor_buy
        Aux.log('Vendor buy price in tooltip '..(aux_tooltip_vendor_buy and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'vendor' and arguments[3] == 'sell' then
        aux_tooltip_vendor_sell = not aux_tooltip_vendor_sell
        Aux.log('Vendor sell price in tooltip '..(aux_tooltip_vendor_sell and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'value' then
        aux_tooltip_disenchant_value = not aux_tooltip_disenchant_value
        Aux.log('Disenchant value in tooltip '..(aux_tooltip_disenchant_value and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'distribution' then
        aux_tooltip_disenchant_distribution = not aux_tooltip_disenchant_distribution
        Aux.log('Disenchant distribution in tooltip '..(aux_tooltip_disenchant_distribution and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'source' then
        aux_tooltip_disenchant_source = not aux_tooltip_disenchant_source
        Aux.log('Disenchant source in tooltip '..(aux_tooltip_disenchant_source and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'ignore' and arguments[2] == 'owner' then
        aux_ignore_owner = not aux_ignore_owner
        Aux.log('Ignoring of owner '..(aux_ignore_owner and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'chars' and arguments[2] == 'add' then
		local realm = GetCVar('realmName')
		aux_characters[realm] = aux_characters[realm] or {}
		for i=3,getn(arguments) do
			local name = string.gsub(strlower(arguments[i]), '^%l', strupper)
			if not aux_characters[realm][name] then
				aux_characters[realm][name] = true
				Aux.log('Character "'..name..'" added.')
			end
		end
	elseif arguments[1] == 'chars' and arguments[2] == 'remove' then
		local realm = GetCVar('realmName')
		if not aux_characters[realm] then
			return
		end
		for i=3,getn(arguments) do
			local name = string.gsub(strlower(arguments[i]), '^%l', strupper)
			if aux_characters[realm][name] then
				aux_characters[realm][name] = nil
				Aux.log('Character "'..name..'" removed.')
			end
		end
	elseif arguments[1] == 'chars' then
		local realm = GetCVar('realmName')
		local chars = {}
		for name, _ in aux_characters[realm] or {} do
			tinsert(chars, name)
		end
		if getn(chars) > 0 then
			Aux.log('Your characters: "'..Aux.util.join(chars, ', ')..'".')
		else
			Aux.log('You don\'t have any additional characters. To add your characters type "/aux chars add NAME1 NAME2 NAME3...".')
		end
	else
		Aux.log('Unknown command: "'..command..'"')
	end
end