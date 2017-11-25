module 'aux.gui.item_listing'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local gui = require 'aux.gui'

local ROW_HEIGHT = 39

function M:render()

	if getn(self.item_records or T.empty) > getn(self.rows) then
		self.content_frame:SetPoint('BOTTOMRIGHT', -15, 0)
	else
		self.content_frame:SetPoint('BOTTOMRIGHT', 0, 0)
	end

	FauxScrollFrame_Update(self.scroll_frame, getn(self.item_records), getn(self.rows), ROW_HEIGHT)
	local offset = FauxScrollFrame_GetOffset(self.scroll_frame)

	local rows = self.rows

	for i, row in rows do
		local item_record = self.item_records[i + offset]

        if item_record then
			row.item_record = item_record
			if self.selected and self.selected(item_record) or row.mouseover then
				row.highlight:Show()
			elseif not row.mouse_over then
				row.highlight:Hide()
			end
			row.item.texture:SetTexture(item_record.texture)
			row.item.name:SetText('[' .. item_record.name .. ']')
			local color = ITEM_QUALITY_COLORS[item_record.quality]
			row.item.name:SetTextColor(color.r, color.g, color.b)
			if item_record.aux_quantity > 1 then
				row.item.count:SetText(item_record.aux_quantity)
			else
				row.item.count:SetText()
			end
            row:Show()
        else
            row:Hide()
        end
	end
end

function M.new(parent, on_click, selected)
	local content_frame = CreateFrame('Frame', nil, parent)
	content_frame:SetAllPoints()

	local scroll_frame = CreateFrame('ScrollFrame', gui.unique_name(), parent, 'FauxScrollFrameTemplate')
	scroll_frame:SetScript('OnVerticalScroll', function()
		FauxScrollFrame_OnVerticalScroll(ROW_HEIGHT, function() render(this.item_listing) end)
	end)
	scroll_frame:SetPoint('TOPLEFT', content_frame, 'TOPLEFT', 0, 29)
	scroll_frame:SetPoint('BOTTOMRIGHT', content_frame, 'BOTTOMRIGHT', 0, 0)

	local scroll_bar = _G[scroll_frame:GetName() .. 'ScrollBar']
	scroll_bar:ClearAllPoints()
	scroll_bar:SetPoint('TOPRIGHT', parent, -4, 2)
	scroll_bar:SetPoint('BOTTOMRIGHT', parent, -4, 4)
	scroll_bar:SetWidth(10)
	local thumbTex = scroll_bar:GetThumbTexture()
	thumbTex:SetPoint('CENTER', 0, 0)
	thumbTex:SetTexture(aux.color.content.background())
	thumbTex:SetHeight(150)
	thumbTex:SetWidth(scroll_bar:GetWidth())
	_G[scroll_bar:GetName() .. 'ScrollUpButton']:Hide()
	_G[scroll_bar:GetName() .. 'ScrollDownButton']:Hide()

	local rows = T.acquire()
	local row_index = 1
	local max_height = content_frame:GetHeight()
	local total_height = 0
	while total_height + ROW_HEIGHT < max_height do
		local row = CreateFrame('Frame', nil, content_frame)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint('TOPLEFT', content_frame, 0, -((row_index - 1) * ROW_HEIGHT))
		row:SetPoint('TOPRIGHT', content_frame, 0, -((row_index - 1) * ROW_HEIGHT))
		row:EnableMouse(true)
		row:SetScript('OnMouseUp', on_click)
		row:SetScript('OnEnter', function()
			row.mouseover = true
			row.highlight:Show()
		end)
		row:SetScript('OnLeave', function()
			row.mouseover = false
			if not selected(row.item_record) then
				row.highlight:Hide()
			end
		end)

		row.item = gui.item(row)
		row.item:SetScale(.9)
		row.item:SetPoint('LEFT', 2.5, 0)
		row.item:SetPoint('RIGHT', -2.5, 0)
		row.item.button:SetScript('OnEnter', function()
			info.set_tooltip(row.item_record.itemstring, this, 'ANCHOR_RIGHT')
		end)
		row.item.button:SetScript('OnLeave', function() GameTooltip:Hide() end)

		local highlight = row:CreateTexture()
		highlight:SetAllPoints(row)
		highlight:Hide()
		highlight:SetTexture(1, .9, 0, .4)
		row.highlight = highlight

		rows[row_index] = row
		row_index = row_index + 1
		total_height = total_height + ROW_HEIGHT
	end
	
	local item_listing = {
		selected = selected,
		content_frame = content_frame,
		scroll_frame = scroll_frame,
		rows = rows,
	}
	scroll_frame.item_listing = item_listing
	
	return item_listing
end

function M.populate(item_listing, item_records)
	item_listing.item_records = item_records
	render(item_listing)
end
