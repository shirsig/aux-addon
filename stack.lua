Aux.stack = {}

local controller = (function()
	local controller
	return function()
		controller = controller or Aux.control.controller()
		return controller
	end
end)()

local state

local inventory, item_slots, find_empty_slot, locked, same_slot, move_item, item_name, stack_size, stop, process

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

function find_charges_item_slot(name, charges)
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

function move_item(from_slot, to_slot, amount, k)
	local size_before = stack_size(to_slot)
		
	amount = min(max_stack(from_slot) - stack_size(to_slot), amount)
	
	ClearCursor()
	SplitContainerItem(from_slot.bag, from_slot.bag_slot, amount)
	PickupContainerItem(to_slot.bag, to_slot.bag_slot)
	
	return controller().wait(function() return stack_size(to_slot) == size_before + amount end, k)
end

function item_name(slot)
	local container_item_info = Aux.info.container_item(slot.bag, slot.bag_slot)
	return container_item_info and container_item_info.name
end

function item_id(slot)
	local hyperlink = GetContainerItemLink(slot.bag, slot.bag_slot)
	if hyperlink then
		local _, _, id_string = strfind(hyperlink, "^.-:(%d*).*")
		return tonumber(id_string)
	end		
end

function stack_size(slot)
	local _, item_count = GetContainerItemInfo(slot.bag, slot.bag_slot)
	return item_count or 0
end

function item_charges(slot)
	return Aux.info.container_item(slot.bag, slot.bag_slot).charges
end

function process()

	if stack_size(state.target_slot) > state.target_size then
		local empty_slot = find_empty_slot()
		
		if empty_slot then
			return move_item(
				state.target_slot,
				empty_slot,
				stack_size(state.target_slot) - state.target_size,
				function()
					return process()
			end)
		else
			local next_slot = state.other_slots()
			if next_slot then
				return move_item(
					state.target_slot,
					next_slot,
					stack_size(state.target_slot) - state.target_size,
					function()
						return process()
				end)
			end
		end
	elseif stack_size(state.target_slot) < state.target_size then
		local next_slot = state.other_slots()
		if next_slot then
			return move_item(
				next_slot,
				state.target_slot,
				state.target_size - stack_size(state.target_slot),
				function()
					return process()
			end)
		end
	end
		
	return stop()
end

function max_stack(slot)
	local _, _, _, _, _, _, max_stack = GetItemInfo(item_id(slot))
	return max_stack
end

function Aux.stack.stop(k)
	Aux.control.on_next_update(function()
		stop()
		
		if k then
			return k()
		end
	end)
end

function stop()
	controller().reset()
	if state then
		local slot
		if state.target_slot and (stack_size(state.target_slot) == state.target_size or item_charges(state.target_slot) == state.target_size) then
			slot = state.target_slot
		end
		local callback = state.callback
		
		state = nil
		
		if callback then
			callback(slot)
		end
	end
end

function Aux.stack.start(name, size, callback)
	Aux.control.on_next_update(function()
		stop()
		
		local slots = item_slots(name)
		local target_slot = slots()
		
		state = {
			target_size = size,
			target_slot = target_slot,
			other_slots = slots,
			callback = callback,
		}
		
		if not target_slot then
			return stop()
		elseif item_charges(target_slot) then
			state.target_slot = find_charges_item_slot(name, size)
			return stop()
		else
			return process()
		end
	end)
end