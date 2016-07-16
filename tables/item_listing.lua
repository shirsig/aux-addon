local m, public, private = Aux.module'item_listing'

local ROW_HEIGHT = 38

function public.render(item_listing)

	FauxScrollFrame_Update(item_listing.scroll_frame, getn(item_listing.item_records), getn(item_listing.rows), ROW_HEIGHT)
	item_listing.scroll_frame:Show()
	local offset = FauxScrollFrame_GetOffset(item_listing.scroll_frame)

	local rows = item_listing.rows

	for i, row in ipairs(rows) do
		local item_record = item_listing.item_records[i + offset]

        if item_record then
			row.item_record = item_record
			if item_listing.selected and item_listing.selected(item_record) then
				row.highlight:Show()
			elseif not row.mouse_over then
				row.highlight:Hide()
			end
			getglobal(row.item:GetName()..'IconTexture'):SetTexture(item_record.texture)
			getglobal(row.item:GetName()..'Name'):SetText('['..item_record.name..']')
			local color = ITEM_QUALITY_COLORS[item_record.quality]
			getglobal(row.item:GetName()..'Name'):SetTextColor(color.r, color.g, color.b)
			if item_record.aux_quantity > 1 then
				getglobal(row.item:GetName()..'Count'):SetText(item_record.aux_quantity)
			else
				getglobal(row.item:GetName()..'Count'):SetText()
			end
            row:Show()
        else
            row:Hide()
        end
	end
end

function public.create(parent, on_click, on_enter, on_leave, selected)
	local name = 'aux_item_list'

	local id = 1
	while getglobal(name..id) do
		id = id + 1
	end
	name = name..id

	local content = CreateFrame('Frame', nil, parent)
	content:SetPoint('TOPLEFT', 0, -51)
	content:SetPoint('BOTTOMRIGHT', -15, 0)

	local scroll_frame = CreateFrame('ScrollFrame', name..'ScrollFrame', parent, 'FauxScrollFrameTemplate')
	scroll_frame:SetScript('OnVerticalScroll', function(self, offset)
		FauxScrollFrame_OnVerticalScroll(ROW_HEIGHT, function() m.render(this.item_listing) end)
	end)
	scroll_frame:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 15)
	scroll_frame:SetPoint('BOTTOMRIGHT', content, 'BOTTOMRIGHT', -4, -15)

	local scrollBar = getglobal(scroll_frame:GetName()..'ScrollBar')
	scrollBar:SetWidth(12)
	local thumbTex = scrollBar:GetThumbTexture()
	thumbTex:SetPoint('CENTER', 0, 0)
	thumbTex:SetTexture(unpack(Aux.gui.config.content_color))
	thumbTex:SetHeight(50)
	thumbTex:SetWidth(12)
	getglobal(scrollBar:GetName()..'ScrollUpButton'):Hide()
	getglobal(scrollBar:GetName()..'ScrollDownButton'):Hide()

	local rows = {}
	local row_index = 1
	local max_height = content:GetHeight()
	local total_height = 0
	while total_height + ROW_HEIGHT < max_height do
			local row = CreateFrame('Button', nil, content)
			row:SetHeight(ROW_HEIGHT)
			row:SetWidth(193)
			row:SetPoint('TOPLEFT', content, 0, -((row_index-1) * ROW_HEIGHT))
			row:SetScript('OnClick', on_click)
			row:SetScript('OnEnter', function()
				row.highlight:Show()
				on_enter()
			end)
			row:SetScript('OnLeave', function()
				if not selected(row.item_record) then
					row.highlight:Hide()
				end
				on_leave()
			end)

			local item = CreateFrame('Frame', name..'_item'..row_index, row, 'AuxItemTemplate')
			row.item = item
			item:SetPoint('CENTER', 4, 0)
			row:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
			
			local highlight = row:CreateTexture()
			highlight:SetAllPoints(item)
			highlight:Hide()
			highlight:SetTexture(1, .9, .9, .1)
			row.highlight = highlight

			rows[row_index] = row
			row_index = row_index + 1
			total_height = total_height + ROW_HEIGHT
	end
	
	local item_listing = {
		selected = selected,
		scroll_frame = scroll_frame,
		rows = rows,
	}
	scroll_frame.item_listing = item_listing
	
	return item_listing
end

function public.populate(item_listing, item_records)
	item_listing.item_records = item_records
	m.render(item_listing)
end
