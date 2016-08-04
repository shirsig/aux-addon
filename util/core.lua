local m, public, private = aux.module'util'

function public.pass()
end

function public.id(x)
	return x
end

function public.const(x)
	return function()
		return x
	end
end

function public.size(t)
	local x = 0
	for _ in t do
		x = x + 1
	end
	return x
end

function public.key(value, t)
	for k, v in t do
		if v == value then
			return k
		end
	end
end

function public.keys(t)
	local ks = {}
	for k in t do
		tinsert(ks, k)
	end
	return ks
end

function public.values(t)
	local vs = {}
	for _, v in t do
		tinsert(vs, v)
	end
	return vs
end

function public.eq(t1, t2)
	if not t1 or not t2 then
		return false
	end

	for key, value in t1 do
		if t2[key] ~= value then
			return false
		end
	end

	for key, value in t2 do
		if t1[key] ~= value then
			return false
		end
	end

	return true
end

function public.any(xs, p)
	local holds = false
	for _, x in xs do
		holds = holds or p(x)
	end
	return holds
end

function public.all(xs, p)
	local holds = true
	for _, x in xs do
		holds = holds and p(x)
	end
	return holds
end

function public.filter(xs, p)
	local ys = {}
	for k, x in xs do
		if p(x, k) then
			ys[k] = x
		end
	end
	return ys
end

function public.map(xs, f)
	local ys = {}
	for k, x in xs do
		ys[k] = f(x, k)
	end
	return ys
end

do
	local mt = {
		__call = function(self)
			return
		end,
	}

	--	local methods = {}
	--
	--	function methods:add(key)
	--		self[key] = true
	--	end
	--
	--	function methods:remove(key)
	--		self[key] = nil
	--	end
	--
	--	function methods:size()
	--		local size = 0
	--		for _,_ in self do
	--			size = size + 1
	--		end
	--		return size
	--	end
	--
	--	function methods:elements()
	--		local elements = {}
	--		for element, _ in self do
	--			tinsert(elements, element)
	--		end
	--		return elements
	--	end

	function public.set(...)
		local self = {}
		for i=1,arg.n do
			self[arg[i]] = true
		end
		return setmetatable(self, mt)
	end
end

function public.join(parts, separator)
	local str = parts[1]
	for i=2,getn(parts) do
		if not parts[i] then break end
		str = str..separator..parts[i]
	end
	return str
end

function public.split(str, separator)
	local parts = {}
	while true do
		local start_index, _ = strfind(str, separator, 1, true)

		if start_index then
			local part = strsub(str, 1, start_index - 1)
			tinsert(parts, part)
			str = strsub(str, start_index + 1)
		else
			local part = strsub(str, 1)
			tinsert(parts, part)
			return parts
		end
	end
end

function public.tokenize(str)
	local tokens = {}
	for token in string.gfind(str, '%S+') do
		tinsert(tokens, token)
	end
	return tokens
end

function public.wipe(t)
	while getn(t) > 0 do
		tremove(t)
	end
	for k, _ in t do
		t[k] = nil
	end
end

function public.copy(t)
	local copy = {}
	for k, v in t do
		copy[k] = v
	end
	return copy
end

function public.round(x)
	return floor(x + 0.5)
end

function public.trim(str)
	return gsub(str, '^%s*(.-)%s*$', '%1')
end

function public.inventory()
	local bag, slot = 0, 0

	return function()
		if not GetBagName(bag) or slot >= GetContainerNumSlots(bag) then
			repeat
				bag = bag + 1
			until GetBagName(bag) or bag > 4
			slot = 1
		else
			slot = slot + 1
		end

		if bag <= 4 then
			return {bag, slot}, m.bag_type(bag)
		end
	end
end

function public.bag_type(bag)
	if bag == 0 then
		return 1
	end

	if GetInventoryItemLink('player', ContainerIDToInventoryID(bag)) then
		local item_id = aux.info.parse_hyperlink(GetInventoryItemLink('player', ContainerIDToInventoryID(bag)))
		local item_info = aux.info.item(item_id)
		return aux.info.item_subclass_index(3, item_info.subclass)
	end
end

function public.without_errors(f)
    local orig = UIErrorsFrame.AddMessage
    UIErrorsFrame.AddMessage = m.pass
    f()
    UIErrorsFrame.AddMessage = orig
end

function public.without_sound(f)
    local orig = GetCVar('MasterSoundEffects')
    SetCVar('MasterSoundEffects', 0)
    f()
    SetCVar('MasterSoundEffects', orig)
end

function public.format_money(money, exact, color)
	color = color or '|r'

	local TEXT_NONE = '0'

	local GSC_GOLD = 'ffd100'
	local GSC_SILVER = 'e6e6e6'
	local GSC_COPPER = 'c8602c'
	local GSC_START = '|cff%s%d|r'
	local GSC_PART = color..'.|cff%s%02d|r'
	local GSC_NONE = '|cffa0a0a0'..TEXT_NONE..'|r'

	if not exact and money >= 10000 then
		-- Round to nearest silver
		money = floor(money / 100 + 0.5) * 100
	end
	local g, s, c = aux.money.to_GSC(money)

	local gsc = ''

	local fmt = GSC_START
	if g > 0 then
		gsc = gsc..format(fmt, GSC_GOLD, g)
		fmt = GSC_PART
	end
	if s > 0 or c > 0 then
		gsc = gsc..format(fmt, GSC_SILVER, s)
		fmt = GSC_PART
	end
	if c > 0 then
		gsc = gsc..format(fmt, GSC_COPPER, c)
	end
	if gsc == '' then
		gsc = GSC_NONE
	end
	return gsc
end