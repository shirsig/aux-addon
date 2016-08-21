local type, setmetatable, setfenv, unpack, mask, _g = type, setmetatable, setfenv, unpack, bit.band, getfenv(0)
local PRIVATE, PUBLIC, MUTABLE, PROPERTY = 0, 1, 2, 4
local MODIFIER = {private=PRIVATE, public=PUBLIC, mutable=MUTABLE, property=PROPERTY}
local MODIFIER_MASK, PROPERTY_MASK = {private=MUTABLE+PROPERTY, public=MUTABLE+PROPERTY, mutable=PRIVATE+PUBLIC}, PRIVATE+PUBLIC
local error, import, define_property, lock_mt, env_mt, interface_mt, declarator_mt
lock_mt = {}
local _state, _modules = {}, setmetatable({}, lock_mt)
function error(message, level, ...) _g.error(format(message, unpack(arg))..'\n'..debugstack(3, 5, 0), (level or 1) + 1) end
function import(imports, t) for k, v in t do imports[type(k) == 'number' and v or k] = v end end
declarator_mt = {__metatable=false}
function define_property(self, key, t)
	local state = _state[self]
	for k, v in t do
		if k == 'get' then
			state.getters[key] = type(v) == 'function' and v or error('Getter must be function.', 3)
		elseif k == 'set' or error 'Malformed declaration.' then
			state.setters[key] = type(v) == 'function' and v or error('Setter must be function.', 3)
		end
	end
end
function declarator_mt.__index(self, key)
	local state, modifier = _state[self], MODIFIER[key]
	if modifier then
		state.modifiers = modifier + mask(MODIFIER_MASK[key], state.modifiers)
		return self
	elseif state.metadata[key] then
		error('Field "%s" already exists.', 2, key)
	else
		state.modifiers = PROPERTY + mask(PROPERTY_MASK, state.modifiers)
		return function(t) define_property(self, key, t) end
	end
end
function declarator_mt.__newindex(self, key, value)
	local state = _state[self]
	if state.metadata[key] then error('Field "%s" already exists.', 2, key) end
	state.metadata[key], state.data[key], state.modifiers = state.modifiers, value, PRIVATE
end
do
	local function index(access, default)
		return function(self, key)
			local state = _state[self]; local modifiers = state.metadata[key]
			if modifiers and mask(access+PROPERTY, modifiers) == access then
				return state.data[key]
			else
				local getter = state.getters[key]
				if getter then return getter() else return default[key] or error('No field "%s".', 2, key) end
			end
		end
	end
	env_mt = {__metatable=false, __index=index(PRIVATE, _g)}
	function env_mt.__newindex(self, key, value)
		local state = _state[self]; local modifiers = state.metadata[key]
		if modifiers then
			local setter = state.setters[key]
			if setter then return setter(value) end
			if mask(MUTABLE, modifiers) == 0 then error('Field "%s" is immutable.', 2, key) end
		else
			state.metadata[key] = PRIVATE
		end
		state.data[key] = value
	end
	interface_mt = {__metatable=false, __index=index(PUBLIC, {})}
	function interface_mt.__newindex(self, key, value)
		local state = _state[self]; local setter, metadata = state.setters[key], state.metadata or error('No field "%s".', 2, key)
		if mask(PUBLIC+PROPERTY, metadata) == PUBLIC+PROPERTY and setter then
			return setter(value)
		elseif mask(PUBLIC, metadata) == PUBLIC or error('Field "%s" is immutable.', 2, key) then
			state.data[key] = value
		end
	end
end
function _g.aux_module(name)
	if not _modules[name] then
		local state, declarator, env, interface, imports
		env, interface, declarator, imports = setmetatable({}, env_mt), setmetatable({}, interface_mt), setmetatable({}, declarator_mt), {}
		state = {
			name = name, env = env, interface = interface, declarator = declarator, imports = {}, declarator_state = PRIVATE,
			metadata = setmetatable({_g=PRIVATE, _m=PRIVATE, _i=PRIVATE, import=PRIVATE, private=PROPERTY, public=PROPERTY, getter=PROPERTY, setter=PROPERTY, mutable=PROPERTY}, lock_mt),
			data = {_g=_g, _m=env, _i=interface, import=function(t) import(imports, t) end},
			getters = {private=function() state.modifiers = PRIVATE return declarator end, public=function() state.modifiers = PUBLIC return declarator end, mutable=function() state.modifiers = MUTABLE return declarator end},
			setters = {},
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
					if metadata[key] then error('Import of "%s" failed. Conflict with field "%s"', 1, name, key) end
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