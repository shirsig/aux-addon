local type, setmetatable, setfenv, unpack, mask, _g = type, setmetatable, setfenv, unpack, bit.band, getfenv(0)
local PRIVATE, PUBLIC, MUTABLE, PROPERTY, GETTER, SETTER = 0, 1, 2, 4, 8, 16
local MODIFIER = {private=PRIVATE, public=PUBLIC, mutable=MUTABLE, getter=GETTER+PROPERTY, setter=SETTER+PROPERTY}
local MODIFIER_MASK, PROPERTY_MASK = {private=MUTABLE+GETTER+SETTER, public=MUTABLE+GETTER+SETTER, mutable=PRIVATE+PUBLIC, getter=PRIVATE+PUBLIC, setter=PRIVATE+PUBLIC}, PRIVATE+PUBLIC
local error, declaration_error, immutable_error, collision_error, void_error, set_property, lock_mt, env_mt, interface_mt, declarator_mt, importer_mt
lock_mt = {}
local _state, _modules = {}, setmetatable({}, lock_mt)
function error(message, level, ...) _g.error(format(message, unpack(arg))..'\n'..debugstack(3, 5, 0), (level or 1) + 1) end
function declaration_error(level) error('Malformed declaration.', level + 1) end
function immutable_error(key, level) error('Field "%s" is immutable.', level + 1, key) end
function collision_error(key, level) error('Field "%s" already exists.', level + 1, key) end
function void_error(key, level) error('No field "%s".', level + 1, key) end
importer_mt = {__metatable=false}
function importer_mt.__index(self, key) _state[self][self] = key; return self end
function importer_mt.__call(self, arg1, arg2)
	local name, state, module, alias
	name = arg2 or arg1
	state, module = _state[self], _modules[name]
	alias, state[self] = state[self] or name, nil
	if module then
		if alias == '_' then
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
function set_property(data, property, value)
	if property and not data[property] and type(value) == 'function' or declaration_error(2) then
		data[property] = value
	end
end
declarator_mt = {__metatable=false}
function declarator_mt.__index(self, key)
	local state, modifier = _state[self], MODIFIER[key]; local modifiers = state.modifiers
	if modifier then
		if mask(MODIFIER_MASK[key], modifiers) ~= modifiers then declaration_error(2) end
		state.modifiers = modifiers + modifier; return self
	elseif not state.metadata[key] or collision_error(key, 2) then
		if mask(PROPERTY_MASK, modifiers) ~= modifiers then declaration_error(2) end
		state.property, state.metadata[key], state.modifiers = key, modifiers + PROPERTY, PRIVATE
	end
end
function declarator_mt.__newindex(self, key, value)
	local state = _state[self]
	if state.metadata[key] then collision_error(key, 2) end
	state.metadata[key] = state.modifiers
	if mask(PROPERTY, state.modifiers) == 0 then
		state.data[key] = value
	elseif type(value) == 'function' or declaration_error(2) then
		local data = mask(GETTER, state.modifiers) ~= 0 and state.getters or state.setters
		state.property, data[key] = key, value
	end
	state.modifiers = PRIVATE
end
function declarator_mt.__call() end
do
	local function index(access, default)
		return function(self, key)
			local state = _state[self]; local modifiers = state.metadata[key]
			if modifiers and mask(access+PROPERTY, modifiers) == access then
				return state.data[key]
			else
				local getter = state.getters[key]
				if getter then return getter() else return default[key] or void_error(key, 2) end
			end
		end
	end
	env_mt = {__metatable=false, __index=index(PRIVATE, _g)}
	function env_mt.__newindex(self, key, value)
		local state = _state[self]; local modifiers = state.metadata[key]
		if modifiers then
			local setter = state.setters[key]
			if setter then return setter(value) end
			if mask(MUTABLE, modifiers) == 0 then immutable_error(key, 2) end
		else
			state.metadata[key] = state.modifiers
		end
		state.data[key] = value
	end
	interface_mt = {__metatable=false, __index=index(PUBLIC, {})}
	function interface_mt.__newindex(self, key, value)
		local state = _state[self]; local metadata = state.metadata or void_error(key, 2)
		if mask(PUBLIC+SETTER, metadata) == PUBLIC+SETTER then
			return state.setters[key](value)
		elseif mask(PUBLIC, metadata) == PUBLIC or immutable_error(key, 2) then
			state.data[key] = value
		end
	end
end
function INIT() end
function module(name)
	if not _modules[name] then
		local state, getters, setters, env, interface, declarator, importer
		env, interface, declarator, importer = setmetatable({}, env_mt), setmetatable({}, interface_mt), setmetatable({}, declarator_mt), setmetatable({}, importer_mt)
		getters = {
			private=function() state.modifiers = PRIVATE return declarator end, public=function() state.modifiers = PUBLIC return declarator end,
			mutable=function() state.modifiers = MUTABLE return declarator end,
			getter=function() state.modifiers = PROPERTY+GETTER return declarator end, setter=function() state.modifiers = PROPERTY+SETTER return declarator end}
		setters = {getter=function(value) set_property(getters, state.property, value) end, setter=function(value) set_property(setters, state.property, value) end}
		state = {
			env=env, interface=interface, modifiers=PRIVATE,
			metadata = setmetatable({_g=PRIVATE, _m=PRIVATE, _i=PRIVATE, import=PRIVATE, private=PROPERTY+GETTER, public=PROPERTY+GETTER, mutable=PROPERTY+GETTER, getter=PROPERTY+GETTER+SETTER, setter=PROPERTY+GETTER+SETTER}, lock_mt),
			data = {_g=_g, _m=env, _i=interface, import=importer}, getters=getters, setters=setters,
		}
		_modules[name], _state[env], _state[interface], _state[declarator], _state[importer] = state, state, state, state, state
		setfenv(INIT, env); INIT()
	end
	setfenv(2, _modules[name].env)
end
local frame = CreateFrame 'Frame'; frame:RegisterEvent 'PLAYER_LOGIN'
frame:SetScript('OnEvent', function() lock_mt.__newindex = function() error 'Modules are frozen after the loading phase.' end end)