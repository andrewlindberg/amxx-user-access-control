#include <amxmodx>
#include <uac>

#tryinclude <chatmanager> // Download here https://dev-cs.ru/resources/112/
#if !defined _chatmanager_included
native cm_set_player_message(const new_message[]);
native cm_set_prefix(const player, const prefix[]);
native cm_get_prefix(const player, dest[], const length);
native cm_reset_prefix(const player);
#endif

enum {
	PREFIX_NONE,
	PREFIX_CHANGE,
	PREFIX_CHANGED,
	PREFIX_RESET
}

new Prefix[MAX_PLAYERS+1];

public plugin_init() {
	register_plugin("[UAC] CM Prefix", UAC_VERSION_STR, "GM-X Team");
}

public UAC_Checked(const id, const UAC_CheckResult:found) {
	if (found == UAC_CHECK_SUCCESS) {
		Prefix[id] = PREFIX_CHANGE;
	} else if (Prefix[id] == PREFIX_CHANGED) {
		Prefix[id] = PREFIX_RESET;
	} else {
		Prefix[id] = PREFIX_NONE;
	}

	if (is_user_connected(id)) {
		setPrefix(id);
	}
}

public client_putinserver(id) {
	if (Prefix[id] == PREFIX_CHANGE) {
		UAC_GetPlayerPrivilege(id);
		setPrefix(id);
	}
}

setPrefix(const id) {
	switch (Prefix[id]) {
		case PREFIX_CHANGE: {
			new prefix[UAC_MAX_PREFIX_LENGTH];
			UAC_GetPrefix(prefix, charsmax(prefix));
			if (prefix[0] != EOS) {
				cm_set_prefix(id, fmt("^4[^3%s^4] ", prefix));
				Prefix[id] = PREFIX_CHANGED;
			}
		}

		case PREFIX_RESET: {
			cm_reset_prefix(id);
			Prefix[id] = PREFIX_NONE;
		}
	}
	
}
