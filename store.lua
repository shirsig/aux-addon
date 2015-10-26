local version_outdated, on_load, load_snapshot, save_snapshot, load_history, save_history

aux_store = {}

function on_load()
	perform_migration(aux_store)
	aux_store.version = Aux.core.version
end

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
	local auction_house_id = get_auction_house_id()
    aux_store.datasets[auction_house_id] = aux_store.datasets[auction_house_id] or {}
    return aux_store.datasets[auction_house_id]
end

function save_history(history)
	local auction_house_id = get_auction_house_id()
    aux_store.datasets[auction_house_id] = aux_store.datasets[auction_house_id] or {}
    return aux_store.datasets[auction_house_id]
end

function load_shapshot()
	local auction_house_id = get_auction_house_id()
    aux_store.datasets[auction_house_id] = aux_store.datasets[auction_house_id] or {}
    return aux_store.datasets[auction_house_id]
end

function save_snapshot(snapshot)
	local auction_house_id = get_auction_house_id()
    aux_store.datasets[auction_house_id] = aux_store.datasets[auction_house_id] or {}
    return aux_store.datasets[auction_house_id]
end

Aux.store = {
	load_history = load_history,
	update_history = save_history,
	load_snapshot = load_snapshot,
	update_snapshot = save_snapshot,
}
