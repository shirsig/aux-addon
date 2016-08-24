local type, setmetatable, setfenv, unpack, next, mask, pcall, _g = type, setmetatable, setfenv, unpack, next, bit.band, pcall, getfenv(0)
local PRIVATE, PUBLIC, MUTABLE, DYNAMIC, PROPERTY = 0, 1, 2, 4, 8
local error, import_error, declaration_error, collision_error, mutability_error, set_property, env_mt, interface_mt, declarator_mt, importer_mt
local empty, pass = {}, function() end
local _state, _modules = {}, {}
function error(message, ...) return _g.error(format(message or '', unpack(arg))..'\n'..debugstack(), 0) end
import_error, declaration_error = function() error 'Invalid import statement.' end, function() error 'Invalid declaration.' end
collision_error, mutability_error = function(key) error('Field "%s" already exists.', key) end, function(key) error('Field "%s" is immutable.', key) end
importer_mt = {__metatable=false}
function importer_mt.__index(self, key)
	if type(key) ~= 'string' then import_error() end
	_state[self][self] = key; return self
end
function importer_mt.__call(self, arg1, arg2, state) state=_state[self]
	local name, module, alias
	name = arg2 or arg1
	if type(name) ~= 'string' then import_error() end
	module = _modules[name]
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
	function declarator_mt.__index(self, key, state) state=_state[self]
		if state.property then declaration_error() end
		local modifiers, modifier, compatible = state[self], MODIFIER[key], COMPATIBLE[key]
		if not modifier then modifier, compatible, state.property = PROPERTY, PRIVATE+PUBLIC, key end
		if mask(compatible, modifiers) ~= modifiers then declaration_error() end
		state[self] = modifiers + modifier
		return self
	end
end
do
	local function unpack_property_value(t)
		local get, set; get, set, t.get, t.set = t.get or pass, t.set or pass, nil, nil
		if next(t) or type(get ~= 'function') or type(set) ~= 'function' then error() end
		return get, set
	end
	local function declare(self, modifiers, key, value)
		local metadata = self.metadata
		if metadata[key] then collision_error(key) end
		metadata[key] = modifiers
		if mask(PROPERTY, modifiers) ~= 0 then
			local success, getter, setter = pcall(unpack_property_value, value)
			if success or declaration_error() then self.getters[key], self.setters[key] = getter, setter end
		else
			self.data[key] = value
		end
	end
	declarator_mt.__newindex = function(self, key, value, state) state=_state[self]
		local property, modifiers; property, modifiers, state[self] = state.property, state[self], PRIVATE
		if property then state.property = nil; declare(state, modifiers, property, {[key]=value}) end
	end
	function declarator_mt.__call(self, value, state) state=_state[self]
		local property, modifiers; property, modifiers, state[self] = state.property, state[self], PRIVATE
		if property then state.property = nil; declare(state, modifiers, property, value) else state.modifiers = modifiers end
	end
end
do
	local function index(public)
		local access = public and PUBLIC or 0
		return function(self, key)
			local state, getter, modifiers; state = _state[self]
			getter, modifiers = state.getters[key], state.metadata[key] or 0
			local masked = mask(access+PROPERTY, modifiers)
			if masked == access+PROPERTY then
				return getter and getter[key]()
			elseif masked == access then
				return state.data[key]
			elseif not public then
				return _g[key]
			end
		end
	end
	env_mt = {__metatable=false, __index=index()}
	function env_mt.__newindex(self, key, value)
		local state, modifiers; state = _state[self]; modifiers = state.metadata[key]
		if modifiers then
			local setter = state.setters[key]
			if setter then setter(value) elseif mask(MUTABLE, modifiers) ~= 0 or mutability_error(key) then state.data[key] = value end
		else
			declare(state, key, value)
		end
	end
	interface_mt = {__metatable=false, __index=index(true)}
	function interface_mt.__newindex(self, key, value)
		local state, metadata; state = _state[self]; metadata = state.metadata
		if metadata and mask(PUBLIC+PROPERTY, metadata) == PUBLIC+PROPERTY then
			return state.setters[key](value)
		elseif mask(PUBLIC+PROPERTY, metadata) == PUBLIC then
			return state.data[key](value)
		end
	end
end
function module(name)
	if not _modules[name] then
		local state, getters, env, interface, declarator, importer
		env, interface, declarator, importer = setmetatable({}, env_mt), setmetatable({}, interface_mt), setmetatable({}, declarator_mt), setmetatable({}, importer_mt)
		getters = {
			private=function() state.modifiers=PRIVATE; state.property=nil return declarator end, public=function() state.modifiers=PUBLIC; state.property=nil return declarator end,
			mutable=function() state.modifiers=MUTABLE; state.property=nil return declarator end,
		}
		state = {
			env=env, interface=interface, modifiers=PRIVATE,
			metadata = {_=MUTABLE, _g=PRIVATE, _m=PRIVATE, _i=PRIVATE, error=PRIVATE, import=PRIVATE, private=PROPERTY, public=PROPERTY, mutable=PROPERTY, accessor=PROPERTY, mutator=PROPERTY},
			data = {_g=_g, _m=env, _i=interface, error=error, import=importer}, getters=getters, setters={},
		}
		_modules[name], _state[env], _state[interface], _state[declarator], _state[importer] = state, state, state, state, state
		importer [''] 'core'
	end
	setfenv(2, _modules[name].env)
end