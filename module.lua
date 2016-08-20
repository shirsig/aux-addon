local tinsert, setfenv, rawget, rawset, setmetatable, mask, g = tinsert, setfenv, rawget, rawset, setmetatable, bit.band, getfenv(0)
local DECLARED, ACCESSOR, MUTABLE, PUBLIC = 1, 2, 4, 8
local ACCESSOR_KEY, MUTABLE_KEY, PUBLIC_KEY = 'accessor', 'mutable', 'public'
local PROPERTY = {[ACCESSOR_KEY]=ACCESSOR, [MUTABLE_KEY]=MUTABLE, [PUBLIC_KEY]=PUBLIC}
local _data, _metadata, _modifier_properties, _imports, _envs, _interfaces = {}, {}, {}, {}, {}, {}
local metadata_mt = {
	__index=function() return 0 end,
	__newindex=function(self, key, value)
		if rawget(self, key) then error('Duplicate key "'..key..'".', 3) end
		rawset(self, key, value)
	end,
}
local env_mt = {
	__metatable = false,
	__index = function(self, key)
		local value, properties = _data[self][key], _metadata[self][key]
		if mask(DECLARED+ACCESSOR, properties) == DECLARED then
			return value
		elseif mask(ACCESSOR, properties) == ACCESSOR then
			return value(key)
		else
			for _, name in _imports[self] do
				local interface = _interfaces[name]
				if interface and mask(PUBLIC, _metadata[interface][key]) ~= 0 then
					return interface[key]
				end
			end
			return g[key] or error('No key "'..key..'".', 2)
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
		elseif mask(PUBLIC, properties) ~= 0 then
			return value(key)
		else
			error('No key "'..key..'".', 2)
		end
	end,
	__newindex = function(self, key, value) self[key](value) end,
}
local modifier_mt = {
	__metatable = false,
	__index = function(self, key)
		local property = PROPERTY[key]
		if not property then error('Unsupported modifier "'..key..'".', 2) end
		if mask(property, _modifier_properties[self]) ~= 0 then error('Duplicate modifier "'..key..'".', 2) end
		_modifier_properties[self] = _modifier_properties[self] + property
		return self
	end,
	__newindex = function(self, key, value)
		_data[self][key] = value
		_metadata[self][key] = _modifier_properties[self]
	end,
}
local importer_mt = {
	__call = function(self, ...)
		for i=1,arg.n do
			tinsert(_imports[self], arg[i])
		end
   end,
}
function g.aux_module(name)
	if _interfaces[name] then error('Duplicate module "'..name..'".', 2) end

	local data, metadata, imports, importer, modifier, env, interface, modifier_accessor
	modifier, importer, env, interface = setmetatable({}, modifier_mt), setmetatable({}, importer_mt), setmetatable({}, env_mt), setmetatable({}, interface_mt)
	function modifier_accessor(key) _modifier_properties[modifier] = DECLARED+PROPERTY[key] return modifier end
	data = {g=g, m=env, import=importer, [ACCESSOR_KEY]=modifier_accessor, [MUTABLE_KEY]=modifier_accessor, [PUBLIC_KEY]=modifier_accessor}
	metadata = setmetatable({g=DECLARED, m=DECLARED, import=DECLARED, [ACCESSOR_KEY]=ACCESSOR, [MUTABLE_KEY]=ACCESSOR, [PUBLIC_KEY]=ACCESSOR}, metadata_mt)
	imports = {}

	_envs[name], _interfaces[name] = env, interface
	_data[modifier], _data[env], _data[interface] = data, data, data
	_metadata[modifier], _metadata[env], _metadata[interface] = metadata, metadata, metadata
	_imports[importer], _imports[env] = imports, imports

	env.mutable.__ = nil -- TODO

	setfenv(2, env)
	return interface
end