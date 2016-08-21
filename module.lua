local type, setmetatable, unpack, mask, g = type, setmetatable, unpack, bit.band, getfenv(0)
local PRIVATE, PUBLIC, MUTABLE, GETTER, SETTER = 1, 2, 4, 8, 16
local MODIFIER = {private=PRIVATE, public=PUBLIC, mutable=MUTABLE, getter=GETTER, setter=SETTER}
local MASK = {private=PUBLIC+MUTABLE+GETTER+SETTER, public=PRIVATE+MUTABLE+GETTER+SETTER, mutable=PRIVATE+PUBLIC, getter=PRIVATE+PUBLIC+SETTER, setter=PRIVATE+PUBLIC+GETTER}
local t1f0, t0f1 = {[true]=1, [false]=0}, {[true]=0, [false]=1}
local importer_mt, declarator_mt, env_mt, interface_mt, lock_mt
local define_property, declarator_getter, private_getter, public_getter, mutable_getter, accessor_getter, mutator_getter, index, error
local _modules, _metadata, _data, _getters, _setters, _imports, _declarators, _declarator_state = setmetatable({}, lock_mt), {}, {}, {}, {}, {}, {}, {}
function error(message, ...) g.error(format(message, unpack(arg))..'\n'..debugstack(3, 5, 0), 3) end
importer_mt = {__metatable=false}
function importer_mt.__call(self, t)
	local imports = _imports[self]
	for _, name in t do imports[name] = true end
end
function declarator_getter(modifier)
	return function(declarator) return function() _declarator_state[declarator] = PRIVATE+modifier return declarator end end
end
private_getter, public_getter, mutable_getter, accessor_getter, mutator_getter = declarator_getter(0), declarator_getter(PUBLIC), declarator_getter(MUTABLE), declarator_getter(GETTER), declarator_getter(SETTER)
function define_property(self, key, t)
	local getter, setter = t.get, t.set
	_declarator_state[self] = t0f1[not getter]*GETTER + t0f1[not setter]*SETTER + mask(PRIVATE+PUBLIC, _declarator_state[self])
	_getters[self][key], _setters[self][key] = getter, setter
end
declarator_mt = {__metatable=false}
function declarator_mt.__index(self, key)
	local modifier = MODIFIER[key]
	if not modifier then return function(t) define_property(self, key, t) end end
	_declarator_state[self] = modifier + mask(MASK[key], _declarator_state[self])
	return self
end
function declarator_mt.__newindex(self, key, value)
	local modifiers = _declarator_state[self]
	if modifiers then error('Field "%s" already exists.', key) end
	_metadata[self][key] = modifiers
	if mask(GETTER+SETTER, modifiers) == 0 then
		_data[self][key] = value
	elseif type(value) == 'function' or error('Getters/setters must be functions.') then
		_getters[self][key], _setters[self][key] = value, value
	end
end
function index(access, default)
	return function(self, key)
		local modifiers = _metadata[self][key] or 0
		if mask(access+GETTER+SETTER, modifiers) == access then
			return _data[self][key]
		elseif mask(access+GETTER, modifiers) == access+GETTER then
			return _getters[self][key]()
		else
			return default[key] or error('No field "%s".', key)
		end
	end
end
env_mt = {__metatable=false, __index=index(PRIVATE, g)}
function env_mt.__newindex(self, key, value)
	if not _metadata[self][key] then
		_metadata[self][key] = PRIVATE
	elseif mask(SETTER, _metadata[self][key]) ~= 0 then
		return _setters[self][key](value)
	elseif mask(MUTABLE, _metadata[self][key]) == 0 then
		error('Field "%s" is immutable.', key)
	end
	_data[self][key] = value
end
interface_mt = {__metatable=false, __index=index(PUBLIC, {})}
function interface_mt.__newindex(self, key, value)
	if mask(PUBLIC+SETTER, _metadata[self][key]) == PUBLIC+SETTER then
		return _setters[self][key](value)
	elseif mask(PUBLIC+MUTABLE, _metadata[self][key]) == PUBLIC+MUTABLE or error('Field "%s" is immutable.', key) then
		_data[self][key] = value
	end
end
lock_mt = {}
function g.aux_module(name)
	if _modules[name] then error('Module %s already exists.', name) end
	local metadata, data, getters, setters, imports, importer, declarator, env, interface
	imports, importer, declarator, env, interface = {}, setmetatable({}, importer_mt), setmetatable({}, declarator_mt), setmetatable({}, env_mt), setmetatable({}, interface_mt)
	metadata = setmetatable({g=PRIVATE, m=PRIVATE, import=PRIVATE, private=PRIVATE+GETTER, public=PRIVATE+GETTER, mutable=PRIVATE+GETTER, getter=PRIVATE+GETTER, setter=PRIVATE+GETTER}, lock_mt)
	data = {g=g, m=env, import=importer}
	getters = {private=private_getter(declarator), public=public_getter(declarator), mutable=mutable_getter(declarator), getter=accessor_getter(declarator), setter=mutator_getter(declarator)}
	setters = {}
	_metadata[name], _metadata[declarator], _metadata[env], _metadata[interface] = metadata, metadata, metadata, metadata
	_data[name], _data[declarator], _data[env], _data[interface] = data, data, data, data
	_getters[name], _getters[declarator], _getters[env], _getters[interface] = getters, getters, getters, getters
	_setters[name], _setters[declarator], _setters[env], _setters[interface] = setters, setters, setters, setters
	_imports[name], _imports[importer] = imports, imports
	_declarators[name] = declarator
	_modules[name] = true
	return env, interface
end
local frame = CreateFrame 'Frame'
frame:RegisterEvent 'PLAYER_LOGIN'
frame:SetScript('OnEvent', function()
	lock_mt.__newindex = function() error 'Cannot change modules after the loading phase.' end
	local count = 0
	local t0 = GetTime()
	for name in _modules do
		local declarator = _declarators[name]
		for import_name in _imports[name] do
			if not _modules[import_name] then error('Invalid import %s in %s.', import_name, name) end
			local data = _data[import_name]
			for key, modifiers in _metadata[import_name] do
				if mask(PUBLIC, modifiers) ~= 0 then
					count = count + 1
					_declarator_state[declarator] = modifiers
					declarator[key] = data[key]
				end
			end
		end
	end
	log('imported: '..count..' in '..(GetTime()-t0))
end)