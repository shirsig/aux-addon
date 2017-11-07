if module then return end
local _G, setfenv, setmetatable = getfenv(0), setfenv, setmetatable
local environments, exports_data, interfaces = {}, {}, {}

local function nop() end

local function create_module(name)
	local environment, exports = setmetatable({_G=_G, nop=nop}, {__index=_G}), {}
	environment.M = setmetatable({}, {
		__metatable=false,
		__newindex=function(_, k, v)
			environment[k], exports[k] = v, v
		end,
	})
	environment.include = function(name)
		for k, v in exports_data[name] or error('No such module.', 2) do
			environment[k] = v
		end
	end
	environment._M = environment
	interfaces[name] = setmetatable({}, {__metatable=false, __index=exports, __newindex=nop})
	environments[name], exports_data[name] = environment, exports
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
	return interfaces[name]
end