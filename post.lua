local target_size
local slot


-- iterator for inventory
function inventory()
	local inventory = {}
	for bag = 0, 4 do
		if GetBagName(bag) then
			for bagSlot = 1, GetContainerNumSlots(bag) do
				tinsert(inventory, { bag = bag, bagSlot = bagSlot })
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

function findEmptySlot()
	for slot in inventory() do
		if not GetContainerItemInfo(slot.bag, slot.bagSlot) then
			return slot
		end
	end
end

function findItem(name)
	local slots = {}
	for slot in inventory()	do	
		if itemName(slot) == name then
			tinsert(slots, slot)
		end
	end
	return slots
end

function sameSlot(slot1, slot2)
	return slot1.bag == slot2.bag and slot1.bagSlot == slot2.bagSlot
end

function moveItem(fromSlot, toSlot, amount)
	ClearCursor()
	SplitContainerItem(fromSlot.bag, fromSlot.bagSlot, amount)
	PickupContainerItem(toSlot.bag, toSlot.bagSlot)
	ClearCursor()
end

function itemName(slot)
	local itemLink = GetContainerItemLink(slot.bag, slot.bagSlot)
	if itemLink then
		return string.gsub(itemLink, "^.-%[(.*)%].*", "%1")
	end		
end

function stackSize(slot)
	local _, itemCount = GetContainerItemInfo(slot.bag, slot.bagSlot)
	return itemCount
end

function postAuction(slot)
	ClearCursor()
	pickupContainerItem(slot.bag, slot.bagSlot)
	ClickAuctionSellItemButton()
	ClearCursor()
	Aux.orig.AuctionsCreateAuctionButton_OnClick()
	-- StartAuction(request.bid, request.buyout, request.duration);
end

function createStack(name, size)
	ClearCursor()
	ClickAuctionSellItemButton()
	ClearCursor()
	
	local slots = findItem(name)
	local stackSlot = slots[1]
	tremove(slots, 1)

	for _, slot in ipairs(slots) do
		if stackSize(stackSlot) < size then
			moveItem(slot, stackSlot, size - stackSize(stackSlot))
		elseif stackSize(stackSlot) > size then
			moveItem(stackSlot, slot, stackSize(stackSlot) - size)
		else
			return stackSlot
		end
	end

	if stackSize(stackSlot) > size then
		local emptySlot = findEmptySlot()
		Aux_Log(stackSize(stackSlot) .. ' : ' .. emptySlot.bag .. ' ' .. emptySlot.bagSlot)
		moveItem(stackSlot, emptySlot, stackSize(stackSlot) - size)
		Aux_Log(stackSize(stackSlot) .. ' : ' .. emptySlot.bag .. ' ' .. emptySlot.bagSlot)
		if stackSize(stackSlot) == size then
			return stackSlot
		end
	end
end

-- /script createStack('Dried King Bolete', 3)