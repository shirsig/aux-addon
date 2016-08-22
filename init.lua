function INIT()
	import :_ 'core' :_ 'util'
	function LOAD()
		import :_ 'core' :_ 'control' :_ 'util'
	end
end

module 'core'
public.version = '5.0.0'

do
	local table_pool, temporary = {}, {}

	CreateFrame'Frame':SetScript('OnUpdate', function()
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
		temporary[t] = nil
		wipe(t)
		tinsert(table_pool, t)
	end

	function public.accessor.t() return
		tremove(table_pool) or {}
	end

	function public.accessor.tt()
		local t = tremove(table_pool) or {}
		temporary[t] = true
		return t
	end

	do
		local mt = {
			__call=function(self, arg) return self[1](arg) end,
			__sub=function(self, arg) return self[1](arg) end,
		}
		function public.modifier(f)
			local self = t
			self[1] = f
			return setmetatable(self, mt)
		end
	end

	public.tmp = modifier(function(t)
		temporary[t] = true
		return t
	end)

	do
		local mt = {
			__call=function(self, arg1, arg2)
				tinsert(self, arg2 or arg1)
				return self
			end,
			__index=function(self, key)
				tinsert(self, key)
				return self
			end,
		}
		function public.accessor.from()
			return setmetatable(tt, mt)
		end
	end

	do
		local mt = {__call = function(self, key) return self[key] end}
		public.set = modifier(function(table)
			local self = t
			for _, v in table do self[v] = true end
			recycle(table)
			return setmetatable(self, mt)
		end)
	end

	public.array = modifier(function(table)
		local self = t
		for _, v in table do tinsert(self, v) end
		recycle(table)
		return self
	end)

	-- TODO map
end

local event_frame = CreateFrame 'Frame'
for event in tmp-set-from . ADDON_LOADED . VARIABLES_LOADED . PLAYER_LOGIN . AUCTION_HOUSE_SHOW . AUCTION_HOUSE_CLOSED . AUCTION_BIDDER_LIST_UPDATE . AUCTION_OWNED_LIST_UPDATE do
	event_frame:RegisterEvent(event)
end

ADDON_LOADED = t
do
	local variables_loaded_hooks, player_login_hooks = t, t
	function public.mutator.LOAD(f) tinsert(variables_loaded_hooks, f) end
	function public.mutator.LOAD2(f) tinsert(player_login_hooks, f) end
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