if module then return end
local _G, setfenv, setmetatable, rawget = getfenv(0), setfenv, setmetatable, rawget
local loaded, defined, interfaces, environments = {}, {}, {}, {}

local function nop() end

local function include(private, name)
	local P = loaded[name] or error('No such module.', 2)
	for k, v in P.public do private[k] = v end
end

local function create_module(name)
	local P, private, public, modifier
	local modifier = setmetatable({}, {
		__metatable=false,
		__newindex=function(_, k, v)
			public[k] = v
			if rawget(private, k) == nil then
				private[k] = v
			end
		end
	})
	local env = setmetatable(
		{_G=_G, _M=private, M=modifier, include=function(name) include(private, name) end, nop=nop},
		{__index=_G}
	)
	local public = {}
	local interface = setmetatable({}, {__metatable=false, __index=public})
	P = {private=private, public=public}
	environments[name], interfaces[name] = env, interface
	loaded[name] = P
end

function module(name) if not loaded[name] then create_module(name) end defined[name] = true; setfenv(2, environments[name]) end
function require(name) if not loaded[name] then create_module(name) end return interfaces[name] end
function _G.defined(name) return defined[name] end