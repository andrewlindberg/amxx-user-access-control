#include <amxmodx>
#include <uac>

#include <chatmanager>

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
			cm_set_prefix(id, fmt("^4[^3%s^4] ", prefix));
			Prefix[id] = PREFIX_CHANGED;
		}

		case PREFIX_RESET: {
			cm_reset_prefix(id);
			Prefix[id] = PREFIX_NONE;
		}
	}
	
}
