local aux_module, getn, setn, tinsert, tremove, setfenv, gfind = aux_module, getn, table.setn, tinsert, tremove, setfenv, string.gfind
do
	local env, interface = aux_module '/core'
	setfenv(1, env)
	g.aux = interface
end

public.version = '5.0.0'

do
	local recycle_frame = CreateFrame 'Frame'
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
	public.accessor.temp = setmetatable({}, {__sub = function(_, t) auto_recycle[t] = true return t end})
	function public.accessor.t() return tremove(table_pool) or {} end
end

do
	local module_envs = t
	function public.module(path)
		local env, parts, parent, name
		parts, parent, name = gfind(path, '[%a_][%w_]*'), aux_module '/modules', ''
		for part in parts do
			name = name..'/'..part
			if not module_envs[name] then
				env, parent.public[part] = aux_module(name)
				env.import(temp-{'modules', 'core', 'util'})
				module_envs[name] = env
			else
				env = module_envs[name]
			end
			parent = env
		end
		setfenv(2, env)
	end
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