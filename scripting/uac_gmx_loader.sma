#include <amxmodx>
#include <grip>
#include <uac>
#include <gmx>
#include <gmx_cache>

new bool:Loaded = false;
new bool:GMXLoaded = false, bool:UACLoading = false;

enum {
	GMX_REQ_STATUS_ERROR = 0,
	GMX_REQ_STATUS_OK = 1
};

enum AUTH_TYPE {
	AUTH_TYPE_STEAM,
	AUTH_TYPE_STEAM_AND_PASS,
	AUTH_TYPE_NICK_AND_PASS,
	AUTH_TYPE_STEAM_AND_HASH,
	AUTH_TYPE_NICK_AND_HASH
};

enum _:GroupInfo {
	GroupId,
	GroupTitle[UAC_GROUP_MAX_TITLE_LENGTH],
	GroupFlags,
	GroupPriority,
	GroupPrefix[UAC_MAX_PREFIX_LENGTH]
}

new Array:Groups = Invalid_Array, GroupsNum, Group[GroupInfo];

public plugin_init() {
	register_plugin("[UAC] GM-X Loader", UAC_VERSION_STR, "GM-X Team");
	GMX_RegisterCommand("group_changed", "OnReload");
	GMX_RegisterCommand("group_removed", "OnReload");
	GMX_RegisterCommand("privilege_changed", "OnReload");
	GMX_RegisterCommand("privilege_removed", "OnReload");
}

public GMX_CfgLoaded() {
	if (GMXLoaded) {
		return;
	}
	GMXLoaded = true;
	if (!UACLoading) {
		return;
	}

	GMX_MakeRequest("server/privileges", Invalid_GripJSONValue, "OnResponse");
	UACLoading = false;
}

public UAC_Loading() {
	UAC_StartLoad();
	UACLoading = true;

	new bool:needRequest = true, GripJSONValue:data;
	if (!Loaded && GMX_CacheLoad("privileges", data)) {
		needRequest = !parseData(data);
		grip_destroy_json_value(data);
		Loaded = true;
	}

	if (!needRequest) {
		UAC_FinishLoad();
	} else if (GMXLoaded) {
		GMX_MakeRequest("server/privileges", Invalid_GripJSONValue, "OnResponse");
	} else {
		UACLoading = true;
	}
}

public OnResponse(const GmxResponseStatus:status, const GripJSONValue:data) {
	if (status != GmxResponseStatusOk) {
		UAC_FinishLoad();
		return;
	}

	if (!data || grip_json_get_type(data) != GripJSONObject) {
		UAC_FinishLoad();
		return;
	}

	parseData(data);
	GMX_CacheSave("privileges", data)
	UAC_FinishLoad();
}

public OnReload() {
	UAC_Reload();
}

bool:parseData(const GripJSONValue:data) {
	if (grip_json_get_type(data) != GripJSONObject) {
		return false;
	}

	new GripJSONValue:tmp;
	tmp = grip_json_object_get_value(data, "groups");
	parseGroups(tmp);
	grip_destroy_json_value(tmp);

	tmp = grip_json_object_get_value(data, "privileges");
	parsePrivileges(tmp);
	grip_destroy_json_value(tmp);
	return true;
}

parseGroups(const GripJSONValue:data) {
	if (Groups == Invalid_Array) {
		Groups = ArrayCreate(GroupInfo, 1);
	} else {
		ArrayClear(Groups);
	}
	for (new i = 0, n = grip_json_array_get_count(data), GripJSONValue:tmp; i < n; i++) {
		tmp = grip_json_array_get_value(data, i);
		if (grip_json_get_type(tmp) == GripJSONObject) {
			arrayset(Group, 0, sizeof Group);
			Group[GroupId] = grip_json_object_get_number(tmp, "id");
			grip_json_object_get_string(tmp, "title", Group[GroupTitle], charsmax(Group[GroupTitle]));
			Group[GroupFlags] = grip_json_object_get_number(tmp, "flags");
			Group[GroupPriority] = grip_json_object_get_number(tmp, "priority");

			new GripJSONValue:prefix = grip_json_object_get_value(tmp, "prefix");
			if (grip_json_get_type(prefix) != GripJSONNull) {
				grip_json_get_string(prefix, Group[GroupPrefix], charsmax(Group[GroupPrefix]));
			}
			grip_destroy_json_value(prefix);
			ArrayPushArray(Groups, Group, sizeof Group);
		}
		grip_destroy_json_value(tmp);
	}
	GroupsNum = ArraySize(Groups);
}

parsePrivileges(const GripJSONValue:data) {
	new id, auth[MAX_AUTHID_LENGTH], password[UAC_MAX_PASSWORD_LENGTH], access, flags, expired, prefix[UAC_MAX_PREFIX_LENGTH], options, authTypeStr[32];
	for (new i = 0, n = grip_json_array_get_count(data), GripJSONValue:tmp, GripJSONValue:passwordValue, GripJSONValue:prefixValue; i < n; i++) {
		tmp = grip_json_array_get_value(data, i);
		if (grip_json_get_type(tmp) != GripJSONObject) {
			grip_destroy_json_value(tmp);
			continue;
		}

		arrayset(auth, 0, sizeof auth);
		arrayset(password, 0, sizeof password);
		arrayset(prefix, 0, sizeof prefix);
		access = 0;
		flags = 0;
		expired = 0;
		options = 0;

		id = grip_json_object_get_number(tmp, "id");

		passwordValue = grip_json_object_get_value(tmp, "password");
		if (grip_json_get_type(passwordValue) != GripJSONNull) {
			grip_json_get_string(passwordValue, password, charsmax(password));
		}	
		grip_destroy_json_value(passwordValue);

		prefixValue = grip_json_object_get_value(tmp, "prefix");
		if (grip_json_get_type(prefixValue) != GripJSONNull) {
			grip_json_get_string(prefixValue, prefix, charsmax(prefix));
		}
		grip_destroy_json_value(prefixValue);

		grip_json_object_get_string(tmp, "auth_type", authTypeStr, charsmax(authTypeStr));
		switch (getAuthType(authTypeStr)) {
			case AUTH_TYPE_STEAM: {
				flags |= FLAG_AUTHID | FLAG_NOPASS;
				grip_json_object_get_string(tmp, "steamid", auth, charsmax(auth));
			}

			case AUTH_TYPE_STEAM_AND_PASS: {
				flags |= FLAG_AUTHID | FLAG_KICK;
				grip_json_object_get_string(tmp, "steamid", auth, charsmax(auth));
				options |= UAC_OPTIONS_MD5;
			}

			case AUTH_TYPE_NICK_AND_PASS: {
				flags |= FLAG_KICK;
				grip_json_object_get_string(tmp, "nick", auth, charsmax(auth));
				options |= UAC_OPTIONS_MD5;
			}
		}

		new GripJSONValue:privileges = grip_json_object_get_value(tmp, "privileges");
		for (new j = 0, k = grip_json_array_get_count(privileges), GripJSONValue:privilege, GripJSONValue:expiredVal, group_id, priority = -1; j < k; j++) {
			privilege = grip_json_array_get_value(privileges, j);
			group_id = grip_json_object_get_number(privilege, "group_id");
			if (!getGroup(group_id)) {
				grip_destroy_json_value(privilege);
				continue;
			}

			access |= Group[GroupFlags];
			if (Group[GroupPriority] > priority) {
				priority = Group[GroupPriority];
				expiredVal = grip_json_object_get_value(privilege, "expired_at");
				if (grip_json_get_type(expiredVal) != GripJSONNull) {
					expired = grip_json_get_number(expiredVal) + GMX_GetServerTimeDiff();
				} else {
					expired = 0;
				}
				grip_destroy_json_value(expiredVal);

				if (prefix[0] == EOS) {
					copy(prefix, charsmax(prefix), Group[GroupPrefix]);
				}
			}
			grip_destroy_json_value(privilege);
		}
		grip_destroy_json_value(privileges);

		UAC_Push(id, auth, password, access, flags, prefix, expired, options);

		grip_destroy_json_value(tmp);
	}
}

AUTH_TYPE:getAuthType(const authType[]) {
	if (strcmp(authType, "steamid_pass") == 0) {
		return AUTH_TYPE_STEAM_AND_PASS;
	} else if (strcmp(authType, "nick_pass") == 0) {
		return AUTH_TYPE_NICK_AND_PASS;
	} else if (strcmp(authType, "steamid_hash") == 0) {
		return AUTH_TYPE_STEAM_AND_HASH;
	} else if (strcmp(authType, "nick_hash") == 0) {
		return AUTH_TYPE_NICK_AND_HASH;
	} else {
		return AUTH_TYPE_STEAM;
	}
}

bool:getGroup(const id) {
	if (id == 0) {
		return false;
	}

	for (new i = 0; i < GroupsNum; i++) {
		if (ArrayGetArray(Groups, i, Group, sizeof Group) && Group[GroupId] == id) {
			return true;
		}
	}

	return false;
}