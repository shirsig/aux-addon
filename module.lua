local DECLARED, MUTABLE, PUBLIC = 1, 2, 4
local DECLARED_KEY, MUTABLE_KEY, PUBLIC_KEY = 'declared', 'mutable', 'public'
local MODIFIER_VALUE = {[DECLARED_KEY]=DECLARED, [MUTABLE_KEY]=MUTABLE, [PUBLIC_KEY]=PUBLIC}

local band, bor, bnot = bit.band, bit.bor, bit.bnot
local _G = getfenv(0)

local _state, _data, _metadata  = {}, {}, setmetatable({}, {__index=function() return 0 end})

--local function_mt = {
--	__call = function(self, ...)
--		local f = state[self]
--		getfenv(f).__ = {}
--		f(unpack(arg))
--		getfenv(f).__ = temp
--	end,
--}
--local method_mt = {
--	__call = function(self, ...)
--		local f = self[1]
--		local temp = getfenv(f)
--		setfenv(f, state[self])
--		f(...)
--		setfenv(f, temp)
--	end,
--}
local environment_mt = {
	__metatable = false,
	__index = function(self, key)
		if _metadata[self][key] == 0 then return _G[key] or error('No key "'..key..'".', 2) end
		return _data[self][key]
	end,
	__newindex = function(self, key, value)
		local m = _metadata[self][key]
		if band(bor(DECLARED, MUTABLE), m) == DECLARED then error('"'..key..'" is immutable.', 2) end
		_data[self][key] = value
		_metadata[self][key] = bor(1, m)
	end,
}
local interface_mt = {
	__metatable = false,
	__index = function(self, key)
		if band(PUBLIC_V, _metadata[self][key]) == 0 then error('No key "'..key..'".', 2) end
		return _data[self][key]
	end,
	__newindex = function() error('Unsupported operation.', 2) end,
}
local modifier_mt = {
	__metatable = false,
	__call = function(self, key)
		_state[self] = MODIFIER_VALUE[key]
	end,
	__index = function(self, key)
		local value = MODIFIER_VALUE[key]
		if not value then error('Unsupported operation.', 2) end
		_state[self] = bor(_state[self], value)
		return self
	end,
	__newindex = function(self, key, value)
		if _metadata[self][key] then error('Duplicate key "'..key..'".', 2) end
		_data[self][key] = value
		_metadata[self][key] = bor(_state[self], DECLARED)
	end,
}
function aux_module()
	local modifier, environment, interface = setmetatable({}, modifier_mt), setmetatable({}, environment_mt), setmetatable({}, interface_mt)
	local data, metadata = {mutable=modifier, public=modifier}, {mutable=1, public=1}

	_data[modifier], _data[environment], _data[interface] = data, data, data
	_metadata[modifier], _metadata[environment], _metadata[interface] = metadata, metadata, metadata
	_state[modifier] = 1

	environment.mutable.__()
	environment.m = environment -- TODO for compatibility, remove later

	setfenv(2, environment)
	return interface
end