local type, setmetatable, setfenv, unpack, mask, g = type, setmetatable, setfenv, unpack, bit.band, getfenv(0)
local PRIVATE, PUBLIC, MUTABLE, PROPERTY = 0, 1, 2, 4
local MODIFIER = {private=PRIVATE, public=PUBLIC, mutable=MUTABLE, property=PROPERTY}
local MODIFIER_MASK, PROPERTY_MASK = {private=MUTABLE+PROPERTY, public=MUTABLE+PROPERTY, mutable=PRIVATE+PUBLIC}, PRIVATE+PUBLIC
local import, error, define_property, modules_mt, module_mt, env_mt, interface_mt, declarator_mt
local _state, _lock_metatables = {}, {}
function error(message, ...) g.error(format(message, unpack(arg))..'\n'..debugstack(3, 5, 0), 3) end
function import(imports, t) for k, v in t do imports[type(k) == 'number' and v or k] = v end end
--function lock_metatable()
--	local mt = {__metatable=false}
--	tinsert(mt, _lock_metatables)
--	return mt
--end
declarator_mt = {__metatable=false}
function declarator_mt.__call(self, t)
	local state = _state[self]
	local key = state.property
	if not key then return end
	for k, v in t do
		if k == 'get' then
			state.getters[key] = type(v) == 'function' and v or error('Getter must be function.')
		elseif k == 'set' or error('Malformed property definition.') then
			state.setters[key] = type(v) == 'function' and v or error('Setter must be function.')
		end
	end
end
function declarator_mt.__index(self, key)
	local state, modifier = _state[self], MODIFIER[key]
	if modifier then
		state.modifiers = modifier + mask(MODIFIER_MASK[key], state.modifiers)
		return self
	else
		state.modifiers = PROPERTY + mask(PROPERTY_MASK, state.modifiers)
		state.property = key
		return self
	end
end
function declarator_mt.__newindex(self, key, value)
	local state, modifiers
	local state = _state[self]
	modifiers, state.modifiers = state.modifiers, PRIVATE
	if modifiers then error('Field "%s" already exists.', key) end
	state.metadata[key] = modifiers
	if mask(GETTER+SETTER, modifiers) == 0 then
		state.data[self][key] = value
	elseif type(value) == 'function' or error('Getters/setters must be functions.') then
		state.getters[key], state.setters[key] = value, value
	end
end
do
	local function index(access, default)
		return function(self, key)
			local state = _state[self]
			local modifiers = state.modifiers
			if mask(access+GETTER+SETTER, modifiers) == access then
				return state.data[key]
			elseif mask(access+GETTER, modifiers) == access+GETTER then
				return state.getters[key]()
			else
				return default[key] or error('No field "%s".', key)
			end
		end
	end
	env_mt = {__metatable=false, __index=index(PRIVATE, g)}
	function env_mt.__newindex(self, key, value)
		local state = _state[self]
		if not state.metadata[key] then
			state.metadata[key] = PRIVATE
		elseif mask(SETTER, state.metadata[key]) ~= 0 then
			return state.setters[key](value)
		elseif mask(MUTABLE, state.metadata[key]) == 0 then
			error('Field "%s" is immutable.', key)
		end
		state.data[key] = value
	end
	interface_mt = {__metatable=false, __index=index(PUBLIC, {})}
	function interface_mt.__newindex(self, key, value)
		local state = _state[self]
		if mask(PUBLIC+SETTER, state.metadata[key]) == PUBLIC+SETTER then
			return state.setters[key][key](value)
		elseif mask(PUBLIC+MUTABLE, state.metadata[key]) == PUBLIC+MUTABLE or error('Field "%s" is immutable.', key) then
			state.data[key] = value
		end
	end
end
function g.aux_module(name)
	if not _state[name] then
		local state, declarator, env, interface, imports
		env, interface, declarator, imports = setmetatable({}, env_mt), setmetatable({}, interface_mt), setmetatable({}, declarator_mt), {}
		state = {
			name = name, env = env, interface = interface, declarator = declarator, imports = {}, declarator_state = PRIVATE,
			metadata={_g=PRIVATE, _m=PRIVATE, _i=PRIVATE, import=PRIVATE, private=GETTER, public=GETTER, getter=GETTER, setter=GETTER, mutable=GETTER},
			data = {_g=g, _m=env, _i=interface, import=function(t) import(imports, t) end},
			getters = {
				private=function() state.modifiers = PRIVATE return declarator end, public=function() state.modifiers = PUBLIC return declarator end,
				getter=function() state.modifiers = GETTER return declarator end, setter=function() state.modifiers = SETTER return declarator end,
				mutable=function() state.modifiers = MUTABLE return declarator end,
			},
			setters = {},
		}
		_state[name], _state[env], _state[interface], _state[declarator] = state, state, state, state
	end
	local state = (_state[name])
	setfenv(2, state.env)
	return state
end
local frame = CreateFrame 'Frame'
frame:RegisterEvent 'PLAYER_LOGIN'
frame:SetScript('OnEvent', function()
	lock_mt.__newindex = function() error 'Cannot change modules after the loading phase.' end
	local count = 0
	local t0 = GetTime()
	for name, module in _state do
		local data, metadata, getters, setters = module.data, module.metadata, module.getters, module.setters
		for alias, name in _imports[name] do
			local import = _state[name]
			if not import then error('Import failed. No module "%s".', name) end
			local import_data, import_getters, import_setters = import.data
			if alias == '' then
				for key, modifiers in import.metadata do
					if mask(PUBLIC, modifiers) ~= 0 then
						if mask(GETTER+SETTER, modifiers) ~= 0 then

						count = count + 1
						_declarator_state[declarator] = modifiers
						declarator[key] = data[key]
					end
				end
			else
				declarator[alias] = module.interface
			end
		end
	end
	log('imported: '..count..' in '..(GetTime()-t0))
end)