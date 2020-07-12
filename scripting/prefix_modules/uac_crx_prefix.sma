#include <amxmodx>
#include <uac>

#include <chatmanager> // Download here https://github.com/OciXCrom/ChatManager

new bool:PlayerChecked[MAX_PLAYERS + 1];
new bool:PlayerUpdated[MAX_PLAYERS + 1];

public plugin_init() {
	register_plugin("[UAC] Prefix for Chat Manager by OciXCrom", UAC_VERSION_STR, "GM-X Team");
}

public client_putinserver(id) {
	PlayerUpdated[id] = false;
}

public UAC_Checking(const id) {
	PlayerChecked[id] = false;
}

public UAC_Checked(const id, const UAC_CheckResult:found) {
	PlayerChecked[id] = true;
	if (PlayerUpdated[id]) {
		setPrefix(id);
	}
}

public cm_on_player_data_updated(id) {
	PlayerUpdated[id] = true;
	if (PlayerChecked[id]) {
		setPrefix(id);
	}
}

setPrefix(const id) {
	new prefix[UAC_MAX_PREFIX_LENGTH];
	UAC_GetPrefix(prefix, charsmax(prefix));
	if (prefix[0] != EOS) {
		cm_set_user_prefix(id, fmt("[%s]", prefix));
	}
}
