local band, bor, bnot = bit.band, bit.bor, bit.bnot
local _G = getfenv(0)

local FIELD, ACCESSOR, MUTABLE, PUBLIC = 1, 2, 4, 8
local ACCESSOR_KEY, MUTABLE_KEY, PUBLIC_KEY = 'accessor', 'mutable', 'public'
local MODIFIER = {[ACCESSOR_KEY]=ACCESSOR, [MUTABLE_KEY]=MUTABLE, [PUBLIC_KEY]=PUBLIC}

local _state, _data, _metadata  = {}, {}, {}

--local function_mt = {
--	__call = function(self, ...)
--		local f = state[self]
--		getfenv(f).__ = {}
--		f(unpack(arg))
--		getfenv(f).__ = temp
--	end,
--}
local metadata_mt = {__index=function() return 0 end}
local environment_mt = {
	__metatable = false,
	__index = function(self, key)
		local value, properties = _data[self][key], _metadata[self][key]
		if band(FIELD, properties) ~= 0 then
			return value
		elseif band(ACCESSOR, properties) ~= 0 then
			return value(key)
		else
			return _G[key] or error('No key "'..key..'".', 2)
		end
	end,
	__newindex = function(self, key, value)
		local properties = _metadata[self][key]
		if properties == 0 then
			_metadata[self][key] = FIELD
		elseif band(MUTABLE, properties) == 0 then
			error('"'..key..'" is immutable.', 2)
		end
		_data[self][key] = value
	end,
}
local interface_mt = {
	__metatable = false,
	__index = function(self, key)
		local value, properties = _data[self][key], _metadata[self][key]
		if band(FIELD, properties) ~= 0 then
			return value
		elseif band(ACCESSOR, properties) ~= 0 then
			return value(key)
		else
			error('No key "'..key..'".', 2)
		end
	end,
	__newindex = function() error('Unsupported operation.', 2) end,
}
local modifier_mt = {
	__metatable = false,
	__call = function(self, key)
		_state[self] = bor(_state[self], MODIFIER[key])
		return self
	end,
	__index = function(self, key)
		local value = MODIFIER[key]
		if not value then error('Unsupported operation.', 2) end
		_state[self] = bor(_state[self], value)
		return self
	end,
	__newindex = function(self, key, value)
		if _metadata[self][key] ~= 0 then error('Duplicate key "'..key..'".', 2) end
		_data[self][key] = value
		_metadata[self][key] = _state[self]
		_state[self] = 0
	end,
}
function aux_module()
	local modifier, environment, interface = setmetatable({}, modifier_mt), setmetatable({}, environment_mt), setmetatable({}, interface_mt)
	local data = {[ACCESSOR_KEY]=modifier, [MUTABLE_KEY]=modifier, [PUBLIC_KEY]=modifier}
	local metadata = setmetatable({[ACCESSOR_KEY]=ACCESSOR, [MUTABLE_KEY]=ACCESSOR, [PUBLIC_KEY]=ACCESSOR}, metadata_mt)

	_data[modifier], _data[environment], _data[interface] = data, data, data
	_metadata[modifier], _metadata[environment], _metadata[interface] = metadata, metadata, metadata
	_state[modifier] = 0

	environment.mutable.__ = nil
	environment.m = environment -- TODO for compatibility, remove later
	environment.private = environment -- TODO for compatibility, remove later

	setfenv(2, environment)
	return interface
end