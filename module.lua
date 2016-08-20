local rawget, setmetatable, mask, add, g = rawget, setmetatable, bit.band, bit.bor, getfenv(0)
local DECLARED, ACCESSOR, MUTABLE, PUBLIC = 1, 2, 4, 8
local IMPORTER_KEY, ACCESSOR_KEY, MUTABLE_KEY, PUBLIC_KEY = 'import', 'accessor', 'mutable', 'public'
local PROPERTY = {[ACCESSOR_KEY]=ACCESSOR, [MUTABLE_KEY]=MUTABLE, [PUBLIC_KEY]=PUBLIC}
local _modules, _data, _metadata, _modifiers, _modifier_properties, _imports = {}, {}, {}, {}, {}, {}
local metadata_mt, modifier_mt, env_mt, interface_mt, importer_mt
local modifier_accessor, accessor_modifier_accessor, mutable_modifier_accessor, public_modifier_accessor
local error, locked
function error(message, ...) g.error(format(message, unpack(arg))..'\n'..debugstack(3, 5, 0), 3) end
metadata_mt = {__index=function() return 0 end }
function importer_mt.__call(self, ...)
	local imports = _imports[self]
	for i = 1, arg.n do imports[arg[i]] = true end
end
function modifier_accessor(property)
	return function(modifier) return function() _modifier_properties[modifier] = DECLARED+property return modifier end end
end
accessor_modifier_accessor, mutable_modifier_accessor, public_modifier_accessor = modifier_accessor(ACCESSOR), modifier_accessor(MUTABLE), modifier_accessor(PUBLIC)
modifier_mt = {__metatable=false}
function modifier_mt.__index(self, key)
	local property = PROPERTY[key]
	if not property then error('Unknown modifier "%s".', key) end
	_modifier_properties[self] = add(property, _modifier_properties[self])
	return self
end
function modifier_mt.__newindex(self, key, value)
	if rawget(_metadata[self], key) then error('Field "%s" already exists.', key) end
	_metadata[self][key], _data[self][key] = _modifier_properties[self], value
end
env_mt = {__metatable=false}
function env_mt.__index(self, key)
	local value, properties = _data[self][key], _metadata[self][key]
	if mask(DECLARED + ACCESSOR, properties) == DECLARED then
		return value
	elseif mask(ACCESSOR, properties) == ACCESSOR then
		return value(key)
	else
		return g[key] or error('No field "%s".', key)
	end
end
function env_mt.__newindex(self, key, value)
	if not rawget(_metadata[self], key) then
		_metadata[self][key] = DECLARED
	elseif mask(MUTABLE, _metadata[self][key]) == 0 then
		error('Field "%s" is immutable.', key)
	end
	_data[self][key] = value
end
interface_mt = {__metatable=false}
function interface_mt.__index(self, key)
	local value, properties = _data[self][key], _metadata[self][key]
	if mask(ACCESSOR + PUBLIC, properties) == PUBLIC then
		return value
	elseif mask(PUBLIC, properties) ~= 0 or error('No field "%s".', key) then
		return value(key)
	end
end
function interface_mt.__newindex(self, key, value) self[key](value) end
importer_mt = {__metatable=false}
function g.aux_module(name)
	if not _modules[name] then
		local metadata, data, imports, importer, modifier, env, interface
		imports, importer, modifier, env, interface = {}, setmetatable({}, importer_mt), setmetatable({}, modifier_mt), setmetatable({}, env_mt), setmetatable({}, interface_mt)
		metadata = setmetatable({g=DECLARED, m=DECLARED, [IMPORTER_KEY]=DECLARED, [ACCESSOR_KEY]=ACCESSOR, [MUTABLE_KEY]=ACCESSOR, [PUBLIC_KEY]=ACCESSOR}, metadata_mt)
		data = {g=g, m=env, [IMPORTER_KEY]=importer, [ACCESSOR_KEY]=accessor_modifier_accessor(modifier), [MUTABLE_KEY]=mutable_modifier_accessor(modifier), [PUBLIC_KEY]=public_modifier_accessor(modifier)}
		_metadata[name], _metadata[modifier], _metadata[env], _metadata[interface] = metadata, metadata, metadata, metadata
		_data[name], _data[modifier], _data[env], _data[interface] = data, data, data, data
		_imports[name], _imports[importer] = imports, imports
		_modifiers[name] = modifier
		_modules[name] = {env, interface}
	end
	return _modules[name]
end
local frame = CreateFrame 'Frame'
frame:RegisterEvent 'PLAYER_LOGIN'
frame:SetScript('OnEvent', function()
	locked = true
	local count = 0
	local t0 = GetTime()
	for name in _modules do
		local modifier = _modifiers[name]
		for import_name in _imports[name] do
			if not _modules[import_name] then error('Invalid import %s in %s.', import_name, name) end
			local data = _data[import_name]
			for key, properties in _metadata[import_name] do
				if mask(PUBLIC, properties) ~= 0 then
					_modifier_properties[modifier] = properties
					modifier[key] = data[key]
				end
			end
		end
	end
	aux.log('imported: '..count..' in '..(GetTime()-t0))
end)