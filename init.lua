setglobal('aux', aux_module 'core')

public.version = '5.0.0'

local temp
do
	local setn, tinsert, tremove = g.table.setn, g.tinsert, g.tremove
	local table_pool, locked = {}, {}
	local function wipe(t) -- like with a cloth or something
		for k in t do t[k] = nil end
		setn(t, 0)
		return t
	end
	local function release(t)
		locked[t] = nil
		tinsert(table_pool, t)
		aux.log(getn(table_pool))
	end
	function temp()
		local t = tremove(table_pool)
		t = t and wipe(t) or {}
		locked[t] = true
	end
	public.temp = temp
	function public.static()
		local t = tremove(table_pool)
		t = t and wipe(t) or {}
		locked[t] = true
	end
	function public.array(...) locked[arg] = true end
	function public.set(...)
		local set = temp()
		for i=1,arg.n do set[arg[i]] = true end
		release(arg)
		return set
	end
end

do
	local aux_module, getfenv, setfenv, gfind = g.aux_module, g.getfenv, g.setfenv, g.string.gfind
	aux_module 'modules'
	function public.module(path)
		local parts, name, env
		parts, name = gfind(path, '[%a_][%w_]*'), 'modules'
		for part in parts do
			env.public[part], env = (function() return aux_module(name), getfenv() end)()
			env.import('modules', 'core', 'util')
			name = name..'/'..part
		end
		setfenv(2, env)
	end
end

local event_frame = CreateFrame 'Frame'
for _, event in {'VARIABLES_LOADED', 'ADDON_LOADED', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED', 'AUCTION_BIDDER_LIST_UPDATE', 'AUCTION_OWNED_LIST_UPDATE'} do
	event_frame:RegisterEvent(event)
end

LOADED, LOADED2, ADDON_LOADED = {}, {}, {}
function public.accessor.LOAD(f) tinsert(LOAD, f) end
event_frame:SetScript('OnEvent', function()
	if event == 'ADDON_LOADED' then
		if ADDON_LOADED[arg1] then
			ADDON_LOADED[arg1]()
		end
	else
		m[event]()
		if event == 'VARIABLES_LOADED' then
--			for _, env in module_envs do
--				if env.LOAD then
--					env.LOAD()
--				end
--			end
			log('v'..version..' loaded.')
		end
	end
end)

function public.log(...)
	local msg = '[aux]'
	for i=1,arg.n do
		msg = msg..' '..tostring(arg[i])
	end
	DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE..msg)
end
