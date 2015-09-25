Aux.stack = {
	orig = {},
}

local state

local DELAY = 1

local inventory, item_slots, find_empty_slot, locked, same_slot, move_item, item_name, stack_size

-- returns iterator for inventory slots
function inventory()
	local inventory = {}
	for bag = 0, 4 do
		if GetBagName(bag) then
			for bag_slot = 1, GetContainerNumSlots(bag) do
				tinsert(inventory, { bag = bag, bag_slot = bag_slot })
			end
		end
	end
	
	local i = 0
	local n = getn(inventory)
	return function()
		i = i + 1
		if i <= n then
			return inventory[i]
		end
	end
end

function item_slots(name)
	local slots = inventory()
	return function()
		repeat
			slot = slots()
		until slot == nil or item_name(slot) == name
		return slot
	end
end

function find_empty_slot()
	for slot in inventory() do
		if not GetContainerItemInfo(slot.bag, slot.bag_slot) then
			return slot
		end
	end
end

function find_charge_item_slot(name, charges)
	for slot in item_slots(name) do
		if item_charges(slot) == charges then
			return slot
		end
	end
end

function locked(slot)
	local _, _, locked = GetContainerItemInfo(slog.bag, slot.bag_slot)
	return locked
end

function same_slot(slot1, slot2)
	return slot1.bag == slot2.bag and slot1.bag_slot == slot2.bag_slot
end

function move_item(from_slot, to_slot, amount)
	if stack_size(to_slot) < max_stack(from_slot) then
		amount = min(max_stack(from_slot) - stack_size(to_slot), amount)
		
		state.processing = 3

		ClearCursor()
		Aux.stack.orig.SplitContainerItem(from_slot.bag, from_slot.bag_slot, amount)
		Aux.stack.orig.PickupContainerItem(to_slot.bag, to_slot.bag_slot)
		ClearCursor()
	end
end

function item_name(slot)
	local itemLink = GetContainerItemLink(slot.bag, slot.bag_slot)
	if itemLink then
		return string.gsub(itemLink, "^.-%[(.*)%].*", "%1")
	end		
end

function item_id(slot)
	local itemLink = GetContainerItemLink(slot.bag, slot.bag_slot)
	if itemLink then
		local id_string = string.gsub(itemLink, "^.-:(%d*).*", "%1")
		return tonumber(id_string)
	end		
end

function stack_size(slot)
	local _, item_count = GetContainerItemInfo(slot.bag, slot.bag_slot)
	return item_count or 0
end

function item_charges(slot)
	Aux_Scan_ClearTooltip()
	AuxScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	AuxScanTooltip:SetBagItem(slot.bag, slot.bag_slot)
	AuxScanTooltip:Show()
	local tooltip = Aux_Scan_ExtractTooltip()
	return Aux_Scan_ItemCharges(tooltip)
end

function Aux.stack.onupdate()
	if state and state.processing <= 0 then
		local next_slot = state.other_slots()
		local empty_slot = find_empty_slot()

		if next_slot then
			if stack_size(state.target_slot) < state.target_size then
				move_item(
					next_slot,
					state.target_slot,
					state.target_size - stack_size(state.target_slot)
				)
				return
			elseif stack_size(state.target_slot) > state.target_size then
				move_item(
					state.target_slot,
					next_slot,
					stack_size(state.target_slot) - state.target_size
				)
				return
			end
		elseif empty_slot and stack_size(state.target_slot) > state.target_size then
			move_item(
				state.target_slot,
				empty_slot,
				stack_size(state.target_slot) - state.target_size
			)
			return
		end
		
		Aux.stack.stop()
	end
end

function max_stack(slot)
	local _, _, _, _, _, _, item_stack_count = GetItemInfo(item_id(slot))
	return item_stack_count
end

function Aux.stack.item_lock_changed()
	if state then
		state.processing = state.processing - 1
	end
end

function Aux.stack.stop()
	if state then
		local slot
		if state.target_slot and (stack_size(state.target_slot) == state.target_size or item_charges(state.target_slot) == state.target_size) then
			slot = state.target_slot
		end
		local callback = state.callback
		
		state = nil
		PickupContainerItem = Aux.stack.orig.PickupContainerItem
		SplitContainerItem = Aux.stack.orig.SplitContainerItem
		
		if callback then
			callback(slot)
		end
	end
end

function Aux.stack.start(name, size, callback)
	Aux.stack.stop()
	
	PickupContainerItem = function() end
	SplitContainerItem = function() end
	
	local slots = item_slots(name)
	local target_slot = slots()
	
	state = {
		target_size = size,
		target_slot = target_slot,
		other_slots = slots,
		callback = callback,
		processing = 0,
	}
	
	if not target_slot then
		Aux.stack.stop()
	elseif item_charges(target_slot) then
		state.target_slot = find_charges_item(name, size)
		Aux.stack.stop()
	end
end