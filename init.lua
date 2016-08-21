local aux_module, getn, setn, tinsert, tremove, getfenv, setfenv, gfind = aux_module, getn, table.setn, tinsert, tremove, getfenv, setfenv, string.gfind
setfenv(1, aux_module '/core')

public.version = '5.0.0'

do
	local table_pool, auto_recycle = {}, {}
	local function wipe(t) -- like with a cloth or something
		for k in t do t[k] = nil end
		setn(t, 0)
		return t
	end
	function public.recycle(t)
		auto_recycle[t] = nil
		tinsert(table_pool, wipe(t))
		log(getn(table_pool))
	end
	public.temp = setmetatable({}, {__sub = function(_, t) auto_recycle[t] = true return t end})
	function public.accessor.t() return tremove(table_pool) or {} end
	CreateFrame('Frame'):SetScript('OnUpdate', function()
		for t in auto_recycle do recycle(t) end
		recycle(auto_recycle)
		auto_recycle = t
	end)
end

do
	function public.module(name)
		local env, interface = aux_module(name)
		env.import(temp-{'modules', 'core', 'util'})
		setfenv(2, parent)
	end
	g.aux = module 'core'
end

local event_frame = CreateFrame 'Frame'
for _, event in temp-{'VARIABLES_LOADED', 'ADDON_LOADED', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED', 'AUCTION_BIDDER_LIST_UPDATE', 'AUCTION_OWNED_LIST_UPDATE'} do
	event_frame:RegisterEvent(event)
end

ADDON_LOADED = {}
do
	local variables_loaded_hooks, player_login_hooks = t, t
	function public.mutator.LOAD(f) tinsert(variables_loaded_hooks, f) end
	function public.mutator.LOAD2(f) tinsert(player_login_hooks, f) end
	event_frame:SetScript('OnEvent', function()
		if event == 'ADDON_LOADED' then
			if ADDON_LOADED[arg1] then ADDON_LOADED[arg1]() end
		else
			m[event]()
			if event == 'VARIABLES_LOADED' then
				for _, f in variables_loaded_hooks do f() end
			end
			if event == 'PLAYER_LOGIN' then
				for _, f in player_login_hooks do f() end
				log('v'..version..' loaded.')
			end
		end
	end)
end