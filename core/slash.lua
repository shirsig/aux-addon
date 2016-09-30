aux_slash = module

include (green_t)
include (aux)
include (aux_util)
include (aux_control)
include (aux_util_color)

local persistence = aux_persistence

aux_ignore_owner = true

SLASH_AUX1 = '/aux'
function SlashCmdList.AUX(command)
	if not command then return end
	local arguments = tokenize(command)
    if arguments[1] == 'clear' and arguments[2] == 'history' then
        persistence.dataset = nil
        print 'History cleared.'
    elseif arguments[1] == 'clear' and arguments[2] == 'post' then
        persistence.dataset.post = nil
        print 'Post settings cleared.'
    elseif arguments[1] == 'clear' and arguments[2] == 'datasets' then
        aux_datasets = t
        print 'Datasets cleared.'
    elseif arguments[1] == 'clear' and arguments[2] == 'merchant' and arguments[3] == 'buy' then
	    aux_merchant_buy = t
        print 'Merchant buy prices cleared.'
    elseif arguments[1] == 'clear' and arguments[2] == 'merchant' and arguments[3] == 'sell' then
	    aux_merchant_sell = t
        print 'Merchant sell prices cleared.'
    elseif arguments[1] == 'clear' and arguments[2] == 'item' and arguments[3] == 'cache' then
	    aux_items = t
	    aux_item_ids = t
	    aux_auctionable_items = t
        print 'Item cache cleared.'
    elseif arguments[1] == 'populate' and arguments[2] == 'wdb' then
        aux_cache.populate_wdb()
    elseif arguments[1] == 'tooltip' and arguments[2] == 'value' then
	    aux_tooltip_value = not aux_tooltip_value
        print('Historical value in tooltip ' .. (aux_tooltip_value and 'enabled' or 'disabled') .. '.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'daily' then
	    aux_tooltip_daily = not aux_tooltip_daily
        print('Market value in tooltip ' .. (aux_tooltip_daily and 'enabled' or 'disabled') .. '.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'vendor' and arguments[3] == 'buy' then
	    aux_tooltip_vendor_buy = not aux_tooltip_vendor_buy
        print('Vendor buy price in tooltip ' .. (aux_tooltip_vendor_buy and 'enabled' or 'disabled') .. '.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'vendor' and arguments[3] == 'sell' then
	    aux_tooltip_vendor_sell = not aux_tooltip_vendor_sell
        print('Vendor sell price in tooltip ' .. (aux_tooltip_vendor_sell and 'enabled' or 'disabled') .. '.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'value' then
	    aux_tooltip_disenchant_value = not aux_tooltip_disenchant_value
        print('Disenchant value in tooltip ' .. (aux_tooltip_disenchant_value and 'enabled' or 'disabled') .. '.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'distribution' then
	    aux_tooltip_disenchant_distribution = not aux_tooltip_disenchant_distribution
        print('Disenchant distribution in tooltip ' .. (aux_tooltip_disenchant_distribution and 'enabled' or 'disabled') .. '.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'source' then
	    aux_tooltip_disenchant_source = not aux_tooltip_disenchant_source
        print('Disenchant source in tooltip ' .. (aux_tooltip_disenchant_source and 'enabled' or 'disabled') .. '.')
    elseif arguments[1] == 'ignore' and arguments[2] == 'owner' then
	    aux_ignore_owner = not aux_ignore_owner
        print('Ignoring of owner ' .. (aux_ignore_owner and 'enabled' or 'disabled') .. '.')
    elseif arguments[1] == 'chars' and arguments[2] == 'add' then
		local realm = GetCVar('realmName')
		aux_characters[realm] = aux_characters[realm] or t
		for i = 3, getn(arguments) do
			local name = gsub(strlower(arguments[i]), '^%l', strupper)
			if not aux_characters[realm][name] then
				aux_characters[realm][name] = true
				print('Character "' .. name .. '" added.')
			end
		end
	elseif arguments[1] == 'chars' and arguments[2] == 'remove' then
		local realm = GetCVar('realmName')
		if not aux_characters[realm] then
			return
		end
		for i = 3, getn(arguments) do
			local name = gsub(strlower(arguments[i]), '^%l', strupper)
			if aux_characters[realm][name] then
				aux_characters[realm][name] = nil
				print('Character "' .. name .. '" removed.')
			end
		end
	elseif arguments[1] == 'chars' then
		local realm = GetCVar('realmName')
		local chars = t
		for name in aux_characters[realm] or t do
			tinsert(chars, name)
		end
		if getn(chars) > 0 then
			print('Your characters: "' .. join(chars, ', ') .. '".')
		else
			print('You don\'t have any additional characters. To add your characters type "/aux chars add NAME1 NAME2 NAME3...".')
		end
	else
		print('Unknown command: "' .. command .. '"')
	end
end