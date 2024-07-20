#include <amxmodx>
#include <reapi>
#include <hamsandwich>
#include <fakemeta>
#include <easy_cfg>

#pragma ctrlchar '\'

new const DEFAULT_BLOCKWEAPON_LIST[][] = { "weapon_p228", "weapon_xm1014", "weapon_c4", "weapon_mac10", "weapon_elite", "weapon_fiveseven",
									 "weapon_ump45", "weapon_galil", "weapon_mp5navy", "weapon_m249", "weapon_m3", "weapon_tmp", "weapon_deagle", "weapon_ak47", "weapon_p90" };
new Array:g_aBlockWeapons;
new g_bAimBlockMethod = 1;

public plugin_init()
{
	register_plugin("Unreal Aim Blocker", "2.1", "karaulov");
	create_cvar("unreal_no_aim", "2.1", FCVAR_SERVER | FCVAR_SPONLY);

	g_aBlockWeapons = ArrayCreate(64);

	cfg_set_path("plugins/unreal_aim_blocker.cfg");
	
	new tmp_cfgdir[512];
	cfg_get_path(tmp_cfgdir,charsmax(tmp_cfgdir));
	trim_to_dir(tmp_cfgdir);

	if (!dir_exists(tmp_cfgdir))
	{
		log_amx("Warning config dir not found: %s",tmp_cfgdir);
		if (mkdir(tmp_cfgdir) < 0)
		{
			log_error(AMX_ERR_NOTFOUND, "Can't create %s dir",tmp_cfgdir);
			set_fail_state("Fail while create %s dir",tmp_cfgdir);
			return;
		}
		else 
		{
			log_amx("Config dir %s created!",tmp_cfgdir);
		}
	}

	new iBlockWeaponCount = 0;
	cfg_read_int("general","block_weapon_count",iBlockWeaponCount,iBlockWeaponCount);

	cfg_read_int("general","aim_block_method",g_bAimBlockMethod,g_bAimBlockMethod);


	new sWeaponName[64];
	new sWeaponId[64];

	if (iBlockWeaponCount == 0)
	{
		cfg_write_int("general","block_weapon_count",sizeof(DEFAULT_BLOCKWEAPON_LIST));
		for (new i = 0; i < sizeof(DEFAULT_BLOCKWEAPON_LIST); i++)
		{
			formatex(sWeaponId,charsmax(sWeaponId),"weapon%i",i+1);
			cfg_write_str("weapons",sWeaponId,DEFAULT_BLOCKWEAPON_LIST[i]);
			ArrayPushString(g_aBlockWeapons,DEFAULT_BLOCKWEAPON_LIST[i]);
		}
	}
	else 
	{
		for (new i = 0; i < iBlockWeaponCount; i++)
		{
			formatex(sWeaponId,charsmax(sWeaponId),"weapon%i",i+1);
			cfg_read_str("weapons",sWeaponId,sWeaponName,sWeaponName,charsmax(sWeaponName));
			ArrayPushString(g_aBlockWeapons,sWeaponName);
		}
	}

	if (iBlockWeaponCount > 0)
	{
		for (new i = 0; i < ArraySize(g_aBlockWeapons); i++)
		{
			ArrayGetString(g_aBlockWeapons, i, sWeaponName, charsmax(sWeaponName));
			RegisterHam(Ham_Weapon_PrimaryAttack, sWeaponName, "fw_block_weapon_secondary", 1);
			RegisterHam(Ham_Item_Deploy, sWeaponName, "fw_block_weapon_secondary", 1);
		}
	}

	if (g_bAimBlockMethod > 0)
	{
		if (g_bAimBlockMethod == 1)
		{
			RegisterHookChain(RG_PM_Move, "PM_Move_HOOK", .post = true);
		}
		else 
		{
			register_forward(FM_CmdStart, "FM_CmdStart_Pre", false);
		}
	}
}

public plugin_end()
{
	ArrayDestroy(g_aBlockWeapons);
}

// Bypass server side PSILENT [karaul0v first method]
public PM_Move_HOOK(const id)
{
	static Float:vAngles1[MAX_PLAYERS + 1][3];
	static Float:vAngles2[MAX_PLAYERS + 1][3];
	static Float:vTmpAngles[3];
	if (id > 0 && id <= MaxClients)
	{	
		get_pmove(pm_oldangles, vTmpAngles);
		set_pmove(pm_oldangles, vAngles1[id]);
		vAngles1[id][0] = vTmpAngles[0];
		vAngles1[id][1] = vTmpAngles[1];
		vAngles1[id][2] = vTmpAngles[2];
		get_pmove(pm_angles, vTmpAngles);
		set_pmove(pm_angles, vAngles2[id]);
		vAngles2[id][0] = vTmpAngles[0];
		vAngles2[id][1] = vTmpAngles[1];
		vAngles2[id][2] = vTmpAngles[2];
	}
	return HC_CONTINUE;
}

// Bypass server side PSILENT [karaul0v second method]
public FM_CmdStart_Pre(id, handle)
{
	static buttons[MAX_PLAYERS + 1] = {0, ...};
	if (id > 0 && id <= MaxClients)
	{	
		new btn = get_uc(handle, UC_Buttons);
		set_uc(handle, UC_Buttons, buttons[id]);
		buttons[id] = btn;
		return FMRES_HANDLED;
	}
	return FMRES_IGNORED;
}

public fw_block_weapon_secondary(const weapon)
{
	if (get_member(weapon,m_Weapon_flNextSecondaryAttack) < 1000.0)
		set_member(weapon, m_Weapon_flNextSecondaryAttack, 2000.0);
}

stock trim_to_dir(path[])
{
	new len = strlen(path);
	len--;
	for(; len >= 0; len--)
	{
		if(path[len] == '/' || path[len] == '\\')
		{
			path[len] = EOS;
			break;
		}
	}
}