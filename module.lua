local wrap, unwrap = (function()
    local null = {}
    return function(value)
        if value == nil then
            return null
        else
            return value
        end
    end,
    function(value)
        if value == null then
            return nil
        else
            return value
        end
    end
end)()

function Aux_module(name)
    local data, is_public, public_interface, private_interface, public, private = {}, {}, {}, {}, {}, {}
    setmetatable(public_interface, {
        __newindex = function(_, key)
            error('Illegal write of attribute "'..key..'" on public interface of "'..name..'"!')
        end,
        __index = function(_, key)
            if data[key] == nil then
                error('Access of undeclared attribute "'..key..'" on public interface of "'..name..'"!')
            end
            if is_public[key] then
                return unwrap(data[key])
            end
        end,
        __call = function(_, key)
            return is_public[key]
        end
    })
    setmetatable(private_interface, {
        __newindex = function(_, key, value)
            if data[key] == nil then
                error('Assignment of undeclared attribute "'..key..'" on private interface of "'..name..'"!')
            end
            data[key] = wrap(value)
        end,
        __index = function(_, key)
            if data[key] == nil then
                error('Access of undeclared attribute "'..key..'" on private interface of "'..name..'"!')
            end
            return unwrap(data[key])
        end,
        __call = function(_, key)
            return data[key] ~= nil
        end
    })
    setmetatable(public, {
        __newindex = function(_, key, value)
            if data[key] ~= nil then
                error('Multiple declarations of "'..key..'" in "'..name..'"!')
            end
            data[key] = wrap(value)
            is_public[key] = true
        end,
        __index = function(_, key)
            error('Illegal read of attribute "'..key..'" on public keyword in "'..name..'"!')
        end,
    })
    setmetatable(private, {
        __newindex = function(_, key, value)
            if data[key] ~= nil then
                error('Multiple declarations of "'..key..'" in "'..name..'"!')
            end
            data[key] = wrap(value)
            is_public[key] = nil
        end,
        __index = function(_, key)
            error('Illegal read of attribute "'..key..'" on private keyword in "'..name..'"!')
        end,
    })
    return { public_interface, private_interface, public, private }
end