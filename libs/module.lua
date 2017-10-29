if module then return end
local _G, setfenv, setmetatable = getfenv(0), setfenv, setmetatable
local loaded, defined = {}, {}

local function nop() end

local function create_module(name)
	local private, public = setmetatable({}, {__index=_G}), {}
	local modifier = setmetatable({}, {
		__metatable=false,
		__newindex=function(_, k, v) private[k], public[k] = v, v end
	})
	private._G, private.nop, private._M, private.M = _G, nop, private, modifier
	private.include = function(name)
		local P = loaded[name] or error('No such module.', 2)
		for k, v in P.public do private[k] = v end		
	end
	local interface = setmetatable({}, {__metatable=false, __index=public, __newindex=nop})
	local P = {private=private, public=public, interface=interface}
	loaded[name] = P
	return P
end

function module(name) local P = loaded[name] or create_module(name); defined[name] = true; setfenv(2, P.private) end
function require(name) local P = loaded[name] or create_module(name); return P.interface end
function _G.defined(name) return defined[name] end
