if module then return end
local setfenv, getmetatable, setmetatable, type, unpack, next, _G = setfenv, getmetatable, setmetatable, type, unpack, next, getfenv(0)

local PUBLIC, PRIVATE = 1, 2
local CALL, INDEX, NEWINDEX = 1, 2, 3

local function error(msg, ...) return _G.error(format(msg or '', unpack(arg)) .. '\n' .. debugstack(), 0) end
local function import_error() error('Import error.') end
local function declaration_error() error('Declaration error.') end
local function collision_error(key) error('"%s" already exists.', key) end
local function nil_error(key) if key then error('"%s" is nil.', key) else error('Callee is nil') end end

local nop = function() end

local function prototype() local eq = function() return true end
	return setmetatable({__metatable=false, __eq=eq}, {__metatable=false, __eq=eq, __call=function(self, t) return setmetatable(t, self) end})
end

local INTERFACE, ENVIRONMENT, DECLARATOR = prototype(), prototype(), prototype()

local state = {}

function INTERFACE:__index(key) self=state[self]
	if self.access[key] == PUBLIC then return self[CALL][key] or (self[INDEX][key] or nop)() end
end
function INTERFACE:__newindex(key, value) self=state[self]
	if self.access[key] == PUBLIC then (self[NEWINDEX][key] or nop)(value) end
end

function ENVIRONMENT:__index(key) self=state[self]
	local f = self[CALL][key]; if f then return f end
	local getter = self[INDEX][key]; if getter then return getter() end
	return _G[key] or self.declarator[key]
end
function ENVIRONMENT:__newindex(key, value) self=state[self]
	if self.access[key] then (self[NEWINDEX][key] or collision_error(key))(value) else self.declarator[key] = value end
end
ENVIRONMENT.__call = nop -- TODO

do
	local ACCESS, EVENT = {public=PUBLIC, private=PRIVATE}, {call=CALL, get=INDEX, set=NEWINDEX}
	local function declare(self, access, name, handlers)
		self.access[name] = (not self.access[name] or collision_error(name)) and access or self.default_access or declaration_error()
		for event, handler in handlers do local handler = handler
			self[event][name] = type(handler) == 'function' and handler or (event == INDEX and function() return handler end or declaration_error())
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
	function DECLARATOR:__newindex(key, value) self=state[self]; local name, access = self.declaration_name, self.declaration_access
		if name then declare(self, access, name, {[EVENT[key] or nil_error(name)]=value})
		elseif access or self.default_access then declare(self, access, key, {[type(value) == 'function' and CALL or INDEX]=value})
		else _G[key] = (_G[key] == nil or collision_error(key)) and value end --	G.error(nil) TODO silent error?
		self.declaration_access, self.declaration_name = nil, nil
	end
	function DECLARATOR:__call(v) self=state[self]; local name, access = self.declaration_name, self.declaration_access
		if name then
			if type(v) ~= 'table' or getmetatable(v) ~= nil then (access and declaration_error() or nil_error)(name) end
			local f, getter, setter; f, getter, setter, v.call, v.get, v.set = v.call, v.get, v.set, nil, nil, nil
			if next(v) or f ~= nil and getter ~= nil then (access and declaration_error() or nil_error)(name) end
			declare(self, access, name, {[CALL]=f, [INDEX]=getter, [NEWINDEX]=setter})
		elseif access or nil_error() then self.default_access = access end
		self.declaration_access, self.declaration_name = nil, nil
	end
	DECLARATOR.__tostring = function() return 'nil table' end
end

local function import(self, interface)
	local module = (interface == INTERFACE or import_error()) and state[interface]
	for k, v in module.access do
		if v == PUBLIC and not self.access[k] then
			self.access[k], self[CALL][k], self[INDEX][k], self[NEWINDEX][k] = PRIVATE, module[CALL][k], module[INDEX][k], module[NEWINDEX][k]
		end
	end
end

local mt = {}; setmetatable(_G, mt)
function mt:__index(key)
	if key ~= 'module' then return nil end
	local interface, environment, declarator = INTERFACE {}, ENVIRONMENT {}, DECLARATOR {}
	self = {
		access = {_G=PRIVATE, I=PRIVATE, M=PRIVATE, public=PRIVATE, private=PRIVATE, import=PRIVATE, _=PRIVATE, error=PRIVATE, nop=PRIVATE},
		[CALL] = {_G=_G, I=interface, M=environment, import=function(interface) import(self, interface) end, error=error, nop=nop},
		[INDEX] = {public=function() return declarator.public end, private=function() return declarator.private end},
		[NEWINDEX] = {_=nop},
		declarator = declarator,
	}
	state[interface], state[environment], state[declarator] = self, self, self
	setfenv(2, environment)
	return interface
end