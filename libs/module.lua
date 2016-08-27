if module then return end
local typeof, tostring, setmetatable, setfenv, unpack, next, pcall, _G = type, tostring, setmetatable, setfenv, unpack, next, pcall, getfenv(0)

local PUBLIC, PRIVATE = 1, 2
local GETTER, SETTER, FUNCTION = 1, 2, 3

local function error(msg, ...) return _G.error(format(msg or '', unpack(arg))..'\n'..debugstack(), 0) end
local function import_error() error 'Invalid imports.' end
local function declaration_error() error 'Invalid declaration.' end
local function collision_error(key) error('"%s" already exists.', key) end

local function nop() end
local function const(v) return function() return v end end

local _state = {}

local declarator_mt, env_mt = {__metatable=false}, {__metatable=false}
do
	local ACCESS, TYPE = {public=PUBLIC, private=PRIVATE}, {call=FUNCTION, get=GETTER, set=SETTER}
	local access, name
	local function extract(v)
		local call, get, set
		call, get, set, v.call, v.get, v.set = v.call, v.get, v.set, nil, nil, nil
		if next(v) or call ~= nil and get ~= nil then error() end
		return call, get, set
	end
	local function declare(state, access, name, data)
		state.access[name] = state.access[name] and collision_error(name) or access or state.default_access
		for type, value in data do
			if typeof(value) ~= 'function' and (type == GETTER or declaration_error()) then
				value = const(value == nil and tostring(value) or value)
			end
			state[type][name] = value
		end
	end

	function declarator_mt:__index(key) local state=_state[self]
		if ACCESS[key] and not access then
			access = ACCESS[key]
		elseif not name or declaration_error() then
			name = key
		end
	end
	function declarator_mt:__newindex(key, value) local state=_state[self]
--			if module.access[key] then return end
		local type
		if name then
			type = TYPE[key] or declaration_error()
		else
			type = typeof(value) == 'function' and FUNCTION or GETTER
		end
		declare(state, access, key, {[type]=value})
		access, name = nil, nil
	end
	function declarator_mt:__call(value) local state=_state[self]
		if name then
			local success, call, get, set = pcall(extract, value)
			if not success then declaration_error() end
			declare(state, access, name, {[FUNCTION]=call, [GETTER]=get, [SETTER]=set})
		elseif access or declaration_error() then
			state.default_access = access
		end
		access, name = nil, nil
	end
end

function env_mt:__index(key) local state=_state[self]
	local get = state[GETTER][key]
	if get then return get() end
	local f = state[FUNCTION][key]
	if f then return f else return _G[key] end
end
function env_mt:__newindex(key, value) local state=_state[self]
	if declaration_newindex(state, key, value) then return end
	local f = state[SETTER][key]
	if f then f(value); return end
end

local interface_mt = {__metatable=false}
function interface_mt:__index(key) local state=_state[self]
	if state.access[key] == PUBLIC then
		local get = state[GETTER][key]
		if get then return get() else return state[FUNCTION][key] end
	end
end
function interface_mt:__newindex(key, value) local state=_state[self]
	if state.access[key] == PUBLIC then (state[SETTER][key] or state[FUNCTION][key])(value) end
end

function module(...)
	local declarator, env, interface = setmetatable({}, declarator_mt), setmetatable({}, env_mt), setmetatable({}, interface_mt)
	local access = {error=PRIVATE, nop=PRIVATE, _G=PRIVATE, M=PRIVATE, I=PRIVATE, public=PRIVATE, private=PRIVATE}
	local functions, getters, setters = {error=error, nop=nop}, {_G=const(_G), M=const(env), I=const(interface)}, {}
	for i=1,arg.n do
		local module = _state[arg[i] or import_error()] or import_error()
		local import_functions, import_getters, import_setters = module[FUNCTION], module[GETTER], module[SETTER]
		for k, v in module.access do
			if v == PUBLIC and (not access[k] or import_error()) then
				functions[k], getters[k], setters[k] = import_functions[k], import_getters[k], import_setters[k]
				access[k] = PRIVATE
			end
		end
	end
	local state = {access=access, [FUNCTION]=functions, [GETTER]=getters, [SETTER]=setters, default_access=PRIVATE}
	_state[declarator], _state[env], _state[interface] = state, state, state
	setfenv(2, env)
end