SLASH_AUX1 = '/aux'
function SlashCmdList.AUX(command)
	if not command then return end
	local arguments = Aux.util.split(command, " ")
    if command == 'clear history' then
        Aux.persistence.load_dataset().history = nil
        Aux.log('History cleared.')
    elseif command == 'clear post' then
        Aux.persistence.load_dataset().post = nil
        Aux.log('Post settings cleared.')
    elseif command == 'clear datasets' then
        aux_datasets = {}
        Aux.log('Datasets cleared.')
    elseif command == 'clear merchant buy' then
        aux_merchant_buy = {}
        Aux.log('Merchant buy prices cleared.')
    elseif command == 'clear merchant sell' then
        aux_merchant_sell = {}
        Aux.log('Merchant sell prices cleared.')
    elseif command == 'clear item cache' then
        aux_items = {}
        aux_item_ids = {}
        aux_auctionable_items = {}
        Aux.log('Item cache cleared.')
    elseif command == 'populate wdb' then
        Aux.cache.populate_wdb()
    elseif command == 'tooltip daily' then
        aux_tooltip_daily = not aux_tooltip_daily
        Aux.log('Market value in tooltip '..(aux_tooltip_daily and 'enabled' or 'disabled')..'.')
    elseif command == 'tooltip vendor buy' then
        aux_tooltip_vendor_buy = not aux_tooltip_vendor_buy
        Aux.log('Vendor buy price in tooltip '..(aux_tooltip_vendor_buy and 'enabled' or 'disabled')..'.')
    elseif command == 'tooltip vendor sell' then
        aux_tooltip_vendor_sell = not aux_tooltip_vendor_sell
        Aux.log('Vendor sell price in tooltip '..(aux_tooltip_vendor_sell and 'enabled' or 'disabled')..'.')
    elseif command == 'tooltip disenchant value' then
        aux_tooltip_disenchant_value = not aux_tooltip_disenchant_value
        Aux.log('Disenchant value in tooltip '..(aux_tooltip_disenchant_value and 'enabled' or 'disabled')..'.')
    elseif command == 'tooltip disenchant distribution' then
        aux_tooltip_disenchant_distribution = not aux_tooltip_disenchant_distribution
        Aux.log('Disenchant distribution in tooltip '..(aux_tooltip_disenchant_distribution and 'enabled' or 'disabled')..'.')
    elseif command == 'tooltip disenchant source' then
        aux_tooltip_disenchant_source = not aux_tooltip_disenchant_source
        Aux.log('Disenchant source in tooltip '..(aux_tooltip_disenchant_source and 'enabled' or 'disabled')..'.')
    elseif command == 'ignore owner' then
        aux_ignore_owner = not aux_ignore_owner
        Aux.log('Ignoring of owner '..(aux_ignore_owner and 'enabled' or 'disabled')..'.')
    elseif arguments[1] == 'addchar' and arguments[2] then
		local exists = false
		for i=2, table.getn(arguments) do
			exists = false
			if arguments[i] ~= "" then
				arguments[i] = strupper(strsub(arguments[i], 1, 1))..strsub(arguments[i], 2) -- force uppercase
				for i_aux,v in ipairs(aux_characters) do
					if (aux_characters[i_aux] == arguments[i]) then
						exists = true
						break
					end
				end
				if not exists then
					table.insert(aux_characters, arguments[i])
					Aux.log('Character "'..arguments[i]..'" added.')
				end
			end
		end
	elseif arguments[1] == 'delchar' and arguments[2] then
		for i=2, table.getn(arguments) do
			if arguments[i] ~= "" then
				arguments[i] = strupper(strsub(arguments[i], 1, 1))..strsub(arguments[i], 2)
				for i_aux,v in ipairs(aux_characters) do
					if (aux_characters[i_aux] == arguments[i]) then
						table.remove(aux_characters, i_aux)
						Aux.log('Character "'..arguments[i]..'" removed.')
						break
					end
				end
			end
		end
	elseif command == 'chars' then
		local chars = nil
		local num = table.getn(aux_characters);
		for i,v in ipairs(aux_characters) do
			if( i ~= num) then
				if chars ~= nil then
					chars = chars .. v .. ", ";
				else
					chars =   v .. ", ";
				end
			else
				if chars ~= nil then
					chars = chars .. v;
				else
					chars = v;
				end
			end
		end
		if num > 0 then
			Aux.log('Your characters: "'..chars..'".')
		else
			Aux.log('You don\'t have any additional characters. Type "/aux addchar NAME" to add one.')
		end
	end
end