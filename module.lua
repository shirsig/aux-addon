local type, setmetatable, setfenv, unpack, next, mask, pcall, _g = type, setmetatable, setfenv, unpack, next, bit.band, pcall, getfenv(0)
local PRIVATE, PUBLIC, MUTABLE, DYNAMIC, PROPERTY = 0, 1, 2, 4, 8
local error, import_error, declaration_error, collision_error, assignment_error, set_property, env_mt, interface_mt, declarator_mt, importer_mt
function error(message, ...) return _g.error(format(message or '', unpack(arg))..'\n'..debugstack(), 0) end
import_error, declaration_error = function() error 'Invalid import statement.' end, function() error 'Invalid declaration.' end
collision_error, assignment_error = function(key) error('Field "%s" already exists.', key) end, function(key) error('Field "%s" is immutable.', key) end
local _state, _modules = {}, {}
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
					state.metadata[key], state.data[key], state.getters[key], state.setters[key] = modifiers, module.data[key], module.getters[key], module.setters[key]
				end
			end
		elseif not state.metadata[alias] then
			state.metadata[alias], state.data[alias] = PRIVATE, module.interface
		end
	end
	return self
end
declarator_mt = {__metatable=false}
do
	local MODIFIER = {private=PRIVATE, public=PUBLIC, mutable=MUTABLE}
	local COMPATIBLE = {private=MUTABLE+PROPERTY, public=PROPERTY, mutable=PRIVATE}
	function declarator_mt.__index(self, key)
		local state, modifiers, modifier, compatible; state = _state[self]
		if state.property then declaration_error() end
		modifiers, modifier, compatible = state.modifiers, MODIFIER[key], COMPATIBLE[key]
		if not modifier then modifier, compatible, state.property = PROPERTY, PRIVATE+PUBLIC, key end
		if mask(compatible, modifiers) ~= modifiers then declaration_error() end
		state.modifiers = modifiers + modifier
		return self
	end
end
do
	local function declare(self, key, value, getter, setter)
		local property, metadata = self.metadata, self.property
		if property and (type(value) == 'function' or declaration_error()) then
			if key == 'get' then getter = value elseif key == 'set' or declaration_error() then setter = value end
			key, value = property, nil
		end
		local old_modifiers, new_modifiers = metadata[key], self.modifiers
		if old_modifiers then collision_error(key) end
		metadata[key], self.modifiers = new_modifiers, PRIVATE
		self.data[key], self.getters[key], self.setters[key] = value, getter, setter
	end
	declarator_mt.__newindex = declare --TODO
	local function unpack_property_value(t)
		local get, set; get, set, t.get, t.set = t.get, t.set, nil, nil
		if next(t) or get and type(get ~= 'function') or set and type(set) ~= 'function' then error() end
		return get, set
	end
	function declarator_mt.__call(self, value)
		local state, property; state = _state[self]; property = state.property
		if property then
			local success, getter, setter = pcall(unpack_property_value, value)
			if success or declaration_error() then declare(state, property, nil, getter, setter)
		end
	end
end
do
	local function index(public, default)
		local access, default
		if public then access, default = PUBLIC, {} else access, default = 0, _g end
		return function(self, key)
			local state, getter, modifiers; state = _state[self];
			getter, modifiers = state.getters[key], state.metadata[key] or 0
			if mask((public*PUBLIC)+PROPERTY, modifiers) == access+PROPERTY then return getter and getter[key]() end
			return state.data[key] or default[key]
		end
	end
	env_mt = {__metatable=false, __index=index(PRIVATE, _g)}
	function env_mt.__newindex(self, key, value)
		local state = _state[self]; local modifiers = state.metadata[key]
		if modifiers then
			local mutator = state.setters[key]
			if mutator then return mutator(value) end
			if mask(MUTABLE, modifiers) == 0 then assignment_error(key) end
		else
			state.metadata[key] = state.modifiers
		end
		state.data[key] = value
	end
	interface_mt = {__metatable=false, __index=index(PUBLIC, {})}
	function interface_mt.__newindex(self, key, value)
		local state = _state[self]; local metadata = state.metadata
		if metadata and mask(PUBLIC+MUTATOR, metadata) == PUBLIC+MUTATOR then
			return state.setters[key](value)
		elseif mask(PUBLIC+PROPERTY, metadata) == PUBLIC then
			return state.data[key](value)
		end
	end
end
function module(name)
	if not _modules[name] then
		local state, getters, setters, env, interface, declarator, importer
		env, interface, declarator, importer = setmetatable({}, env_mt), setmetatable({}, interface_mt), setmetatable({}, declarator_mt), setmetatable({}, importer_mt)
		getters = {
			private=function() state.modifiers=PRIVATE; state.property=nil return declarator end, public=function() state.modifiers=PUBLIC; state.property=nil return declarator end,
			mutable=function() state.modifiers=MUTABLE; state.property=nil return declarator end,
		}
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