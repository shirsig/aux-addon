local aux_module, setn, tinsert, tremove, setfenv = aux_module, table.setn, tinsert, tremove, setfenv
local aux = aux_module 'core'
_g.aux = aux.interface
public.version = '5.0.0'

do
	local table_pool, auto_recycle = {}, {}
	local function wipe(t) -- like with a cloth or something
		for k in t do t[k] = nil end
		setn(t, 0); return t
	end
	function public.recycle(t)
		auto_recycle[t] = nil
		tinsert(table_pool, wipe(t))
--		log(getn(table_pool))
	end
	public.temp = setmetatable({}, {__sub = function(_, t) auto_recycle[t] = true return t end})
	function public.t.get() return tremove(table_pool) or {} end
	CreateFrame('Frame'):SetScript('OnUpdate', function()
		for t in auto_recycle do recycle(t) end
		recycle(auto_recycle); auto_recycle = t
	end)
end

do
	local modules = {}
	local function module_env(name) aux_module(name) return _m end
	function public.module(name)
		local env = module_env(name)
		if not modules[name] then env.import(temp-{['']='modules', ['']='core', ['']='util'}) end
		setfenv(2, env); modules[name] = true
	end
end

local event_frame = CreateFrame 'Frame'
for _, event in temp-{'ADDON_LOADED', 'VARIABLES_LOADED', 'PLAYER_LOGIN', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED', 'AUCTION_BIDDER_LIST_UPDATE', 'AUCTION_OWNED_LIST_UPDATE'} do
	event_frame:RegisterEvent(event)
end

ADDON_LOADED = {}
do
	local variables_loaded_hooks, player_login_hooks = t, t
	function public.LOAD.set(f) tinsert(variables_loaded_hooks, f) end
	function public.LOAD2.set(f) tinsert(player_login_hooks, f) end
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