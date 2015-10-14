Aux.sheet = {}

Aux.list = {}

local NAME, LEVEL, OWNER, BID, BID_UNIT, BUYOUT, BUYOUT_UNIT, QUANTITY, TIME_LEFT = 1, 2, 3, 4, 5, 6, 7, 8, 9

MoneyTypeInfo["AUX_LIST"] = {
	UpdateFunc = function()
		return this.staticMoney
	end,
	collapse = 1,
	fixedWidth = 1,
	showSmallerCoins = 1,
}

function Aux.list.on_load()
	Aux.sheet.initialize(this, physical_columns, logical_columns)
end

function Aux.sheet.render(sheet)
	
	for i, physical_column in ipairs(sheet.physical_columns) do
		local sort_info = sheet.sort_order[1]
		local logical_column = physical_column.logical_column
		
		if sort_info.logical_column == logical_column then
			if sort_info.sort_ascending then
				sheet.labels[i].sort_texture:SetTexCoord(0,0.55,0.2,0.9)
				sheet.labels[i].sort_texture:SetVertexColor(0.2,1,0)
				sheet.labels[i].sort_texture:Show()
			else
				sheet.labels[i].sort_texture:SetTexCoord(0,0.55,0.9,0.2)
				sheet.labels[i].sort_texture:SetVertexColor(1,0.2,0)
				sheet.labels[i].sort_texture:Show()
			end
		else
			sheet.labels[i].texture:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
			sheet.labels[i].sort_texture:Hide()
		end
	end
	
	FauxScrollFrame_Update(sheet.scroll_frame, getn(sheet.data), getn(sheet.rows), 16)
	sheet.scroll_frame:Show()
	local offset = FauxScrollFrame_GetOffset(sheet.scroll_frame)
	--local vSize = self.panel.vSize
	local hSize = getn(sheet.physical_columns)

	local rows = sheet.rows
	local data = sheet.data

	for i, row in ipairs(rows) do
		local direction, rowR, rowG, rowB, rowA1, rowA2 = "Horizontal", 1, 1, 1, 0, 0 --row level coloring used for gradients
		local datum = data[i + offset]
		for j, physical_column in sheet.physical_columns do
			local cell = row[j]
			if datum then
				physical_column.logical_column.cell_setter(cell, datum)
				cell:Show()
			else
				cell:Hide()
			end
		end
		rows[i].color_texture:SetGradientAlpha(direction, rowR, rowG, rowB, rowA1, rowR, rowG, rowB, rowA2)--row color to apply
	end
end

function Aux.sheet.create(frame, physical_columns, sort_order, on_cell_click, on_cell_enter, on_cell_leave)
	local sheet
	local name = (frame:GetName() or '')..'ScrollSheet'
	
	local id = 1
	while getglobal(name..id) do
		id = id + 1
	end
	name = name..id

	local scroll_frame = CreateFrame("ScrollFrame", name..'ScrollFrame', frame, "FauxScrollFrameTemplate")
	scroll_frame:SetScript("OnVerticalScroll", function()
		FauxScrollFrame_OnVerticalScroll(16, function() Aux.sheet.render(this.sheet) end)
	end)
	scroll_frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -10)
	scroll_frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 5, 19)
	
	local parent_height = frame:GetHeight()
	local content = CreateFrame('Frame', name..'Content', frame)
	content:SetHeight(parent_height - 30)
	content:SetPoint("TOPLEFT", scroll_frame, "TOPLEFT", 5, 0)

	local total_width = 0
	
	local labels = {}
	for i = 1,getn(physical_columns) do
		local button = CreateFrame('Button', nil, content)
		if i == 1 then
			button:SetPoint('TOPLEFT', content, 'TOPLEFT', 5, 0)
			total_width = total_width + 5
		else
			button:SetPoint('TOPLEFT', labels[i-1].button, 'TOPRIGHT', 3, 0)
			total_width = total_width + 3
		end
		local label = content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
		label:SetText(physical_columns[i].logical_column.title)
		local column_width = physical_columns[i].width or 30
		
		total_width = total_width + column_width
		button:SetWidth(column_width)
		button:SetHeight(16)
		button:SetID(i)
		button:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight')
		button:SetScript("OnMouseDown", function() Aux.list.sort(sheet, this:GetID()) end)
		
		local texture = content:CreateTexture(nil, 'ARTWORK')
		texture:SetTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight')
		texture:SetTexCoord(0.1, 0.8, 0, 1)
		texture:SetAllPoints(button)
		button.texture = texture 
		
		local sort_texture = button:CreateTexture(nil, 'ARTWORK')
		sort_texture:SetTexture('Interface\\Buttons\\UI-SortArrow')
		sort_texture:SetPoint('TOPRIGHT', button, 'TOPRIGHT', 0, 0)
		sort_texture:SetPoint('BOTTOM', button, 'BOTTOM', 0, 0)
		sort_texture:SetWidth(12)
		sort_texture:Hide()
		button.sort_texture = sort_texture
		
		local background = content:CreateTexture(nil, 'ARTWORK')
		background:SetTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight')
		-- background:SetTextCoord(0.2, 0.9, 0, 0.9)
		background:SetPoint('TOPLEFT', button, 'BOTTOMLEFT', 0, 0)
		background:SetPoint('TOPRIGHT', button, 'BOTTOMRIGHT', 0, 0)
		background:SetPoint('BOTTOM', content, 'BOTTOM', 0, 0)
		background:SetAlpha(0.2)
		
		label:SetPoint('TOPLEFT', button, 'TOPLEFT', 0, 0)
		label:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', 0, 0)
		label:SetJustifyH('CENTER')
		label:SetJustifyV('CENTER')
		label:SetTextColor(0.8, 0.8, 0.8)
		
		label.button = button
		label.texture = texture
		label.sort_texture = sort_texture
		label.background = background
		labels[i] = label
	end
	total_width = total_width + 5
	
	local rows = {}
	local row_index = 1
	local max_height = content:GetHeight()
	local total_height = 16
	while total_height + 14 < max_height do
		local row = {}
		for i = 1,getn(physical_columns) do
			local cell = CreateFrame('Button', nil, content)
			cell:SetPoint('TOPLEFT', labels[i], 'BOTTOMLEFT', 0, -((row_index-1) * 14))
			cell:SetPoint('TOPRIGHT', labels[i], 'BOTTOMRIGHT', 0, -((row_index-1) * 14))				
			
			cell:SetHeight(14)
			
			local row_index, column_index = row_index, i
			cell:SetScript("OnClick", function() if sheet.on_cell_click then sheet.on_cell_click(sheet, row_index, column_index) end end)
			cell:SetScript("OnEnter", function() if sheet.on_cell_enter then sheet.on_cell_enter(sheet, row_index, column_index) end end)
			cell:SetScript("OnLeave", function() if sheet.on_cell_leave then sheet.on_cell_leave(sheet, row_index, column_index) end end)
			
			physical_columns[i].logical_column.cell_initializer(cell)
			
			row[i] = cell
		end
		
		local color_texture = content:CreateTexture()
		color_texture:SetPoint('TOPLEFT', row[1], 'TOPLEFT', 0, 0)
		color_texture:SetPoint('BOTTOMRIGHT', row[getn(physical_columns)], 'BOTTOMRIGHT', 0, 1)
		color_texture:SetTexture(1, 1, 1)
		row.color_texture = color_texture
		
		local highlight = content:CreateTexture()
		highlight:SetPoint('TOPLEFT', row[1], 'TOPLEFT', 0, 0)
		highlight:SetPoint('BOTTOMRIGHT', row[getn(physical_columns)], 'BOTTOMRIGHT', 0, 1)
		highlight:SetAlpha(0)
		highlight:SetTexture(0.8, 0.6, 0)
		row.highlight = highlight
		
		rows[row_index] = row
		row_index = row_index + 1
		total_height = total_height + 14		
	end
	
	content:SetWidth(total_width)
	
	sheet = {
		name = name,
		content = content,
		scroll_frame = scroll_frame,
		labels = labels,
		rows = rows,
		physical_columns = physical_columns,
		data = {},
		sort_order = sort_order,
		on_cell_click = on_cell_click,
		on_cell_enter = on_cell_enter,
		on_cell_leave = on_cell_leave,
	}
	scroll_frame.sheet = sheet
	
	return sheet
end

function Aux.list.row_comparator(sheet)
	return function(row1, row2)
		for _, sort_info in ipairs(sheet.sort_order) do
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

function Aux.sheet.default_cell_initializer(alignment)
	return function(cell)
		local text = cell:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
		text:SetAllPoints(cell)
		text:SetJustifyV('TOP')
		text:SetJustifyH(alignment)
		text:SetTextColor(0.8, 0.8, 0.8)
		cell.text = text
	end
end

function Aux.sheet.initialize(frame)

	local logical_columns = {
		{
			title = 'Auction Item',
			texture = function(row) return row.texture end,
			comparator = function(row1, row2) return Aux.util.compare(row1.tooltip[1][1].text, row2.tooltip[1][1].text, Aux.util.GT) end,
			cell_initializer = function(cell)
				local icon = CreateFrame('Button', nil, cell)
				icon:SetPoint('LEFT', cell)
				icon:SetWidth(12)
				icon:SetHeight(12)
				local text = cell:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
				text:SetPoint("LEFT", icon, "RIGHT", 1, 0)
				text:SetPoint('TOPRIGHT', cell)
				text:SetPoint('BOTTOMRIGHT', cell)
				text:SetJustifyV('TOP')
				text:SetJustifyH('LEFT')
				text:SetTextColor(0.8, 0.8, 0.8)
				cell.text = text
				cell.icon = icon
			end,
			cell_setter = function(cell, datum)
				cell.icon:SetNormalTexture(datum.texture)
				cell.text:SetText('['..datum.tooltip[1][1].text..']')
				local color = ITEM_QUALITY_COLORS[datum.quality]
				cell.text:SetTextColor(color.r, color.g, color.b)
			end,
		},
		{
			title = 'Lvl',
			comparator = function(row1, row2) return Aux.util.compare(row1.level, row2.level, Aux.util.GT) end,
			cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
			cell_setter = function(cell, datum)
				cell.text:SetText(max(1, datum.level))
			end,
		},
		{
			title = 'Owner',
			comparator = function(row1, row2) return Aux.util.compare(row1.owner, row2.owner, Aux.util.GT) end,
			cell_initializer = Aux.sheet.default_cell_initializer('LEFT'),
			cell_setter = function(cell, datum)
				cell.text:SetText(datum.owner)
			end,
		},
		{
			title = 'Bid',
			comparator = function(row1, row2) return Aux.util.compare(row1.bid, row2.bid, Aux.util.GT) end,
			cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
			cell_setter = function(cell, datum)
				cell.text:SetText(Aux.util.money_string(datum.bid))
			end,
		},
		{
			title = 'Bid/ea',
			comparator = function(row1, row2) return Aux.util.compare(row1.bid_per_unit, row2.bid_per_unit, Aux.util.GT) end,
			cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
			cell_setter = function(cell, datum)
				cell.text:SetText(Aux.util.money_string(datum.bid_per_unit))
			end,
		},
		{
			title = 'Buy',
			comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price, row2.buyout_price, Aux.util.GT) end,
			cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
			cell_setter = function(cell, datum)
				cell.text:SetText(Aux.util.money_string(datum.buyout_price))
			end,
		},
		{
			title = 'Buy/ea',
			comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price_per_unit, row2.buyout_price_per_unit, Aux.util.GT) end,
			cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
			cell_setter = function(cell, datum)
				cell.text:SetText(Aux.util.money_string(datum.buyout_price_per_unit))
			end,
		},
		{
			title = '#',
			comparator = function(row1, row2) return Aux.util.compare(row1.stack_size, row2.stack_size, Aux.util.LT) end,
			cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
			cell_setter = function(cell, datum)
				cell.text:SetText(datum.stack_size)
			end,
		},
		{
			title = 'Left',
			comparator = function(row1, row2) return Aux.util.compare(row1.duration, row2.duration, Aux.util.GT) end,
			cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
			cell_setter = function(cell, datum)
				local text
				if datum.duration == 1 then
					text = '30m'
				elseif datum.duration == 2 then
					text = '2h'			
				elseif datum.duration == 3 then
					text = '8h'
				elseif datum.duration == 4 then
					text = '24h'
				end
				cell.text:SetText(text)
			end,
		},
	}

	local physical_columns = {
		{
			logical_columns = { logical_columns[QUANTITY] },
			logical_column = logical_columns[QUANTITY],
			width = 23
		},
		{
			logical_columns = { logical_columns[NAME] },
			logical_column = logical_columns[NAME],
			width = 157
		},
		{
			logical_columns = { logical_columns[LEVEL] },
			logical_column = logical_columns[LEVEL],
			width = 23
		},
		{
			logical_columns = { logical_columns[TIME_LEFT] },
			logical_column = logical_columns[TIME_LEFT],
			width = 30
		},
		{
			logical_columns = { logical_columns[OWNER] },
			logical_column = logical_columns[OWNER],
			width = 70
		},
		{
			logical_columns = { logical_columns[BID_UNIT], logical_columns[BUYOUT_UNIT] },
			logical_column = logical_columns[BID_UNIT],
			width = 70
		},
		{
			logical_columns = { logical_columns[BID_UNIT], logical_columns[BUYOUT_UNIT] },
			logical_column = logical_columns[BUYOUT_UNIT],
			width = 70
		},
		{
			logical_columns = { logical_columns[BID], logical_columns[BUYOUT] },
			logical_column = logical_columns[BID],
			width = 70
		},
		{
			logical_columns = { logical_columns[BID], logical_columns[BUYOUT] },
			logical_column = logical_columns[BUYOUT],
			width = 70
		},
	}
	
	local sort_order = {}
	for i, logical_column in logical_columns do
		if i ~= BUYOUT_UNIT and i ~= NAME then 
			tinsert(sort_order, { logical_column = logical_column, sort_ascending = true })
		end
	end
	tinsert(sort_order, 1, { logical_column = logical_columns[BUYOUT_UNIT], sort_ascending = true })
	tinsert(sort_order, 1, { logical_column = logical_columns[NAME], sort_ascending = true })
	
	
	function on_cell_click(sheet, row_index, column_index)
		local entry_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
		AuxBuyEntry_OnClick(entry_index)
	end
	
	function on_cell_enter(sheet, row_index, column_index)
		sheet.rows[row_index].highlight:SetAlpha(.5)
	end
	
	function on_cell_leave(sheet, row_index, column_index)
		sheet.rows[row_index].highlight:SetAlpha(0)
	end
	
	return Aux.sheet.create(frame, physical_columns, sort_order, on_cell_click, on_cell_enter, on_cell_leave)
end

function Aux.list.populate(sheet, data)
	sheet.data = data

	-- Perform the sort.
	Aux.util.merge_sort(sheet.data, Aux.list.row_comparator(sheet))

	-- Update the scroll pane.
	Aux.sheet.render(sheet)
end

function Aux.list.sort(sheet, physical_column_index)

	local physical_column = sheet.physical_columns[physical_column_index]
	local logical_column = physical_column.logical_column
			
	if sheet.sort_order[1].logical_column == logical_column then
		sheet.sort_order[1].sort_ascending = not sheet.sort_order[1].sort_ascending
	else
		for index, sort_info in ipairs(sheet.sort_order) do
			if sort_info.logical_column == logical_column then
				local temp = sort_info
				table.remove(sheet.sort_order, index)
				table.insert(sheet.sort_order, 1, temp)
				break
			end
		end
		sheet.sort_order[1].sort_ascending = true
	end
	
	Aux.util.merge_sort(sheet.data, Aux.list.row_comparator(sheet))

	Aux.sheet.render(sheet)
end

function Aux.list.dropdown_on_load()
	getglobal(this:GetName().."Text"):Hide()
	this.initialize = Aux.list.dropdown_initialize
	UIDropDownMenu_SetSelectedID(this, 1)
end

function Aux.list.dropdown_initialize()
	local dropdown = this:GetParent()
	local frame = dropdown:GetParent()
	
	if frame.physical_columns then
		local physical_column_index = dropdown:GetID()
		local physical_column = frame.physical_columns[physical_column_index]
		for _, logical_column in pairs(physical_column.logical_columns) do
			UIDropDownMenu_AddButton({
				text = logical_column.title,
				owner = dropdown,
				func = Aux.list.dropdown_item_onclick,
			})
		end
	end
end

function Aux.list.dropdown_item_onclick()
	local logical_column_index = this:GetID()
	local physical_column_index = this.owner:GetID()
	local dropdown = this.owner
	local frame = dropdown:GetParent()
	if frame.physical_columns[physical_column_index].logical_column ~= frame.logical_columns[logical_column_index] then

		frame.physical_columns[physical_column_index].logical_column = frame.physical_columns[physical_column_index].logical_columns[logical_column_index]
		getglobal(frame:GetName().."Column"..physical_column_index.."SortText"):SetText(frame.physical_columns[physical_column_index].logical_column.title)

		Aux.util.merge_sort(frame.data, Aux.list.row_comparator(frame))

		UIDropDownMenu_SetSelectedID(dropdown, logical_column_index)
		Aux.list.scroll_frame_update(getglobal(frame:GetName().."ScrollFrame"))
	end
end