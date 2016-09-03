if module then return end
local type, getmetatable, setmetatable, setfenv, unpack, next, _G = type, getmetatable, setmetatable, setfenv, unpack, next, getfenv(0)

local PUBLIC, PRIVATE = 1, 2
local CALL, INDEX, NEWINDEX = 1, 2, 3

do
	local function print(msg) DEFAULT_CHAT_FRAME:AddMessage(RED_FONT_COLOR_CODE..msg) end
	p = setmetatable({}, {
		__call=function(_, ...)
			for i = 1, arg.n do
				if type(arg[i]) == 'table' then
					print('arg'..i..' = {')
					for k, v in arg[i] do print(format('    %s: %s = %s', type(k) == 'string' and k or '['..tostring(k)..']', type(v), tostring(v))) end
					print('}')
				else
					print(format('arg%d: %s = %s', i, type(arg[i]), tostring(arg[i])))
				end
			end
			return unpack(arg)
		end,
		__pow=function(self, v) self(v); return v end,
	})
end

local function error(msg, ...) return _G.error(format(msg or '', unpack(arg))..'\n'..debugstack(), 0) end
local function import_error() error('Import error.') end
local function declaration_error() error('Declaration error.') end
local function collision_error(key) error('"%s" already exists.', key) end
local function nil_error(key) if key then error('"%s" is nil.', key) else error('Callee is nil') end end

local nop, const = function() end, function(v) return function() return v end end

local function prototype() local eq = const(true)
	return setmetatable({__metatable=false, __eq=eq}, {__metatable=false, __eq=eq, __call=function(self, t) return setmetatable(t, self) end})
end

local INTERFACE, ENVIRONMENT, DECLARATOR = prototype(), prototype(), prototype()

local state = {}

function INTERFACE:__index(key) self=state[self]
	if self.access[key] == PUBLIC then
		local getter = self[INDEX][key]
		if getter then return getter() else return self[CALL][key] end
	end
end
function INTERFACE:__newindex(key, value) self=state[self]
	if self.access[key] == PUBLIC then (self[NEWINDEX][key] or nop)(value) end
end

function ENVIRONMENT:__index(key) self=state[self]
	local getter = self[INDEX][key]
	if getter then return getter() end
	return self[CALL][key] or _G[key] or self.declarator[key]
end
function ENVIRONMENT:__newindex(key, value) self=state[self]
	if self.access[key] then
		local setter = self[NEWINDEX][key] or collision_error(key)
		setter(value)
	else
		self.declarator[key] = value
	end
end

do
	local ACCESS, EVENT = {public=PUBLIC, private=PRIVATE}, {call=CALL, get=INDEX, set=NEWINDEX}
	local function declare(self, access, name, handlers)
		self.access[name] = self.access[name] and collision_error(name) or access or self.default_access
		for event, handler in handlers do
			if type(handler) ~= 'function' and (event == INDEX or declaration_error()) then
				handler = const(handler)
			end
			self[event][name] = handler
		end
	end
	function DECLARATOR:__index(key) self=state[self]; local name, access = self.declaration_name, self.declaration_access
		if ACCESS[key] and (not access or declaration_error() and not name or nil_error(name)) then
			self.declaration_access = ACCESS[key]
		elseif not name or nil_error(name) then
			self.declaration_name = (type(key) == 'string' or access and declaration_error() or nil_error(name)) and key
		end
		return self.declarator
	end
	function DECLARATOR:__newindex(key, value) self=state[self]
		local name, event = self.declaration_name, nil
		if name then
			event = EVENT[key] or nil_error(name)
		else
			name, event = key, type(value) == 'function' and CALL or INDEX
		end
		declare(self, self.declaration_access, name, {[event]=value})
		self.declaration_access, self.declaration_name = nil, nil
	end
	function DECLARATOR:__call(v) self=state[self]; local name, access = self.declaration_name, self.declaration_access
		if name then
			if type(v) ~= 'table' or getmetatable(v) ~= nil then (access and declaration_error() or nil_error)(name) end
			local f, getter, setter; f, getter, setter, v.call, v.get, v.set = v.call, v.get, v.set, nil, nil, nil
			if next(v) or f ~= nil and getter ~= nil then (access and declaration_error() or nil_error)(name) end
			declare(self, access, name, {[CALL]=f, [INDEX]=getter, [NEWINDEX]=setter})
		elseif access or nil_error() then
			self.default_access = access
		end
		self.declaration_access, self.declaration_name = nil, nil
	end
end

local function import(self, interface)
	local module = (interface == INTERFACE or import_error()) and state[interface]
	for k, v in module.access do
		if v == PUBLIC and not self.access[k] then
			self.access[k], self[CALL][k], self[INDEX][k], self[NEWINDEX][k] = PRIVATE, module[CALL][k], module[INDEX][k], module[NEWINDEX][k]
		end
	end
end

function module(name)
	if name and _G[name] then return true end
	local interface, env, declarator = INTERFACE {}, ENVIRONMENT {}, DECLARATOR {}
	local self; self = {
		access = {p=PRIVATE, _=PRIVATE, error=PRIVATE, nop=PRIVATE, _G=PRIVATE, M=PRIVATE, I=PRIVATE, public=PRIVATE, private=PRIVATE},
		[CALL] = {p=p, import=function(interface) import(self, interface) end, error=error, nop=nop},
		[INDEX] = {_G=const(_G), M=const(env), I=const(interface), public=function() return declarator.public end, private=function() return declarator.private end},
		[NEWINDEX] = {p=p, _=nop},
		declarator = declarator,
		default_access = PRIVATE,
	}
	state[interface], state[env], state[declarator] = self, self, self
	if name then _G[name] = interface end
	setfenv(2, env)
end