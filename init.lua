function INIT()
	import :_ 'core' :_ 'control' :_ 'util'
end

module 'core'
public.version = '5.0.0'

do
	local table_pool, auto_recycle = {}, {}
	function public.wipe(t) -- like with a cloth or something
		for k in t do t[k] = nil end; table.setn(t, 0)
	end
	function public.recycle(t)
		auto_recycle[t] = nil; wipe(t); tinsert(table_pool, t)
	end
	public.temp = setmetatable({}, {__sub = function(_, t) auto_recycle[t] = true return t end})
	function public.getter.t() return tremove(table_pool) or {} end
	CreateFrame 'Frame' :SetScript('OnUpdate', function()
		for t in auto_recycle do recycle(t); log(getn(table_pool)) end
		wipe(auto_recycle)
	end)
end

local event_frame = CreateFrame 'Frame'
for _, event in temp-{'ADDON_LOADED', 'VARIABLES_LOADED', 'PLAYER_LOGIN', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED', 'AUCTION_BIDDER_LIST_UPDATE', 'AUCTION_OWNED_LIST_UPDATE'} do
	event_frame:RegisterEvent(event)
end

ADDON_LOADED = t
do
	local variables_loaded_hooks, player_login_hooks = t, t
	function public.setter.LOAD(f) tinsert(variables_loaded_hooks, f) end
	function public.setter.LOAD2(f) tinsert(player_login_hooks, f) end
	event_frame:SetScript('OnEvent', function()
		if event == 'ADDON_LOADED' then
			if ADDON_LOADED[arg1] then ADDON_LOADED[arg1]() end
		elseif event == 'VARIABLES_LOADED' then
			for _, f in variables_loaded_hooks do f() end
		elseif event == 'PLAYER_LOGIN' then
			for _, f in player_login_hooks do f() end
			log('v'..version..' loaded.')
		else
			_m[event]()
		end
	end)
end