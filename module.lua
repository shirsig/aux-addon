local __ = {}

local public_interface_mt = {
	__newindex = function()
		error('Unsupported operation.', 2)
	end,
	__index = function(self, key)
		if __[self].public[key] then
			return __[self].data[key]
		else
			error('Read of undeclared "'..key..'".', 2)
		end
	end,
}
local private_interface_mt = {
	__newindex = function(self, key, value)
		if not __[self].declared[key] then
			error('Write of undeclared "'..key..'".', 2)
		end
		__[self].data[key] = value
	end,
	__index = function(self, key)
		if not __[self].declared[key] then
			error('Read of undeclared "'..key..'".', 2)
		end
		return __[self].data[key]
	end,
}
local public_declarator_mt = {
	__newindex = function(self, key, value)
		if __[self].declared[key] then
			error('Multiple declarations of "'..key..'".', 2)
		end
		__[self].data[key] = value
		__[self].public[key] = true
		__[self].declared[key] = true
	end,
	__index = function()
		error('Unsupported operation.', 2)
	end,
}
local private_declarator_mt = {
	__newindex = function(self, key, value)
		if __[self].declared[key] then
			error('Multiple declarations of "'..key..'".', 2)
		end
		__[self].data[key] = value
		__[self].declared[key] = true
	end,
	__index = function()
		error('Unsupported operation.', 2)
	end,
}

function aux_module()
	local dataset = {data={}, public={}, declared={}}
    local module = {setmetatable({}, public_interface_mt), setmetatable({}, private_interface_mt), setmetatable({}, public_declarator_mt), setmetatable({}, private_declarator_mt)}
	for _, component in module do
		__[component] = dataset
	end
    return module
end