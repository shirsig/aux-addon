local mask, _G = bit.band, getfenv(0)
local DECLARED, ACCESSOR, MUTABLE, PUBLIC = 1, 2, 4, 8
local ACCESSOR_KEY, MUTABLE_KEY, PUBLIC_KEY = 'accessor', 'mutable', 'public'
local PROPERTY = {[ACCESSOR_KEY]=ACCESSOR, [MUTABLE_KEY]=MUTABLE, [PUBLIC_KEY]=PUBLIC}
local _data, _metadata, _modifier_properties = {}, {}, {}
local metadata_mt = {__index=function() return 0 end}
local env_mt = {
	__metatable = false,
	__index = function(self, key)
		local value, properties = _data[self][key], _metadata[self][key]
		if mask(DECLARED+ACCESSOR, properties) == DECLARED then
			return value
		elseif mask(ACCESSOR, properties) == ACCESSOR then
			return value(key)
		else
			return _G[key] or error('No key "'..key..'".', 2)
		end
	end,
	__newindex = function(self, key, value)
		local properties = _metadata[self][key]
		if properties == 0 then
			_metadata[self][key] = DECLARED
--		elseif mask(MUTABLE, properties) == 0 then
--			error('"'..key..'" is immutable.', 2)
		end
		_data[self][key] = value
	end,
}
local interface_mt = {
	__metatable = false,
	__index = function(self, key)
		local value, properties = _data[self][key], _metadata[self][key]
		if mask(ACCESSOR+PUBLIC, properties) == PUBLIC then
			return value
		elseif mask(PUBLIC, properties) == PUBLIC then
			return value(key)
		else
			error('No key "'..key..'".', 2)
		end
	end,
	__newindex = function(self, key, value) self[key](value) end,
}
local modifier_mt = {
	__metatable = false,
	__call = function() end,
	__index = function(self, key)
		local property = PROPERTY[key]
		if not property then error('Unsupported modifier "'..key..'".', 2) end
		if mask(property, _modifier_properties[self]) ~= 0 then error('Duplicate modifier "'..key..'".', 2) end
		_modifier_properties[self] = _modifier_properties[self] + property
		return self
	end,
	__newindex = function(self, key, value)
		if _metadata[self][key] ~= 0 then error('Duplicate key "'..key..'".', 2) end
		_data[self][key] = value
		_metadata[self][key] = _modifier_properties[self]
	end,
}
function _G.aux_module()
	local data, metadata, modifier, env, interface
	modifier = setmetatable({}, modifier_mt) env = setmetatable({}, env_mt) interface = setmetatable({}, interface_mt)
	local function modifier_accessor(key) _modifier_properties[modifier] = DECLARED+PROPERTY[key] return modifier end
	data = {_G=_G, m=env, [ACCESSOR_KEY]=modifier_accessor, [MUTABLE_KEY]=modifier_accessor, [PUBLIC_KEY]=modifier_accessor}
	metadata = setmetatable({_G=DECLARED, m=DECLARED, [ACCESSOR_KEY]=ACCESSOR, [MUTABLE_KEY]=ACCESSOR, [PUBLIC_KEY]=ACCESSOR}, metadata_mt)

	_data[modifier], _data[env], _data[interface] = data, data, data
	_metadata[modifier], _metadata[env], _metadata[interface] = metadata, metadata, metadata

	env.mutable.__ = nil

	setfenv(2, env)
	return interface
end