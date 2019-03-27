if module then return end
local _G, setfenv, setmetatable = getfenv(0), setfenv, setmetatable
local environments, interfaces = {}, {}

local function pass() end

local environment_mt = {__index=_G}

local function create_module(name)
	local environment = setmetatable({_G=_G, pass=pass}, environment_mt)
	local exports = {}
	environment.M = setmetatable({}, {
		__metatable=false,
		__newindex=function(_, k, v)
			environment[k], exports[k] = v, v
		end,
	})
	environment._M = environment
	environments[name] = environment
	interfaces[name] = setmetatable({}, {__metatable=false, __index=exports, __newindex=pass})
end

function module(name)
	local defined = not not environments[name]
	if not defined then
		create_module(name)
	end
	setfenv(2, environments[name])
	return defined
end

function require(name)
    if not interfaces[name] then
        create_module(name)
    end
	return interfaces[name]
end