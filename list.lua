Aux.sheet = {}

local GSC_GOLD = 'ffd100'
local GSC_SILVER = 'e6e6e6'
local GSC_COPPER= 'c8602c'
local GSC_RED = 'ff0000'

Aux.list = {}

local MAX_COLUMNS = 7

local NAME, LEVEL, OWNER, BID, BID_UNIT, BUYOUT, BUYOUT_UNIT, QUANTITY, TIME_LEFT = 1, 2, 3, 4, 5, 6, 7, 8, 9

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
		title = 'Auction Item',
		texture = function(row) return row.texture end,
		comparator = function(row1, row2) return Aux.util.compare(row1.tooltip[1][1].text, row2.tooltip[1][1].text, Aux.util.GT) end,
		getter = function(row) return '      ['..row.tooltip[1][1].text..']' end,
		color = function(row) return ITEM_QUALITY_COLORS[row.quality] end,
		cell_initializer = Aux.sheet.default_cell_initializor('LEFT'),
		cell_setter = function(cell) end,
	},
	{
		title = 'Lvl',
		comparator = function(row1, row2) return Aux.util.compare(row1.level, row2.level, Aux.util.GT) end,
		getter = function(row) return row.level end,
		cell_initializer = Aux.sheet.default_cell_initializor('RIGHT'),
	},
	{
		title = 'Owner',
		comparator = function(row1, row2) return Aux.util.compare(row1.owner, row2.owner, Aux.util.GT) end,
		getter = function(row) return row.owner end,
		cell_initializer = Aux.sheet.default_cell_initializor('LEFT'),
	},
	{
		title = 'Bid',
		comparator = function(row1, row2) return Aux.util.compare(row1.bid, row2.bid, Aux.util.GT) end,
		getter = function(row) return Aux.util.coins(row.bid) end,
		cell_initializer = Aux.sheet.default_cell_initializor('RIGHT'),
	},
	{
		title = 'Bid (Unit)',
		comparator = function(row1, row2) return Aux.util.compare(row1.bid_per_unit, row2.bid_per_unit, Aux.util.GT) end,
		getter = function(row) return Aux.util.coins(row.bid_per_unit) end,
		cell_initializer = Aux.sheet.default_cell_initializor('RIGHT'),
	},
	{
		title = 'Buyout',
		comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price, row2.buyout_price, Aux.util.GT) end,
		getter = function(row) return Aux.util.coins(row.buyout_price) end,
		cell_initializer = Aux.sheet.default_cell_initializor('RIGHT'),
	},
	{
		title = 'Buyout (Unit)',
		comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price_per_unit, row2.buyout_price_per_unit, Aux.util.GT) end,
		getter = function(row) return Aux.util.coins(row.buyout_price_per_unit) end,
		cell_initializer = Aux.sheet.default_cell_initializor('RIGHT'),
	},
	{
		title = '#',
		comparator = function(row1, row2) return Aux.util.compare(row1.stack_size, row2.stack_size, Aux.util.LT) end,
		getter = function(row) return row.stack_size end,
		cell_initializer = Aux.sheet.default_cell_initializor('RIGHT'),
	},
	{
		title = 'Left',
		comparator = function(row1, row2) return Aux.util.compare(row1.duration, row2.duration, Aux.util.GT) end,
		getter = function(row)
			if row.duration == 1 then
				return '30m'
			elseif row.duration == 2 then
				return '2h'			
			elseif row.duration == 3 then
				return '8h'
			elseif row.duration == 4 then
				return '24h'
			end
		end,
		cell_initializer = Aux.sheet.default_cell_initializor('CENTER'),
	},
}

local physical_columns = {
	{
		logical_columns = { logical_columns[QUANTITY] },
		logical_column = logical_columns[QUANTITY],
		width = 30
	},
	{
		logical_columns = { logical_columns[NAME] },
		logical_column = logical_columns[NAME],
		width = 180
	},
	{
		logical_columns = { logical_columns[LEVEL] },
		logical_column = logical_columns[LEVEL],
		width = 40
	},
	{
		logical_columns = { logical_columns[TIME_LEFT] },
		logical_column = logical_columns[TIME_LEFT],
		width = 50
	},
	{
		logical_columns = { logical_columns[OWNER] },
		logical_column = logical_columns[OWNER],
		width = 90
	},
	{
		logical_columns = { logical_columns[BID_UNIT], logical_columns[BUYOUT_UNIT] },
		logical_column = logical_columns[BUYOUT_UNIT],
		width = 100
	},
	{
		logical_columns = { logical_columns[BID], logical_columns[BUYOUT] },
		logical_column = logical_columns[BUYOUT],
		width = 100
	},
}

function Aux.list.on_load()
	Aux.list.initialize(this, physical_columns, logical_columns)
end

-------------------------------------------------------------------------------
-- Aux.util.compare two rows
-------------------------------------------------------------------------------

function Aux.sheet.create(frame, physical_columns)
	local sheet
	local name = (frame:GetName() or '')..'ScrollSheet'
	
	local id = 1
	while getglobal(name..id) do
		id = id + 1
	end
	name = name..id
	
	local parent_height = frame:GetHeight()
	local content = CreateFrame('Frame', name..'Content', frame)
	content:SetHeight(parent_height - 30)
	
	local panel = CreateFrame('ScrollFrame', nil, 'FauxScrol
	
	
local NUM_BUTTONS = 8
local BUTTON_HEIGHT = 20

local list = {} -- put contents of the scroll frame here, for example item names
local buttons = {}

local function update(self)
	local numItems = #list
	FauxScrollFrame_Update(self, numItems, NUM_BUTTONS, BUTTON_HEIGHT)
	local offset = FauxScrollFrame_GetOffset(self)
	for line = 1, NUM_BUTTONS do
		local lineplusoffset = line + offset
		local button = buttons[line]
		if lineplusoffset > numItems then
			button:Hide()
		else
			button:SetText(list[lineplusoffset])
			button:Show()
		end
	end
end

local scrollFrame = CreateFrame("ScrollFrame", "MyFirstNotReallyScrollFrame", UIParent, "FauxScrollFrameTemplate")
scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
	FauxScrollFrame_OnVerticalScroll(self, offset, BUTTON_HEIGHT, update)
end)

for i = 1, NUM_BUTTONS do
	local button = CreateFrame("Button", nil, scrollFrame:GetParent())
	if i == 1 then
		button:SetPoint("TOP", scrollFrame)
	else
		button:SetPoint("TOP", buttons[i - 1], "BOTTOM")
	end
	button:SetSize(96, BUTTON_HEIGHT)
	buttons[i] = button
end

<ScrollFrame name="$parentScrollFrame" inherits="FauxScrollFrameTemplate">
				<Anchors>
					<Anchor point="TOPLEFT">
						<Offset>
							<AbsDimension x="0" y="-28"/>
						</Offset>
					</Anchor>
					<Anchor point="BOTTOMRIGHT" relativePoint="BOTTOMRIGHT">
						<Offset>
							<AbsDimension x="0" y="0"/>
						</Offset>
					</Anchor>
				</Anchors>
				<Layers>
					<Layer level="ARTWORK">
						<Texture file="Interface\PaperDollInfoFrame\UI-Character-ScrollBar">
							<Size>
								<AbsDimension x="31" y="256"/>
							</Size>
							<Anchors>
								<Anchor point="TOPLEFT" relativePoint="TOPRIGHT">
									<Offset>
										<AbsDimension x="-2" y="5"/>
									</Offset>
								</Anchor>
							</Anchors>
							<TexCoords left="0" right="0.484375" top="0" bottom="1.0"/>
						</Texture>
						<Texture file="Interface\PaperDollInfoFrame\UI-Character-ScrollBar">
							<Size>
								<AbsDimension x="31" y="106"/>
							</Size>
							<Anchors>
								<Anchor point="BOTTOMLEFT" relativePoint="BOTTOMRIGHT">
									<Offset>
										<AbsDimension x="-2" y="-2"/>
									</Offset>
								</Anchor>
							</Anchors>
							<TexCoords left="0.515625" right="1.0" top="0" bottom="0.4140625"/>
						</Texture>
					</Layer>
				</Layers>
				<Scripts>
					<OnVerticalScroll>
						FauxScrollFrame_OnVerticalScroll(16, Aux.list.scroll_frame_update)
					</OnVerticalScroll>
				</Scripts>
			</ScrollFrame>
	
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
		button:SetHighLightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight')
		-- button:SetScript('OnMouseDown', function() end)
		
		local texture = content:CreateTexture(nil, 'ARTWORK')
		texture:SetTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight')
		texture:SetTexCoord(0.1, 0.8, 0, 1)
		texture:SetAllPoints(button)
		button.texture = texture 
		
		local sort_texture = button:CreateTexture(nil, 'ARTWORK')
		sort_texture:SetTexture('Interface\\Buttons\\UI-SortArrow')
		sort_texture:SetPoint('TOPRIGHT, button, 'TOPRIGHT', 0, 0)
		sort_texture:SetPoint('BOTTOM', button, 'BOTTOM', 0, 0)
		sort_texture:SetWidth(12)
		sort_texture:Hide()
		button.sort_texture = sort_texture
		
		local background = content:CreateTexture(nil, 'ARTWORK')
		background:SetTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight')
		background:SetTextCoord(0.2, 0.9, 0, 0.9)
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
			local cell = CreateFrame('Frame', nil, content)
			if row_index == 1 then
				cell:SetPoint('TOPLEFT', labels[i], 'BOTTOMLEFT', 0, 0)
				cell:SetPoint('TOPRIGHT', labels[i], 'BOTTOMRIGHT', 0, 0)
			else
				cell:SetPoint('TOPLEFT', rows[row_index-1][i], 'BOTTOMLEFT', 0, 0)
				cell:SetPoint('TOPRIGHT', rows[row_index-1][i], 'BOTTOMRIGHT', 0, 0)				
			end
			
			cell:SetHeight(14)
			
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
		panel = panel,
		labels = labels,
		rows = rows,
		column_count = getn(labels),
		physical_row_count = getn(rows),
		data = {},
		style = {},
		sort = {},
		logical_row_count = 0,
	}
	
	return sheet
end

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

function Aux.sheet.default_cell_initializer(alignment)
	return function(cell_frame)
		local text = cell_frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
		text:SetAllPoints(cell_frame)
		text:SetJustifyV('TOP')
		text:SetJustifyH(alignment)
		text:SetTextColor(0.8, 0.8, 0.8)
	end
end

-------------------------------------------------------------------------------
-- Initialize the list with the column information
-------------------------------------------------------------------------------
function Aux.list.initialize(frame, physical_columns, logical_columns)

	
	Aux.sheet.create(frame, physical_columns)
	--frame.lines = 19
	--frame.lineHeight = 16
	--frame.content = {}
	--frame.physical_columns = physical_columns
	--frame.logical_columns = logical_columns

	--frame.sort_order = {}
	--for i, logical_column in logical_columns do
		--if i ~= BUYOUT_UNIT and i ~= NAME then 
			--tinsert(frame.sort_order, { logical_column = logical_column, sort_ascending = true })
		--end
	--end
	--tinsert(frame.sort_order, 1, { logical_column = logical_columns[BUYOUT_UNIT], sort_ascending = true })
	--tinsert(frame.sort_order, 1, { logical_column = logical_columns[NAME], sort_ascending = true })
	
	--for i = 1, MAX_COLUMNS do
		--local button = getglobal(frame:GetName().."Column"..i.."Sort")
		--local dropdown = getglobal(frame:GetName().."Column"..i.."DropDown")
		--if (i <= table.getn(physical_columns)) then
			--local physical_column = physical_columns[i]
			--local logical_column = physical_column.logical_column
			--UIDropDownMenu_SetSelectedID(dropdown, Aux.util.index_of(logical_column, logical_columns))
			--getglobal(button:GetName().."Arrow"):Hide()
			--getglobal(button:GetName().."Text"):SetText(logical_column.title)
			--button:Show()
			--if (getn(physical_column.logical_columns) > 1) then
				--dropdown:Show();
			--else
				--dropdown:Hide();
			--end

			--Aux.list.set_column_width(frame, i, physical_column.width);
		--else
			--button:Hide()
			--dropdown:Hide()
		--end
	--end
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
			text:SetWidth(width - 3)
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
	
	for column_index = 1, table.getn(parent.physical_columns) do
		local arrow = getglobal(parent:GetName().."Column"..column_index.."SortArrow")
		local sort_info = parent.sort_order[1]
		local physical_column = parent.physical_columns[column_index]
		local logical_column = physical_column.logical_column
		
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
	end
	
	for line = 1, parent.lines do
		local item = getglobal(parent:GetName().."Item"..line)
		local row_index = line + FauxScrollFrame_GetOffset(frame)
				
		if row_index <= getn(content) then		
			for column_index = 1, MAX_COLUMNS do
				
				local item = getglobal(parent:GetName().."Item"..line.."Column"..column_index.."Item")
				if item then
					item:Hide()
				end

				local text = getglobal(parent:GetName().."Item"..line.."Column"..column_index)
				-- text:Hide() TODO
				text:SetText()
				
				if column_index <= table.getn(parent.physical_columns) then
					local physical_column = parent.physical_columns[column_index]
					local logical_column = physical_column.logical_column
					local value = logical_column.getter(content[row_index])
					
					if value then
						if item and logical_column.type == "ITEM" then
							item:Show()
							getglobal(item:GetName() .. 'IconTexture'):SetTexture(logical_column.texture(content[row_index]))
						end
						if text and (logical_column.type == "DATE" or logical_column.type == "NUMBER" or logical_column.type == "STRING" or logical_column.type == "ITEM") then
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
							-- if (logical_column.type == "NUMBER") then
								-- text:SetJustifyH("RIGHT")
							-- else
								-- text:SetJustifyH("LEFT")
							-- end
							text:Show()
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

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function Aux.list.dropdown_item_onclick()
	local logical_column_index = this:GetID()
	local physical_column_index = this.owner:GetID()
	local dropdown = this.owner
	local frame = dropdown:GetParent()
	if frame.physical_columns[physical_column_index].logical_column ~= frame.logical_columns[logical_column_index] then

		frame.physical_columns[physical_column_index].logical_column = frame.physical_columns[physical_column_index].logical_columns[logical_column_index]
		getglobal(frame:GetName().."Column"..physical_column_index.."SortText"):SetText(frame.physical_columns[physical_column_index].logical_column.title)

		Aux.util.merge_sort(frame.content, Aux.list.row_comparator(frame))

		UIDropDownMenu_SetSelectedID(dropdown, logical_column_index)
		Aux.list.scroll_frame_update(getglobal(frame:GetName().."ScrollFrame"))
	end
end


