local private, public = {}, {}
Aux.static = public

local auctionable_items = {}
local sorted_item_names

function public.on_load()
	private.find_auctionable_items()
end

function public.sorted_item_names()
	if not sorted_item_names then
		sorted_item_names = {}
		for name, _ in auctionable_items do
			tinsert(sorted_item_names, name)
		end
		sort(sorted_item_names, function(a, b) return strlen(a) < strlen(b) or (strlen(a) == strlen(b) and a < b) end)
	end
	return sorted_item_names
end

function public.item_id(item_name)
	return auctionable_items[strlower(item_name)]
end

function public.item_info(item_id)
	local data_string

	if aux_auctionable_items then
		data_string = aux_auctionable_items[item_id]
	else
		data_string = private.auctionable_items[item_id]
	end

	return data_string and private.read_item_info(data_string)
end

--function public.generate_cache()
--	local ids = {}
--	for id, _ in pairs(private.auctionable_items) do
--		if type(id) == 'number' then
--			tinsert(ids, id)
--		end
--	end
--	local n = getn(ids)
--
--	local function helper(index)
--		if index > n then
--			Aux.log('Cache generated.')
--			return
--		end
--
--		local id = ids[index]
--		if not GetItemInfo(id) then
--			Aux.log('Fetching item '..id..' ...')
--			AuxStaticTooltip:SetHyperlink('item:'..id)
--		end
--		local t0 = time()
--		Aux.control.as_soon_as(function() return GetItemInfo(id) or time() > t0 + 3 end, function()
--			local name, _, quality, level, class, subclass, max_stack, slot, texture = GetItemInfo(id)
--			if name then
--			    local class_index = Aux.item_class_index(class)
--				local subclass_index = class_index and Aux.item_subclass_index(class_index, subclass)
--
--				Aux.log('Adding item '..id..' ...')
--
--				aux_auctionable_item_ids[strupper(name)] = id
--				aux_auctionable_items[id] = Aux.util.join({id or '', name or '', quality or '', level or '', class_index or '', subclass_index or '', slot or '', max_stack or '', texture or ''}, '#')
--			end
--			return helper(index + 1)
--		end)
--	end
--
--	aux_auctionable_items = {}
--	aux_auctionable_item_ids = {}
--	helper(1)
--end

function private.find_auctionable_items() -- requires a full wdb item cache
	local function helper(i)
		for item_id=i,i+200 do
			local name, _, quality = GetItemInfo('item:'..item_id)
			if name then
				local item_id = item_id
				local tooltip = Aux.info.tooltip(function(tt) tt:SetHyperlink('item:'..item_id) end)
				if Aux.info.auctionable(tooltip, quality) then
					auctionable_items[strlower(name)] = item_id
					sorted_item_names = nil
				end
			end
		end
		if i+200 <= 30000 then
			local t0 = GetTime()
			Aux.control.as_soon_as(function() return GetTime() - t0 > 0.2 end, function()
				return helper(i+200)
			end)
		end
	end

	helper(1)
end