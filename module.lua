local type, setmetatable, setfenv, unpack, mask, _g = type, setmetatable, setfenv, unpack, bit.band, getfenv(0)
local PRIVATE, PUBLIC, MUTABLE, PROPERTY, ACCESSOR, MUTATOR = 0, 1, 2, 4, 8, 16
local error, import_error, modifier_error, property_error, immutable_error, collision_error, set_property, env_mt, interface_mt, declarator_mt, importer_mt
local _state, _modules = {}, {}
function error(message, ...) return _g.error(format(message, unpack(arg))..'\n'..debugstack(1, 15, 5), 0) end
import_error, modifier_error, property_error = function() error 'Invalid modifiers.' end, function() error 'Invalid modifiers.' end, function() error 'Accessor/Mutator must be function.' end
immutable_error, collision_error = function(key) error('Field "%s" is immutable.', key) end, function(key) error('Field "%s" already exists.', key) end
importer_mt = {__metatable=false}
function importer_mt.__index(self, key)
	if type(key) ~= 'string' then import_error() end
	_state[self][self] = key; return self
end
function importer_mt.__call(self, arg1, arg2)
	local name, state, module, alias
	name = arg2 or arg1
	if type(name) ~= 'string' then import_error() end
	state, module = _state[self], _modules[name]
	alias, state[self] = state[self] or name, nil
	if module then
		if alias == '' then
			for key, modifiers in module.metadata do
				if not state.metadata[key] and mask(PUBLIC, modifiers) ~= 0 then
					state.metadata[key], state.data[key], state.accessors[key], state.mutators[key] = modifiers, module.data[key], module.accessors[key], module.mutators[key]
				end
			end
		elseif not state.metadata[alias] then
			state.metadata[alias], state.data[alias] = PRIVATE, module.interface
		end
	end
	return self
end
function set_property(metadata, data, modifier, key, f)
	if key and not data[key] and (type(f) == 'function' or property_error()) then
		metadata[key] = metadata[key] + modifier
		data[key] = f
	end
end
declarator_mt = {__metatable=false}
do
	local MODIFIER = {private=PRIVATE, public=PUBLIC, mutable=MUTABLE, accessor=ACCESSOR+PROPERTY, mutator=MUTATOR+PROPERTY}
	local MODIFIER_MASK, PROPERTY_MASK = {private=MUTABLE+ACCESSOR+MUTATOR, public=ACCESSOR+MUTATOR, mutable=PRIVATE, accessor=PRIVATE+PUBLIC, mutator=PRIVATE+PUBLIC}, PRIVATE+PUBLIC
	function declarator_mt.__index(self, key)
		local state, modifier = _state[self], MODIFIER[key]; local modifiers = state.modifiers
		if modifier then
			if mask(MODIFIER_MASK[key], modifiers) ~= modifiers then modifier_error() end
			state.modifiers = modifiers + modifier
		elseif not state.metadata[key] or collision_error(key) then
			if mask(PROPERTY_MASK, modifiers) ~= modifiers then modifier_error() end
			state.property, state.metadata[key], state.modifiers = key, modifiers + PROPERTY, PRIVATE
		end
		return self
	end
end
function declarator_mt.__newindex(self, key, value)
	local state = _state[self]
	if state.metadata[key] then collision_error(key) end
	state.metadata[key] = state.modifiers
	if mask(PROPERTY, state.modifiers) == 0 then
		state.data[key] = value
	elseif type(value) == 'function' or property_error() then
		local data = mask(ACCESSOR, state.modifiers) ~= 0 and state.accessors or state.mutators
		state.property, data[key] = key, value
	end
	state.modifiers = PRIVATE
end
function declarator_mt.__call() end
do
	local function index(access, default)
		return function(self, key)
			local state = _state[self]; local modifiers = state.metadata[key] or 0
			if mask(access+ACCESSOR, modifiers) == access+ACCESSOR then return state.accessors[key]() end
			return state.data[key] or default[key]
		end
	end
	env_mt = {__metatable=false, __index=index(PRIVATE, _g)}
	function env_mt.__newindex(self, key, value)
		local state = _state[self]; local modifiers = state.metadata[key]
		if modifiers then
			local mutator = state.mutators[key]
			if mutator then return mutator(value) end
			if mask(MUTABLE, modifiers) == 0 then immutable_error(key) end
		else
			state.metadata[key] = state.modifiers
		end
		state.data[key] = value
	end
	interface_mt = {__metatable=false, __index=index(PUBLIC, {})}
	function interface_mt.__newindex(self, key, value)
		local state = _state[self]; local metadata = state.metadata
		if metadata and mask(PUBLIC+MUTATOR, metadata) == PUBLIC+MUTATOR then
			return state.mutators[key](value)
		elseif mask(PUBLIC+PROPERTY, metadata) == PUBLIC then
			return state.data[key](value)
		end
	end
end
function module(name)
	if not _modules[name] then
		local state, accessors, mutators, env, interface, declarator, importer
		env, interface, declarator, importer = setmetatable({}, env_mt), setmetatable({}, interface_mt), setmetatable({}, declarator_mt), setmetatable({}, importer_mt)
		accessors = {
			private=function() state.modifiers = PRIVATE return declarator end, public=function() state.modifiers = PUBLIC return declarator end,
			mutable=function() state.modifiers = MUTABLE return declarator end,
			accessor=function() state.modifiers = PROPERTY+ACCESSOR return declarator end, mutator=function() state.modifiers = PROPERTY+MUTATOR return declarator end}
		mutators = {accessor=function(f) set_property(state.metadata, accessors, ACCESSOR, state.property, f) end, mutator=function(f) set_property(state.metadata, mutators, MUTATOR, state.property, f) end}
		state = {
			env=env, interface=interface, modifiers=PRIVATE,
			metadata = {_=MUTABLE, _g=PRIVATE, _m=PRIVATE, _i=PRIVATE, import=PRIVATE, private=PROPERTY+ACCESSOR, public=PROPERTY+ACCESSOR, mutable=PROPERTY+ACCESSOR, accessor=PROPERTY+ACCESSOR+MUTATOR, mutator=PROPERTY+ACCESSOR+MUTATOR},
			data = {_g=_g, _m=env, _i=interface, import=importer}, accessors=accessors, mutators=mutators,
		}
		_modules[name], _state[env], _state[interface], _state[declarator], _state[importer] = state, state, state, state, state
		importer [''] 'core'
	end
	setfenv(2, _modules[name].env)
end