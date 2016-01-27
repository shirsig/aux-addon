local m = {}
Aux.listing_util = m

function m.money_column(name, getter)
    return {
        title = name,
        width = 80,
        comparator = function(datum1, datum2) return Aux.util.compare(getter(datum1), getter(datum2), Aux.util.GT) end,
        cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
        cell_setter = function(cell, datum)
            cell.text:SetText(getter(datum) and Aux.util.money_string(getter(datum)) or 'N/A')
--            group_alpha_setter(cell, getter(datum))
        end,
    }
end

function m.owner_column(getter)
    return {
        title = 'Owner',
        width = 90,
        comparator = function(datum1, datum2)
            if getter(datum1) == UnitName('player') and getter(datum2) == UnitName('player') then
                return Aux.util.EQ
            elseif getter(datum1) == UnitName('player') then
                return Aux.util.LT
            elseif getter(datum2) == UnitName('player') then
                return Aux.util.GT
            else
                return Aux.util.compare(getter(datum1), getter(datum2), Aux.util.GT)
            end
        end,
        cell_initializer = Aux.sheet.default_cell_initializer('LEFT'),
        cell_setter = function(cell, datum)
            cell.text:SetText(getter(datum) == UnitName('player') and GREEN_FONT_COLOR_CODE..'You'..FONT_COLOR_CODE_CLOSE or getter(datum))
        end,
    }
end

function m.percentage_market_column(item_key_getter, value_getter)
    return {
        title = 'Pct',
        width = 40,
        comparator = function(datum1, datum2)
            local market_price1 = Aux.history.market_value(item_key_getter(datum1))
            local market_price2 = Aux.history.market_value(item_key_getter(datum2))
            local factor1 = value_getter(datum1) and market_price1 and market_price1 > 0 and value_getter(datum1) / market_price1
            local factor2 = value_getter(datum2) and market_price2 and market_price2 > 0 and value_getter(datum2) / market_price2
            return Aux.util.compare(factor1, factor2, Aux.util.GT)
        end,
        cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
        cell_setter = function(cell, datum)
            local market_price = Aux.history.market_value(item_key_getter(datum))

            local pct = value_getter(datum) and market_price and market_price > 0 and ceil(100 / market_price * value_getter(datum))
            if not pct then
                cell.text:SetText('N/A')
                cell.text:SetTextColor(0.8, 0.8, 0.8)
            elseif pct > 999 then
                cell.text:SetText('>999%')
            else
                cell.text:SetText(pct..'%')
            end
            if pct then
                cell.text:SetTextColor(Aux.price_level_color(pct))
            end
        end,
    }
end