local module = aux_module()
aux = tremove(module, 1)
local m, public, private = unpack(module)

public.version = '3.9.0'

local function initialize_module(private_declarator)
	private_declarator.LOAD = nil
end
initialize_module(public)
private.modules = {aux=module}
function public.module(name)
	if m.modules[name] then
		return unpack(m.modules[name])
	else
		local module = aux_module()
		initialize_module(module[4])
		m.modules[name] = module
		public[name] = tremove(module, 1)
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
