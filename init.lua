setglobal('aux', aux_module 'core')
import 'util'

public.version = '5.0.0'

do
	local setn = g.table.setn
	local table_pool, locked = {}
	local function wipe(t) -- like with a cloth or something
		for k in t do t[k] = nil end
		setn(t, 0)
		return t
	end
	local function release(t)
		locked[t] = nil
		tinsert(table_pool, t)
	end
	function public.temp()
		local t = tremove(table_pool)
		t = t and wipe(t) or {}
		locked[t] = true
	end
	function public.static()
		local t = tremove(table_pool)
		t = t and wipe(t) or {}
		locked[t] = true
	end
	function public.array(...) locked[arg] = true end
	function public.set(...)
		local set = temp()
		for i=1,arg.n do self[arg[i]] = true end
		return set
	end
end
local temp = temp

do
	local aux_module, getfenv, setfenv, gfind, tinsert = g.aux_module, g.getfenv, g.setfenv, g.string.gfind, g.tinsert
	local root = (function() aux_module 'modules' return getfenv() end)()
	function public.module(path)
		local parts = gfind(path, '[%a_][%w_]*')
		local name = parts() or ''
		local env = root
		for part in parts do
			env.public[part], env = (function() return aux_module(name), getfenv() end)()
			env.import('modules', 'core', 'util')
			name = name..'.'..part
		end
		setfenv(2, env)
	end
end

local event_frame = CreateFrame 'Frame'
for _, event in {'VARIABLES_LOADED', 'ADDON_LOADED', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED', 'AUCTION_BIDDER_LIST_UPDATE', 'AUCTION_OWNED_LIST_UPDATE'} do
	event_frame:RegisterEvent(event)
end
ADDON_LOADED = {}
event_frame:SetScript('OnEvent', function()
	if event == 'ADDON_LOADED' then
		if ADDON_LOADED[arg1] then
			ADDON_LOADED[arg1]()
		end
	else
		m[event]()
		if event == 'VARIABLES_LOADED' then
			for _, env in module_envs do
				if env.LOAD then
					env.LOAD()
				end
			end
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
