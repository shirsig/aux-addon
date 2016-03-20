local private, public = {}, {}
Aux.item_cache = public

local MIN_ITEM_ID, MAX_ITEM_ID = 1, 30000

aux_items = {}
aux_auctionable_items = {}

function public.on_load()
	private.find_auctionable_items()
end

function public.item_id(item_name)
	return aux_items[strlower(item_name)]
end

function private.find_auctionable_items()

	local function helper(item_id)
		local processed = 0
		while processed <= 100 and item_id <= MAX_ITEM_ID do
			local itemstring = 'item:'..item_id
			local name, _, quality = GetItemInfo(itemstring)
			name = name and strlower(name)
			if name and not aux_items[name] then
				aux_items[name] = item_id
				local tooltip = Aux.info.tooltip(function(tt) tt:SetHyperlink(itemstring) end)
				if Aux.info.auctionable(tooltip, quality) then
					tinsert(aux_auctionable_items, name)
				end
				processed = processed + 1
			end
			item_id = item_id + 1
		end

		if item_id <= MAX_ITEM_ID then
			local t0 = GetTime()
			Aux.control.as_soon_as(function() return GetTime() - t0 > 0.1 end, function()
				return helper(item_id)
			end)
		else
			sort(aux_auctionable_items, function(a, b) return strlen(a) < strlen(b) or (strlen(a) == strlen(b) and a < b) end)
		end
	end

	helper(MIN_ITEM_ID)
end

function public.populate_wdb()

	local function helper(item_id)
		if item_id > MAX_ITEM_ID then
			Aux.log('Cache populated.')
			return
		end

		if not GetItemInfo('item:'..item_id) then
			Aux.log('Fetching item '..item_id..'.')
			AuxTooltip:SetHyperlink('item:'..item_id)
		end

		local t0 = GetTime()
		Aux.control.as_soon_as(function() return GetItemInfo('item:'..item_id) or GetTime() - t0 > 0.1 end, function()
			return helper(item_id + 1)
		end)
	end

	helper(MIN_ITEM_ID)
end