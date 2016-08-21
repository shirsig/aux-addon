local type, setmetatable, setfenv, unpack, mask, _g = type, setmetatable, setfenv, unpack, bit.band, getfenv(0)
local PRIVATE, PUBLIC, MUTABLE, PROPERTY, GETTER, SETTER = 0, 1, 2, 4, 8, 16
local MODIFIER = {private=PRIVATE, public=PUBLIC, mutable=MUTABLE, getter=GETTER+PROPERTY, setter=SETTER+PROPERTY}
local MODIFIER_MASK, PROPERTY_MASK = {private=MUTABLE+GETTER+SETTER, public=MUTABLE+GETTER+SETTER, mutable=PRIVATE+PUBLIC, getter=PRIVATE+PUBLIC, setter=PRIVATE+PUBLIC}, PRIVATE+PUBLIC
local error, declaration_error, immutable_error, collision_error, void_error, import, set_property, lock_mt, env_mt, interface_mt, declarator_mt
lock_mt = {}
local _state, _modules = {}, setmetatable({}, lock_mt)
function error(message, level, ...) _g.error(format(message, unpack(arg))..'\n'..debugstack(3, 5, 0), (level or 1) + 1) end
function declaration_error(level) error('Malformed declaration.', level + 1) end
function immutable_error(key, level) error('Field "%s" is immutable.', level + 1, key) end
function collision_error(key, level) error('Field "%s" already exists.', level + 1, key) end
function void_error(key, level) error('No field "%s".', level + 1, key) end
function import(imports, t) for k, v in t do imports[type(k) == 'number' and v or k] = v end end
function set_property(data, property, value)
	if property and not data[property] and type(value) == 'function' or declaration_error(2) then
		data[property] = value
	end
end
declarator_mt = {__metatable=false}
function declarator_mt.__call() end
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
		local state = _state[self]; local setter, metadata = state.setters[key], state.metadata or void_error(key, 2)
		if mask(PUBLIC+PROPERTY, metadata) == PUBLIC+PROPERTY and setter then
			return setter(value)
		elseif mask(PUBLIC, metadata) == PUBLIC or immutable_error(key, 2) then
			state.data[key] = value
		end
	end
end
function _g.aux_module(name)
	if not _modules[name] then
		local state, getters, setters, imports, env, interface, declarator
		imports, env, interface, declarator = {}, setmetatable({}, env_mt), setmetatable({}, interface_mt), setmetatable({}, declarator_mt)
		getters = {private=function() state.modifiers = PRIVATE return declarator end, public=function() state.modifiers = PUBLIC return declarator end, mutable=function() state.modifiers = MUTABLE return declarator end}
		setters = {getter=function(value) set_property(getters, state.property, value) end, setter=function(value) set_property(setters, state.property, value) end}
		state = {
			name=name, env=env, interface=interface, imports={}, declarator_state=PRIVATE,
			metadata = setmetatable({_g=PRIVATE, _m=PRIVATE, _i=PRIVATE, import=PRIVATE, private=PROPERTY, public=PROPERTY+GETTER, mutable=PROPERTY+GETTER, getter=PROPERTY+GETTER+SETTER, setter=PROPERTY+GETTER+SETTER}, lock_mt),
			data = {_g=_g, _m=env, _i=interface, import=function(t) import(imports, t) end},
			getters=getters, setters=setters,
		}
		_modules[name], _state[env], _state[interface], _state[declarator] = state, state, state, state
	end
	local module = _modules[name]
	setfenv(2, module.env)
	return module
end
local frame = CreateFrame 'Frame'
frame:RegisterEvent 'PLAYER_LOGIN'
frame:SetScript('OnEvent', function()
	lock_mt.__newindex = function() error 'Modules are frozen after the loading phase.' end
	local count = 0
	local t0 = GetTime()
	for _, module in _modules do
		local metadata, data, getters, setters = module.metadata, module.data, module.getters, module.setters
		for alias, name in module.imports do
			local import = _modules[name]
			if not import then error('Import failed. No module "%s".', 1, name) end
			local import_data, import_getters, import_setters = import.data, import.getters, import.setters
			if alias == '' then
				for key, modifiers in import.metadata do
					if metadata[key] then error('Import of "%s" failed. Name collision for "%s"', 1, name, key) end
					count = count + 1
					metadata[key], data[key], getters[key], setters[key] = modifiers, import_data[key], import_getters[key], import_setters[key]
				end
			else
				if metadata[alias] then error('') end
				metadata[alias], data[alias] = PRIVATE, module.interface
			end
		end
	end
	_g.aux.log('imported: '..count..' in '..(GetTime()-t0))
end)