local aux_module, getn, setn, tinsert, tremove, setfenv, gfind = aux_module, getn, table.setn, tinsert, tremove, setfenv, string.gfind
do
	local env, interface = aux_module 'core'
	setfenv(1, env)
	g.aux = interface
end

public.version = '5.0.0'

local temp, recycle
do
	local table_pool, locked = {}, {}
	local function wipe(t) -- like with a cloth or something
		for k in t do t[k] = nil end
		setn(t, 0)
		return t
	end
	function recycle(t)
		locked[t] = nil
		tinsert(table_pool, t)
		log(getn(table_pool))
	end
	public.recycle = recycle
	temp = setmetatable({}, {
		__call = function()
			local t = tremove(table_pool)
			t = t and wipe(t) or {}
			locked[t] = true
		end,
		__sub = function(_, t) locked[t] = true return t end,
	})
	public.temp = temp
end

do
	function public.module(path)
		local env, parts, parent, name
		parts, parent, name = gfind(path, '[%a_][%w_]*'), aux_module 'modules', ''
		for part in parts do
			name = name..'/'..part
			env, parent.public[part] = aux_module(name)
			env.import('modules', 'core', 'util')
			parent = env
		end
		setfenv(2, env)
	end
end

local event_frame = CreateFrame 'Frame'
for event in temp-set{'VARIABLES_LOADED', 'ADDON_LOADED', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED', 'AUCTION_BIDDER_LIST_UPDATE', 'AUCTION_OWNED_LIST_UPDATE'} do
	event_frame:RegisterEvent(event)
end

ADDON_LOADED = {}
do
	local variables_loaded_hooks, player_login_hooks = {}, {}
	function public.accessor.LOAD(f) tinsert(variables_loaded_hooks, f) end
	function public.accessor.LOAD2(f) tinsert(player_login_hooks, f) end
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

function public.log(...)
	local msg = '[aux]'
	for i=1,arg.n do msg = msg..' '..tostring(arg[i]) end
	DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE..msg)
end
