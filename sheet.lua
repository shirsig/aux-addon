local private, public = {}, {}
Aux.sheet = public

Aux.list = {}

MoneyTypeInfo['AUX_LIST'] = {
	UpdateFunc = function()
		return this.staticMoney
	end,
	collapse = 1,
	fixedWidth = 1,
	showSmallerCoins = 1,
}

function public.render(sheet)
	
	for i, column in ipairs(sheet.columns) do
		local sort_info = sheet.sort_order[1]

		if sort_info and sort_info.column == i then
			if sort_info.order == 'ascending' then
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
	local hSize = getn(sheet.columns)

	local rows = sheet.rows
	local data = sheet.data

	for i, row in ipairs(rows) do
		local direction, rowR, rowG, rowB, rowA1, rowA2 = 'Horizontal', 1, 1, 1, 0, 0 --row level coloring used for gradients
		local datum = data[i + offset]

        if datum then
            if sheet.row_setter then
                sheet.row_setter(row, datum)
            end
            row:Show()
        else
            row:Hide()
        end
		for j, column in sheet.columns do
			local cell = row.cells[j]
			if datum then
                column.cell_setter(cell, datum)
				cell:Show()
			else
				cell:Hide()
			end
		end
		rows[i].color_texture:SetGradientAlpha(direction, rowR, rowG, rowB, rowA1, rowR, rowG, rowB, rowA2)--row color to apply
	end
end

function public.create(params)
	local sheet
	local name = (params.frame:GetName() or '')..'ScrollSheet'
	
	local id = 1
	while getglobal(name..id) do
		id = id + 1
	end
	name = name..id

	local scroll_frame = CreateFrame('ScrollFrame', name..'ScrollFrame', params.frame, 'FauxScrollFrameTemplate')

	local scrollbar = getglobal(scroll_frame:GetName()..'ScrollBar')
	scrollbar:SetPoint('TOPLEFT', scroll_frame, 'TOPRIGHT', 6, -4)
	scrollbar:SetPoint('BOTTOMLEFT', scroll_frame, 'BOTTOMRIGHT', 6, 4)
	local thumbTex = scrollbar:GetThumbTexture()
	thumbTex:SetPoint('CENTER', 0, 0)
	thumbTex:SetTexture(42/255, 42/255, 42/255, 1)
	thumbTex:SetHeight(params.frame:GetHeight() * .4)
	thumbTex:SetWidth(scrollbar:GetWidth())
	local scrollbg = scrollbar:CreateTexture(nil, 'BACKGROUND')
	scrollbg:SetAllPoints(scrollbar)
	scrollbg:SetTexture(24/255, 24/255, 24/255, 1)
	local scrollbar = getglobal(scroll_frame:GetName()..'ScrollBarScrollUpButton'):Hide()
	local scrollbar = getglobal(scroll_frame:GetName()..'ScrollBarScrollDownButton'):Hide()

	scroll_frame:SetScript('OnVerticalScroll', function()
		FauxScrollFrame_OnVerticalScroll(16, function() public.render(this.sheet) end)
	end)
	scroll_frame:SetPoint('TOPLEFT', params.frame, 'TOPLEFT', 5, -10)
	scroll_frame:SetPoint('BOTTOMRIGHT', params.frame, 'BOTTOMRIGHT', 5, 19)
	
	local parent_height = params.frame:GetHeight()
	local content = CreateFrame('Frame', name..'Content', params.frame)
	content:SetHeight(parent_height - 30)
	content:SetPoint('TOPLEFT', scroll_frame, 'TOPLEFT', 5, 0)

	local total_width = 0
	
	local labels = {}
	for i = 1,getn(params.columns) do
		local button = CreateFrame('Button', nil, content)
		if i == 1 then
			button:SetPoint('TOPLEFT', content, 'TOPLEFT', 5, 0)
			total_width = total_width + 5
		else
			button:SetPoint('TOPLEFT', content, 'TOPLEFT', total_width + 3, 0)
			total_width = total_width + 3
		end
		local label = content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
		label:SetText(params.columns[i].title)
		local column_width = params.columns[i].width or 30

		total_width = total_width + column_width
		button:SetWidth(column_width)
		button:SetHeight(16)
		button:SetID(i)
		button:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight')
		button:SetScript("OnMouseDown", function() Aux.sheet.sort(sheet, this:GetID()) end)
		button:RegisterForClicks("LeftButtonDown", "RightButtonDown")

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
    params.frame:SetWidth(total_width)
	
	local rows = {}
	local row_index = 1
	local max_height = content:GetHeight()
	local total_height = 16
	while total_height + 14 < max_height do
		if getn(params.columns) > 0 then
			local row = CreateFrame('Button', nil, content)
			row:SetPoint('TOPLEFT', labels[1], 'BOTTOMLEFT', 0, -((row_index-1) * 14))
			row:SetPoint('TOPRIGHT', labels[getn(params.columns)], 'BOTTOMRIGHT', 0, -((row_index-1) * 14))
			row:RegisterForClicks("LeftButtonDown", "RightButtonDown")
			row:SetHeight(14)
			
			local row_idx = row_index
			row:SetScript('OnClick', function() if sheet.on_row_click then sheet.on_row_click(sheet, row_idx) end end)
			row:SetScript('OnEnter', function() if sheet.on_row_enter then sheet.on_row_enter(sheet, row_idx) end end)
			row:SetScript('OnLeave', function() if sheet.on_row_leave then sheet.on_row_leave(sheet, row_idx) end end)
            row:SetScript('OnUpdate', function() if sheet.on_row_update then sheet.on_row_update(sheet, row_idx) end end)
			
			row.cells = {}			
			for i = 1,getn(params.columns) do
				local cell = CreateFrame('Button', nil, content)
				cell:SetPoint('TOPLEFT', labels[i], 'BOTTOMLEFT', 0, -((row_index-1) * 14))
				cell:SetPoint('TOPRIGHT', labels[i], 'BOTTOMRIGHT', 0, -((row_index-1) * 14))
				
				cell:SetHeight(14)

                params.columns[i].cell_initializer(cell)
				
				row.cells[i] = cell
			end
			
			local color_texture = row:CreateTexture()
			color_texture:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0)
			color_texture:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 0, 1)
			color_texture:SetTexture(1, 1, 1)
			row.color_texture = color_texture
			
			local highlight = row:CreateTexture()
			highlight:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0)
			highlight:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 0, 1)
			highlight:SetAlpha(0)
			highlight:SetTexture(0.8, 0.6, 0)
			row.highlight = highlight
			
			rows[row_index] = row
			row_index = row_index + 1
			total_height = total_height + 14
		end
	end
	
	content:SetWidth(total_width)
	
	sheet = {
		name = name,
		content = content,
		scroll_frame = scroll_frame,
		labels = labels,
		rows = rows,
        columns = params.columns,
		data = {},
		sort_order = params.sort_order,
        row_setter = params.row_setter,
		on_row_click = params.on_row_click,
		on_row_enter = params.on_row_enter,
		on_row_leave = params.on_row_leave,
        on_row_update = params.on_row_update,
	}
	scroll_frame.sheet = sheet
	
	return sheet
end

function private.row_comparator(sheet)
	return function(row1, row2)
		for _, sort_info in ipairs(sheet.sort_order) do
			local column = sheet.columns[sort_info.column]
			if column.comparator then
				local ordering = column.comparator(row1, row2)
				if ordering ~= Aux.util.EQ then
					return sort_info.order == 'ascending' and ordering or Aux.util.invert_order(ordering)
				end
			end
		end
		return Aux.util.EQ
	end
end

function public.default_cell_initializer(alignment)
	return function(cell)
		local text = cell:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
		text:SetAllPoints(cell)
		text:SetJustifyV('TOP')
		text:SetJustifyH(alignment)
		text:SetTextColor(0.8, 0.8, 0.8)
		cell.text = text
	end
end

function public.populate(sheet, data)
	sheet.data = data

	Aux.util.merge_sort(sheet.data, private.row_comparator(sheet))

	public.render(sheet)
end

function Aux.sheet.sort(sheet, column_index)
			
	if sheet.sort_order[1] and sheet.sort_order[1].column == column_index then
		sheet.sort_order[1].order = sheet.sort_order[1].order == 'ascending' and 'descending' or 'ascending'
	else
        sheet.sort_order = Aux.util.filter(sheet.sort_order, function(sort_info) return not sort_info.column == column_index end)
        tinsert(sheet.sort_order, 1, {column=column_index, order = 'ascending'})
	end
	
	Aux.util.merge_sort(sheet.data, private.row_comparator(sheet))

	public.render(sheet)
end
