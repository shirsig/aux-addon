local load_snapshot, update_snapshot, load_history, update_history

aux_store = {}

function get_auction_house_id()
	local realm = GetCVar('realmName')
	local zone = GetMinimapZoneText()
	local faction
	if zone == 'Gadgetzan' or zone == 'Everlook' or zone == 'Booty Bay' then
		faction = 'Neutral'
	else
		faction = UnitFactionGroup('player')
	end
	return realm..'|'..faction
end

function load_history()
    aux_store.history[history_key] = aux_history[history_key] or {}
    return aux_store.history[history_key]
end

function load_history()
    aux_store.history[history_key] = aux_history[history_key] or {}
    return aux_store.history[history_key]
end

function load_history()
    aux_store.history[history_key] = aux_history[history_key] or {}
    return aux_store.history[history_key]
end

function load_history()
    aux_store.history[history_key] = aux_history[history_key] or {}
    return aux_store.history[history_key]
end

Aux.store = {
	load_history = load_history,
	update_history = update_history,
	load_snapshot = load_snapshot,
	update_snapshot = update_snapshot,
}
