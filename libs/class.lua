if module then return end
local typeof, setmetatable, setfenv, unpack, next, pcall, _G = type, setmetatable, setfenv, unpack, next, pcall, getfenv(0)

local PUBLIC, PRIVATE = 1, 2
local INDEX, NEWINDEX, CALL = 1, 2, 3

local function error(msg, ...) return _G.error(format(msg or '', unpack(arg))..'\n'..debugstack(), 0) end
local function import_error() error 'Invalid imports.' end
local function declaration_error() error 'Invalid declaration.' end
local function collision_error(key) error('"%s" already exists.', key) end

local function nop() end
local function id(v) return v end
local function const(v) return function() return v end end

local _state = {}

local env_mt, start_declaration

local interface_mt = {__metatable=false}
function interface_mt:__index(key)
	return generic_function end


	local state=_state[self]
if state.access[key] == PUBLIC then
	local index = state[INDEX][key]
	if index then return index() else return state[CALL][key] end
end

function interface_mt:__newindex(key, value) local state=_state[self]
if state.access[key] == PUBLIC then (state[NEWINDEX][key] or state[CALL][key])(value) end
end


function class()
	local self = {}

	return self, create_new_object
end

local _

local message

function handle() end