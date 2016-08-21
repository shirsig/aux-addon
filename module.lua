local type, setmetatable, unpack, mask, g = type, setmetatable, unpack, bit.band, getfenv(0)
local PRIVATE, PUBLIC, GETTER, SETTER, MUTABLE = 0, 1, 2, 4, 8
local MODIFIER = {private=PRIVATE, public=PUBLIC, getter=GETTER, setter=SETTER, mutable=MUTABLE}
local MASK = {private=MUTABLE+GETTER+SETTER, public=MUTABLE+GETTER+SETTER, getter=PRIVATE+PUBLIC+SETTER, setter=PRIVATE+PUBLIC+GETTER, mutable=PRIVATE+PUBLIC}
local import, declarator_mt, env_mt, interface_mt, lock_mt
local initialize_declarator, error
local _modules, _metadata, _data, _getters, _setters, _imports, _declarators, _declarator_state = setmetatable({}, lock_mt), {}, {}, {}, {}, {}, {}, {}
function error(message, ...) g.error(format(message, unpack(arg))..'\n'..debugstack(3, 5, 0), 3) end
function import(imports, t) for k, v in t do imports[type(k) == 'number' and v or k] = v end end
declarator_mt = {__metatable=false}
do
	local function define_property(self, key, t)
		local getter, setter = t.get, t.set
		_metadata[self][key] = mask(PRIVATE+PUBLIC, _declarator_state[self])
				+ (getter ~= nil and (type(getter) == 'function' or error('Getter "%s" is not a function.', key)) and GETTER or 0)
				+ (setter ~= nil and (type(setter) == 'function' or error('Setter "%s" is not a function.', key)) and SETTER or 0)
		_getters[self][key], _setters[self][key] = getter, setter
	end
	function declarator_mt.__index(self, key)
		local modifier = MODIFIER[key]
		if not modifier then return function(t) define_property(self, key, t) end end
		_declarator_state[self] = modifier + mask(MASK[key], _declarator_state[self])
		return self
	end
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
do
	local function index(access, default)
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
end
lock_mt = {}
function g.aux_module(name)
	if not _modules[name] then
		local metadata, data, getters, setters, imports, declarator, env, interface
		imports, declarator, env, interface = {}, setmetatable({}, declarator_mt), setmetatable({}, env_mt), setmetatable({}, interface_mt)
		metadata = setmetatable({g=PRIVATE, m=PRIVATE, import=PRIVATE, private=GETTER, public=GETTER, getter=GETTER, setter=GETTER, mutable=GETTER}, lock_mt)
		data = {g=g, m=env, import=function(t) import(imports, t) end}
		getters = {
			private=function() _declarator_state[declarator] = PRIVATE return declarator end, public=function() _declarator_state[declarator] = PUBLIC return declarator end,
			getter=function() _declarator_state[declarator] = GETTER return declarator end, setter=function() _declarator_state[declarator] = SETTER return declarator end,
			mutable=function() _declarator_state[declarator] = MUTABLE return declarator end,
		}
		setters = {}
		_metadata[name], _metadata[declarator], _metadata[env], _metadata[interface] = metadata, metadata, metadata, metadata
		_data[name], _data[declarator], _data[env], _data[interface] = data, data, data, data
		_getters[name], _getters[declarator], _getters[env], _getters[interface] = getters, getters, getters, getters
		_setters[name], _setters[declarator], _setters[env], _setters[interface] = setters, setters, setters, setters
		_modules[name], _imports[name], _declarators[name] = {env, interface}, imports, declarator
	end
	local env, interface = unpack(_modules[name])
	setfenv(2, env)
	return interface
end
local frame = CreateFrame 'Frame'
frame:RegisterEvent 'PLAYER_LOGIN'
frame:SetScript('OnEvent', function()
	lock_mt.__newindex = function() error 'Cannot change modules after the loading phase.' end
	local count = 0
	local t0 = GetTime()
	for name in _modules do
		local declarator = _declarators[name]
		for import, v in _imports[name] do
			if not _modules[import] then error('Invalid import "%s" in module "%s".', import, name) end
			if v == '' then
				local data = _data[import]
				for key, modifiers in _metadata[import] do
					if mask(PUBLIC, modifiers) ~= 0 then
						count = count + 1
						_declarator_state[declarator] = modifiers
						declarator[key] = data[key]
					end
				end
			else
				declarator[v] = import
			end
		end
	end
	log('imported: '..count..' in '..(GetTime()-t0))
end)