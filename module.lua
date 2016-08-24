local type, setmetatable, setfenv, unpack, band, _g = type, setmetatable, setfenv, unpack, bit.band, getfenv(0)
local PRIVATE, PUBLIC, MUTABLE, PROPERTY, ACCESSOR, MUTATOR = 0, 1, 2, 4, 8, 16
local error, import_error, declaration_error, property_error, immutable_error, collision_error, set_property, env_mt, interface_mt, declarator_mt, importer_mt
local _state, _modules = {}, {}
function error(message, ...) return _g.error(format(message or '', unpack(arg))..'\n'..debugstack(), 0) end
import_error, declaration_error, property_error = function() error 'Invalid modifiers.' end, function() error 'Invalid declaration.' end, function() error 'Accessor/Mutator must be function.' end
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
				if not state.metadata[key] and band(PUBLIC, modifiers) ~= 0 then
					state.metadata[key], state.data[key], state.getters[key], state.setters[key] = modifiers, module.data[key], module.getters[key], module.setters[key]
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
	local MODIFIER = {private=PRIVATE, public=PUBLIC, mutable=MUTABLE}
	local MASK = {private=MUTABLE+ACCESSOR+MUTATOR, public=ACCESSOR+MUTATOR, mutable=PRIVATE}
	function declarator_mt.__index(self, key)
		local state, modifier, mask = _state[self], MODIFIER[key], MASK[key]; local modifiers = state.modifiers
		if state.property then declaration_error() end
		if not modifier then modifier, mask, state.property = PROPERTY, PRIVATE+PUBLIC, key end
		if band(mask, modifiers) ~= modifiers then declaration_error() end
		state.modifiers = modifiers + modifier
		return self
	end
end
do
	local function declare(self, key, value)
		local state = _state[self]; local metadata = state.metadata
		if metadata[key] then collision_error(key) end
		metadata[key], state[self] = state[self], PRIVATE
		if band(PROPERTY, metadata[key]) == 0 then
			state.data[key] = value
		else
			local success, getter, setter = pcall(function() return value.get, value.set end)
			if success or error 'Invalid property definition.' then
				if getter ~= nil and (type(getter) == 'function' or error 'Getter must be a function.') then
					state.getters[key] = getter
				end
				if setter ~= nil and (type(setter) == 'function' or error 'Setter must be a function.') then
					state.setters[key] = setter
				end
			end
		end
	end
	declarator_mt.__newindex = declare
	function declarator_mt.__call(self, value)
		local state = _state[self]; local property = state.property
		if property then declare(self, property, value) end
	end
end
do
	local function index(access, default)
		return function(self, key)
			local state = _state[self]; local modifiers = state.metadata[key] or 0
			if band(access+ACCESSOR, modifiers) == access+ACCESSOR then return state.getters[key]() end
			return state.data[key] or default[key]
		end
	end
	env_mt = {__metatable=false, __index=index(PRIVATE, _g)}
	function env_mt.__newindex(self, key, value)
		local state = _state[self]; local modifiers = state.metadata[key]
		if modifiers then
			local mutator = state.setters[key]
			if mutator then return mutator(value) end
			if band(MUTABLE, modifiers) == 0 then immutable_error(key) end
		else
			state.metadata[key] = state.modifiers
		end
		state.data[key] = value
	end
	interface_mt = {__metatable=false, __index=index(PUBLIC, {})}
	function interface_mt.__newindex(self, key, value)
		local state = _state[self]; local metadata = state.metadata
		if metadata and band(PUBLIC+MUTATOR, metadata) == PUBLIC+MUTATOR then
			return state.setters[key](value)
		elseif band(PUBLIC+PROPERTY, metadata) == PUBLIC then
			return state.data[key](value)
		end
	end
end
function module(name)
	if not _modules[name] then
		local state, getters, setters, env, interface, declarator, importer
		env, interface, declarator, importer = setmetatable({}, env_mt), setmetatable({}, interface_mt), setmetatable({}, declarator_mt), setmetatable({}, importer_mt)
		getters = {
			private=function() state.modifiers = PRIVATE return declarator end, public=function() state.modifiers = PUBLIC return declarator end,
			mutable=function() state.modifiers = MUTABLE return declarator end,
			accessor=function() state.modifiers = PROPERTY+ACCESSOR return declarator end, mutator=function() state.modifiers = PROPERTY+MUTATOR return declarator end}
		setters = {accessor=function(f) set_property(state.metadata, getters, ACCESSOR, state.property, f) end, mutator=function(f) set_property(state.metadata, setters, MUTATOR, state.property, f) end}
		state = {
			env=env, interface=interface, modifiers=PRIVATE,
			metadata = {_=MUTABLE, _g=PRIVATE, _m=PRIVATE, _i=PRIVATE, error=PRIVATE, import=PRIVATE, private=PROPERTY+ACCESSOR, public=PROPERTY+ACCESSOR, mutable=PROPERTY+ACCESSOR, accessor=PROPERTY+ACCESSOR+MUTATOR, mutator=PROPERTY+ACCESSOR+MUTATOR},
			data = {_g=_g, _m=env, _i=interface, error=error, import=importer}, getters=getters, setters=setters,
		}
		_modules[name], _state[env], _state[interface], _state[declarator], _state[importer] = state, state, state, state, state
		importer [''] 'core'
	end
	setfenv(2, _modules[name].env)
end