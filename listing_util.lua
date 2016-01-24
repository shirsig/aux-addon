local m = {}
Aux.listing_util = m

function m.money_column(name, getter)
    return {
        title = name,
        width = 80,
        comparator = function(datum1, datum2) return Aux.util.compare(getter(datum1), getter(datum2), Aux.util.GT) end,
        cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
        cell_setter = function(cell, datum)
            cell.text:SetText(Aux.util.money_string(getter(datum)))
--            group_alpha_setter(cell, getter(datum))
        end,
    }
end