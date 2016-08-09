local addon = aux_module()
aux = tremove(addon, 1)
local m, public, private = unpack(addon)

public.version = '3.9.0'

private.modules = {}
function public.module(path)
	if path == 'aux' then
		return unpack(addon)
	elseif m.modules[path] then
		return unpack(m.modules[path])
	else
		local module, prefix
		for name in string.gfind(path, '[%a_][%w_]*') do
			local qualified_name = prefix and prefix..'.'..name or name
			module = m.modules[qualified_name]
			if not module then
				module = aux_module()
				module[4].LOAD = nil
				(prefix and m.modules[prefix] or addon)[2][name] = tremove(module, 1)
				m.modules[qualified_name] = module
			end
			prefix = qualified_name
		end
		return unpack(module)
	end
end

local event_frame = CreateFrame('Frame')
private.ADDON_LOADED = {}
event_frame:SetScript('OnEvent', function()
	if event == 'ADDON_LOADED' then
		if m.ADDON_LOADED[arg1] then
			m.ADDON_LOADED[arg1]()
		end
	else
		m[event]()
		if event == 'VARIABLES_LOADED' then
			for _, module in m.modules do
				if module[1].LOAD then
					module[1].LOAD()
				end
			end
			m.log('v'..m.version..' loaded.')
		end
	end
end)
for _, event in {'VARIABLES_LOADED', 'ADDON_LOADED', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED', 'AUCTION_BIDDER_LIST_UPDATE', 'AUCTION_OWNED_LIST_UPDATE'} do
	event_frame:RegisterEvent(event)
end
