local setmetatable, unpack, mask, g = setmetatable, unpack, bit.band, getfenv(0)
local PRIVATE, PUBLIC, MUTABLE, ACCESSOR, MUTATOR = 1, 2, 4, 8, 16
local MODIFIER = {private=PRIVATE, public=PUBLIC, mutable=MUTABLE, accessor=ACCESSOR, mutator=MUTATOR}
local MASK = {private=PUBLIC+MUTABLE+ACCESSOR+MUTATOR, public=PRIVATE+MUTABLE+ACCESSOR+MUTATOR, mutable=PRIVATE+PUBLIC, accessor=PRIVATE+PUBLIC+MUTATOR, mutator=PRIVATE+PUBLIC+ACCESSOR}
local _10, _01, tf, ft = {[true]=1, [false]=0}, {[true]=0, [false]=1}, {true, false}, {false, true}
local importer_mt, declarator_mt, env_mt, interface_mt, lock_mt
local define_property, declarator_accessor, private_accessor, public_accessor, mutable_accessor, accessor_accessor, mutator_accessor, index, error
local _modules, _metadata, _data, _accessors, _mutators, _imports, _declarators, _declarator_state = setmetatable({}, lock_mt), {}, {}, {}, {}, {}, {}, {}
function error(message, ...) g.error(format(message, unpack(arg))..'\n'..debugstack(3, 5, 0), 3) end
importer_mt = {__metatable=false}
function importer_mt.__call(self, t)
	local imports = _imports[self]
	for _, name in t do imports[name] = true end
end
function declarator_accessor(modifier)
	return function(declarator) return function() _declarator_state[declarator] = PRIVATE+modifier return declarator end end
end
private_accessor, public_accessor, mutable_accessor, accessor_accessor, mutator_accessor = declarator_accessor(0), declarator_accessor(PUBLIC), declarator_accessor(MUTABLE), declarator_accessor(ACCESSOR), declarator_accessor(MUTATOR)
function define_property(self, key, t)
	local accessor, mutator = t.get, t.set
	_declarator_state[self] = _01[not accessor]*ACCESSOR + _01[not mutator]*MUTATOR + mask(PRIVATE+PUBLIC, _declarator_state[self])
	_accessors[self][key], _mutators[self][key] = accessor, mutator
end
declarator_mt = {__metatable=false}
function declarator_mt.__index(self, key)
	local modifier = MODIFIER[key]
	if not modifier then return function(t) define_property(self, key, t) end end
	_declarator_state[self] = modifier + mask(MASK[key], _declarator_state[self])
	return self
end
function declarator_mt.__newindex(self, key, value)
	if _metadata[self][key] then error('Field "%s" already exists.', key) end
	_metadata[self][key], _data[self][key], _accessors[self][key], _mutators[self][key] = _declarator_state[self], value, value, value
end
function index(access, default)
	return function(self, key)
		local modifiers = _metadata[self][key] or 0
		if mask(access+ACCESSOR+MUTATOR, modifiers) == access then
--			DEFAULT_CHAT_FRAME:AddMessage(access)
			return _data[self][key]
		elseif mask(access+ACCESSOR, modifiers) == access+ACCESSOR then
			return _accessors[self][key]()
		else
			return default[key] or error('No field "%s".', key)
		end
	end
end
env_mt = {__metatable=false, __index=index(PRIVATE, g)}
function env_mt.__newindex(self, key, value)
	if not _metadata[self][key] then
		_metadata[self][key] = PRIVATE
	elseif mask(MUTATOR, _metadata[self][key]) ~= 0 then
		return _mutators[self][key](value)
	elseif mask(MUTABLE, _metadata[self][key]) == 0 then
		error('Field "%s" is immutable.', key)
	end
	_data[self][key] = value
end
interface_mt = {__metatable=false, __index=index(PUBLIC, {})}
function interface_mt.__newindex(self, key, value)
	if mask(PUBLIC+MUTATOR, _metadata[self][key]) == PUBLIC+MUTATOR then
		return _mutators[self][key](value)
	elseif mask(PUBLIC+MUTABLE, _metadata[self][key]) == PUBLIC+MUTABLE or error('Field "%s" is immutable.', key) then
		_data[self][key] = value
	end
end
lock_mt = {}
function g.aux_module(name)
	if _modules[name] then error('Module %s already exists.', name) end
	local metadata, data, accessors, mutators, imports, importer, declarator, env, interface
	imports, importer, declarator, env, interface = {}, setmetatable({}, importer_mt), setmetatable({}, declarator_mt), setmetatable({}, env_mt), setmetatable({}, interface_mt)
	metadata = setmetatable({g=PRIVATE, m=PRIVATE, import=PRIVATE, private=PRIVATE+ACCESSOR, public=PRIVATE+ACCESSOR, mutable=PRIVATE+ACCESSOR, accessor=PRIVATE+ACCESSOR, mutator=PRIVATE+ACCESSOR}, lock_mt)
	data = {g=g, m=env, import=importer}
	accessors = {private=private_accessor(declarator), public=public_accessor(declarator), mutable=mutable_accessor(declarator), accessor=accessor_accessor(declarator), mutator=mutator_accessor(declarator)}
	mutators = {}
	_metadata[name], _metadata[declarator], _metadata[env], _metadata[interface] = metadata, metadata, metadata, metadata
	_data[name], _data[declarator], _data[env], _data[interface] = data, data, data, data
	_accessors[name], _accessors[declarator], _accessors[env], _accessors[interface] = accessors, accessors, accessors, accessors
	_mutators[name], _mutators[declarator], _mutators[env], _mutators[interface] = mutators, mutators, mutators, mutators
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