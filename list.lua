Aux.list = {}

local MAX_COLUMNS = 6

local NAME, OWNER, BID, BID_UNIT, BUYOUT, BUYOUT_UNIT, QUANTITY = 1, 2, 3, 4, 5, 6, 7, 8

MoneyTypeInfo["AUX_LIST"] = {
	UpdateFunc = function()
		return this.staticMoney
	end,
	collapse = 1,
	fixedWidth = 1,
	showSmallerCoins = 1,
}

local logical_columns = {
	{
		type = 'STRING',
		title = 'Name',
		comparator = function(row1, row2) return Aux.util.compare(row1.name, row2.name, Aux.util.GT) end,
		getter = function(row) return row.name end,
		color = function(row) return ITEM_QUALITY_COLORS[row.quality] end,
	},
	{
		type = 'STRING',
		title = 'Owner',
		comparator = function(row1, row2) return Aux.util.compare(row1.owner, row2.owner, Aux.util.GT) end,
		getter = function(row) return row.owner end,
	},
	{
		type = 'MONEY',
		title = 'Bid',
		comparator = function(row1, row2) return Aux.util.compare(row1.bid, row2.bid, Aux.util.GT) end,
		getter = function(row) return row.bid end,
	},
	{
		type = 'MONEY',
		title = 'Bid (Unit)',
		comparator = function(row1, row2) return Aux.util.compare(row1.bid_per_unit, row2.bid_per_unit, Aux.util.GT) end,
		getter = function(row) return row.bid_per_unit end,
	},
	{
		type = 'MONEY',
		title = 'Buyout',
		comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price, row2.buyout_price, Aux.util.GT) end,
		getter = function(row) return row.buyout_price end,
	},
	{
		type = 'MONEY',
		title = 'Buyout (Unit)',
		comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price_per_unit, row2.buyout_price_per_unit, Aux.util.GT) end,
		getter = function(row) return row.buyout_price_per_unit end,
	},
	{
		type = 'NUMBER',
		title = 'Quantity',
		comparator = function(row1, row2) return Aux.util.compare(row1.stack_size, row2.stack_size, Aux.util.LT) end,
		getter = function(row) return row.stack_size end,
	},
	{
		type = 'STRING',
		title = 'Time Left',
		comparator = function(row1, row2) return Aux.util.invert_order(Aux.util.compare(row1.duration, row2.duration, Aux.util.GT)) end,
		getter = function(row)
			if row.duration == 1 then
				return 'Short'
			elseif row.duration == 2 then
				return 'Medium'			
			elseif row.duration == 3 then
				return 'Long'
			elseif row.duration == 4 then
				return 'Very Long'
			end
		end,
	},
}

local physical_columns = {
	{ logical_column = logical_columns[NAME], width = 156 },
	{ logical_column = logical_columns[OWNER], width = 156 },
	{ logical_column = logical_columns[BUYOUT_UNIT], width = 156 },
	{ logical_column = logical_columns[QUANTITY], width = 156 },
	{ logical_column = logical_columns[BUYOUT], width = 156 },
}



function Aux.list.on_load()
	Aux.list.initialize(this, physical_columns, logical_columns)
end

-------------------------------------------------------------------------------
-- Aux.util.compare two rows
-------------------------------------------------------------------------------

function Aux.list.row_comparator(list_frame)
	return function(row1, row2)
		for _, sort_info in ipairs(list_frame.sort_order) do
			local logical_column = sort_info.logical_column
			if logical_column.comparator then
				local ordering = logical_column.comparator(row1, row2)
				if ordering ~= Aux.util.EQ then
					return sort_info.sort_ascending and ordering or Aux.util.invert_order(ordering)
				end
			end
		end
		return Aux.util.EQ
	end
end

-------------------------------------------------------------------------------
-- Initialize the list with the column information
-------------------------------------------------------------------------------
function Aux.list.initialize(frame, physical_columns, logical_columns)
	frame.lines = 19
	frame.lineHeight = 16
	frame.content = {}
	frame.physical_columns = physical_columns
	frame.logical_columns = logical_columns

	frame.sort_order = {}
	for i, logical_column in logical_columns do
		if i ~= BUYOUT_UNIT then 
			tinsert(frame.sort_order, { logical_column = logical_column, sort_ascending = true })
		end
	end
	tinsert(frame.sort_order, 1, { logical_column = logical_columns[BUYOUT_UNIT], sort_ascending = true })
	
	for i = 1, MAX_COLUMNS do
		local button = getglobal(frame:GetName().."Column"..i.."Sort")
		local dropdown = getglobal(frame:GetName().."Column"..i.."DropDown")
		if (i <= table.getn(physical_columns)) then
			local physical_column = physical_columns[i]
			local logical_column = physical_column.logical_column
			UIDropDownMenu_SetSelectedID(dropdown, Aux.util.index_of(logical_column, logical_columns))
			getglobal(button:GetName().."Arrow"):Hide()
			getglobal(button:GetName().."Text"):SetText(logical_column.title)
			button:Show()
			dropdown:Show()

			Aux.list.set_column_width(frame, i, physical_column.width);
		else
			button:Hide()
			dropdown:Hide()
		end
	end
end

-------------------------------------------------------------------------------
-- Initialize the list with the column information
-------------------------------------------------------------------------------
function Aux.list.set_column_width(frame, column_index, width)
	-- Resize the header
	local button = getglobal(frame:GetName().."Column"..column_index.."Sort")
	button:SetWidth(width + 2)
	local dropdown = getglobal(frame:GetName().."Column"..column_index.."DropDown")
	UIDropDownMenu_SetWidth(width - 18, dropdown)

	-- Resize each cell in the columns
	for line = 1, frame.lines do
		local text = getglobal(frame:GetName().."Item"..line.."Column"..column_index)
		if text then
			text:SetWidth(width - 20)
		end
	end
end

-------------------------------------------------------------------------------
-- Set the item to display.
-------------------------------------------------------------------------------
function Aux.list.populate(frame, content)
	frame.content = content

	-- Perform the sort.
	Aux.util.merge_sort(frame.content, Aux.list.row_comparator(frame))

	-- Update the scroll pane.
	Aux.list.scroll_frame_update(getglobal(frame:GetName().."ScrollFrame"))
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- function ListTemplate_SelectRow(frame, row)
	-- if frame.selectedRow ~= row then
		-- local scrollFrame = getglobal(frame:GetName().."ScrollFrame")
		-- local firstVisibleRow = FauxScrollFrame_GetOffset(scrollFrame) + 1
		-- local lastVisibleRow = firstVisibleRow + frame.lines - 1

		-- -- Deselect the previous row
		-- if frame.selectedRow and firstVisibleRow <= frame.selectedRow and frame.selectedRow <= lastVisibleRow then
			-- local line = frame.selectedRow - firstVisibleRow + 1
			-- local item = getglobal(frame:GetName().."Item"..line)
			-- item:UnlockHighlight()
		-- end

		-- -- Update the selected item
		-- frame.selectedRow = row

		-- -- Select the new row
		-- if frame.selectedRow and firstVisibleRow <= frame.selectedRow and frame.selectedRow <= lastVisibleRow then
			-- local line = frame.selectedRow - firstVisibleRow + 1
			-- local item = getglobal(frame:GetName().."Item"..line)
			-- item:LockHighlight()
		-- end
	-- end
-- end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function Aux.list.sort(frame, physical_column_index)

	local physical_column = frame.physical_columns[physical_column_index]
	local logical_column = physical_column.logical_column
			
	if frame.sort_order[1].logical_column == logical_column then
		frame.sort_order[1].sort_ascending = not frame.sort_order[1].sort_ascending
	else
		for index, sort_info in ipairs(frame.sort_order) do
			if sort_info.logical_column == logical_column then
				local temp = sort_info
				table.remove(frame.sort_order, index)
				table.insert(frame.sort_order, 1, temp)
				break
			end
		end
		frame.sort_order[1].sort_ascending = true
	end
	
	Aux.util.merge_sort(frame.content, Aux.list.row_comparator(frame))

	Aux.list.scroll_frame_update(getglobal(frame:GetName().."ScrollFrame"))
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function Aux.list.scroll_frame_update(frame)
	if not frame then frame = this end
	local parent = frame:GetParent()
	local content = parent.content
	FauxScrollFrame_Update(frame, table.getn(content), parent.lines, parent.lineHeight)
	for line = 1, parent.lines do
		local item = getglobal(parent:GetName().."Item"..line)
		local row_index = line + FauxScrollFrame_GetOffset(frame)
		if row_index <= table.getn(content) then
			for column_index = 1, MAX_COLUMNS do
				
				local text = getglobal(parent:GetName().."Item"..line.."Column"..column_index)
				-- text:Hide() TODO
				text:SetText()

				local moneyFrame = getglobal(parent:GetName().."Item"..line.."Column"..column_index.."MoneyFrame")
				moneyFrame:Hide()

				if column_index <= table.getn(parent.physical_columns) then
					local physical_column = parent.physical_columns[column_index]
					local logical_column = physical_column.logical_column
					local value = logical_column.getter(content[row_index])
					
					local arrow = getglobal(parent:GetName().."Column"..column_index.."SortArrow")
					local sort_info = parent.sort_order[1]
					if sort_info.logical_column == logical_column then
						if sort_info.sort_ascending then
							arrow:SetTexCoord(0, 0.5625, 0, 1.0)
						else
							arrow:SetTexCoord(0, 0.5625, 1.0, 0)
						end
						arrow:Show()
					else
						arrow:Hide()
					end
				
					if value then
						if text and (logical_column.type == "DATE" or logical_column.type == "NUMBER" or logical_column.type == "STRING") then
							text:SetText(value)
							if logical_column.color then
								local color = logical_column.color(content[row_index])
								text:SetTextColor(color.r, color.g, color.b)
							else
								text:SetTextColor(255, 255, 255)
							end
							if logical_column.alphaFunc then
								text:SetAlpha(logical_column.alphaFunc(content[row_index]))
							else
								text:SetAlpha(1.0)
							end
							if (logical_column.type == "NUMBER") then
								text:SetJustifyH("RIGHT")
							else
								text:SetJustifyH("LEFT")
							end
							text:Show()
						elseif moneyFrame and logical_column.type == "MONEY" then
							if value >= 0 then
								MoneyFrame_Update(moneyFrame:GetName(), value)
								SetMoneyFrameColor(moneyFrame:GetName(), 255, 255, 255)
							else
								MoneyFrame_Update(moneyFrame:GetName(), -value)
								SetMoneyFrameColor(moneyFrame:GetName(), 255, 0, 0)
							end
							if logical_column.alphaFunc then
								moneyFrame:SetAlpha(logical_column.alphaFunc(content[row_index]))
							else
								moneyFrame:SetAlpha(1.0)
							end
							moneyFrame:Show()
						end
					end
				end
			end
			-- -- Update the row highlight
			-- if parent.selectedRow and parent.selectedRow == row_index then
				-- item:LockHighlight()
			-- else
				-- item:UnlockHighlight()
			-- end
			item:Show()
		else
			item:Hide()
		end
		AuxBuyListScrollFrame:Show()
	end
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function Aux.list.dropdown_on_load()
	getglobal(this:GetName().."Text"):Hide()
	this.initialize = Aux.list.dropdown_initialize
	UIDropDownMenu_SetSelectedID(this, 1)
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function Aux.list.dropdown_initialize()
	local dropdown = this:GetParent()
	local frame = dropdown:GetParent()

	for _, logical_column in pairs(frame.logical_columns) do
		UIDropDownMenu_AddButton({
			text = logical_column.title,
			owner = dropdown,
			func = Aux.list.dropdown_item_onclick
		})
	end
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function Aux.list.dropdown_item_onclick()
	local logical_column_index = this:GetID()
	local physical_column_index = this.owner:GetID()
	local dropdown = this.owner
	local frame = dropdown:GetParent()
	if (frame.physical_columns[physical_column_index].logical_column ~= frame.logical_columns[logical_column_index]) then

		frame.physical_columns[physical_column_index].logical_column = frame.logical_columns[logical_column_index]
		getglobal(frame:GetName().."Column"..physical_column_index.."SortText"):SetText(frame.physical_columns[physical_column_index].logical_column.title)

		Aux.util.merge_sort(frame.content, Aux.list.row_comparator(frame))

		UIDropDownMenu_SetSelectedID(dropdown, logical_column_index)
		Aux.list.scroll_frame_update(getglobal(frame:GetName().."ScrollFrame"))
	end
end


