if module then return end
local _G, setfenv, setmetatable = getfenv(0), setfenv, setmetatable
local loaded = {}

local function nop() end

local function create_module(name)
	local environment, public_fields = setmetatable({}, {__index=_G}), {}
	local public_modifier = setmetatable({}, {
		__metatable=false,
		__newindex=function(_, k, v)
			environment[k], public_fields[k] = v, v
		end,
	})
	environment._G, environment.nop, environment._M, environment.M = _G, nop, environment, public_modifier
	environment.include = function(name)
		local P = loaded[name] or error('No such module.', 2)
		for k, v in P.public_fields do
			environment[k] = v
		end
	end
	local interface = setmetatable({}, {__metatable=false, __index=public_fields, __newindex=nop})
	local P = {environment=environment, public_fields=public_fields, interface=interface}
	loaded[name] = P
	return P
end

function module(name)
	local defined = loaded[name] and true or false
	if not defined then
		create_module(name)
	end
	setfenv(2, loaded[name].environment)
	return defined
end

function require(name)
	local P = loaded[name]
	return P and P.interface
end