function INIT()
	import :_ 'core' :_ 'control' :_ 'util'
end

module 'core'
public.version = '5.0.0'

do
	local table_pool, temporary = {}, {}

	CreateFrame 'Frame' :SetScript('OnUpdate', function()
		for t in temporary do
			recycle(t)
			log(getn(table_pool))
		end
		wipe(temporary)
	end)

	function public.wipe(t) -- like with a cloth or something
		for k in t do
			t[k] = nil
		end
		table.setn(t, 0)
	end

	function public.recycle(t)
		auto_recycle[t] = nil
		wipe(t)
		tinsert(table_pool, t)
	end

	function public.getter.t() return
		tremove(table_pool) or {}
	end

	function public.getter.tt()
		local t = tremove(table_pool) or {}
		temporary[t] = true
		return t
	end

	public.tmp = setmetatable({}, {__sub = function(_, t) temporary[t] = true return t end})


	do
		local mt = {
			__call=function(self, arg1, arg2) tinsert(self, arg2 or arg1); return self; end,
			__index=function(self, key) tinsert(self, key); return self; end,
		}
		function public.getter.from()
			return setmetatable(tt, mt)
		end
	end

	do
		local mt = {
			__call=function(self, arg) return self[1](arg) end,
			__unm=function(self, arg) return self[1](arg) end,
		}
		function public.modifier(f)
			local self = t; t[1] = f
			return setmetatable(self, mt)
		end
	end

	do
		local mt = {__call = function(self, key) return self[key] end}
		public.getter.set = modifier(function(table)
			local self = t
			for _, v in table do self[v] = true end
			recycle(table)
			return setmetatable(self, mt)
		end)
	end



	function public.array(table)
		local array = t
		for k, v in table do tinsert(array, v) end
		return array
	end

	do
		local mt = {
			__call=function(self, arg1, arg2) self[arg2 or arg1] = true; return self; end,
			__index=function(self, key) self[key] = true; return self; end,
		}
		function public.getter.metaset()
			return setmetatable(t, mt)
		end
	end

	do
		local mt = {
			__call=function(self, arg1, arg2) self[arg2 or arg1] = true; return self; end,
			__index=function(self, key) tinsert(self, key); return self; end,
		}
		function public.getter.metamap()
			return setmetatable(t, mt)
		end
	end
end

local event_frame = CreateFrame 'Frame'
for _, event in tmp-{'ADDON_LOADED', 'VARIABLES_LOADED', 'PLAYER_LOGIN', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED', 'AUCTION_BIDDER_LIST_UPDATE', 'AUCTION_OWNED_LIST_UPDATE'} do
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