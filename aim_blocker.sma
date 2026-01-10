#include <amxmodx>
#include <reapi>
#include <hamsandwich>
#include <fakemeta>
#include <cssdk_const>
#include <xs>

#define _easy_cfg_internal
#include <easy_cfg>

new const PLUGIN_VERSION[] = "2.31";

#pragma ctrlchar '\'

new const config_version = 2;

new const DEFAULT_BLOCKWEAPON_LIST[][] = { "weapon_p228", "weapon_xm1014", "weapon_c4", "weapon_mac10", "weapon_elite", "weapon_fiveseven",
									 "weapon_ump45", "weapon_galil", "weapon_mp5navy", "weapon_m249", "weapon_m3", "weapon_tmp", "weapon_deagle", "weapon_ak47", "weapon_p90" };

new Array:g_aBlockWeapons;

new g_iAimBlockMethod = 2;
new g_iScoreAttribMsg = 0;
new g_iScoreInfoMsg = 0;
new g_iForcechasecam = 0;
new g_iForcecamera = 0;
new g_iFadetoblack = 0;
new g_iVipFlags = -2;
new g_iBlockScoreSendDelay = 0;
new g_iMaxSpeedWarns = 0;
new g_iMaxMovementWarns = 0;

new g_iButtons[MAX_PLAYERS + 1][2];
//new g_iButtons_old[MAX_PLAYERS + 1] = {0, ...};
new g_iFpsCounter[MAX_PLAYERS + 1] = {0, ...};
new g_iCmdMsecCounter[MAX_PLAYERS + 1] = {0, ...};
new g_iBlockMove[MAX_PLAYERS + 1] = {0, ...};
new g_iStepCounter[MAX_PLAYERS + 1] = {0, ...};
new g_iScoreSendCounter[MAX_PLAYERS + 1] = {0, ...};
new g_iSpeedHackWarns[MAX_PLAYERS + 1] = {0, ...};
new g_iMoveHackWarns[MAX_PLAYERS + 1] = {0, ...};

new g_sSpeedHackBanString[256] = "amx_ban #[userid] 1000 'Speedhack detected'";
new g_sBadMovementBanString[256] = "amx_ban #[userid] 1000 'MovementHack detected'";

new bool:g_bShowDef = false;
new bool:g_bBlockScoreAttr = true;
new bool:g_bBlockScoreAttrAttack = false;
new bool:g_bBlockScoreLocalDead = false;
new bool:g_bBlockBadCmd = true;
new bool:g_bBlockSpeedHack = true;
new bool:g_bBlockSpeedHackDuck = false;
new bool:g_bBlockBackTrack = false;
new bool:g_bCustomSeedWhenMoving = true;

new bool:g_bCurScore[MAX_PLAYERS + 1] = {false, ...};
new bool:g_bWaitForBuyZone[MAX_PLAYERS + 1] = {false, ...};
new bool:g_bRadarFix[MAX_PLAYERS + 1] = {false, ...};
new bool:g_bUserBot[MAX_PLAYERS + 1] = {false, ...};
new bool:g_bCvarChecking[MAX_PLAYERS + 1] = {false, ...};

new Float:g_fSpeedWarnTime = 1.0;
new Float:g_fMoveWarnTime = 0.25;

new Float:g_fRadarStayTime = 0.45;
new Float:g_fRadarDeadTime = 0.05;
new Float:g_fSpeedHackTime = 0.20;

new Float:g_fSpeedHackWarnTime[MAX_PLAYERS + 1] = {0.0, ...};
new Float:g_fMovementWarnTime[MAX_PLAYERS + 1] = {0.0, ...};

new Float:g_fOldStepVol[MAX_PLAYERS + 1] = {0.0, ...};
new Float:g_fStepTime[MAX_PLAYERS + 1] = {0.0, ...};
new Float:g_fRadarUpdateTime[MAX_PLAYERS + 1] = {0.0, ...};
new Float:g_fSpeedHistory[MAX_PLAYERS + 1][3];
new Float:g_fSpeedHistoryTime[MAX_PLAYERS + 1] = {0.0, ...};

new Float:g_vAngles_old1[MAX_PLAYERS + 1][3];
new Float:g_vAngles_cur1[MAX_PLAYERS + 1][3];
new Float:g_vAngles_old2[MAX_PLAYERS + 1][3];
new Float:g_vAngles_cur2[MAX_PLAYERS + 1][3];

new Float:g_vPunchAngle[MAX_PLAYERS + 1][3];

new Float:g_vCL_movespeedkey[MAX_PLAYERS + 1] = {0.0, ...};
new Float:g_vCL_forwardspeed[MAX_PLAYERS + 1] = {0.0, ...};
new Float:g_vOldStepOrigin[MAX_PLAYERS + 1][3];

public plugin_init()
{
	register_plugin("Unreal Aim Blocker", PLUGIN_VERSION, "karaulov");
	create_cvar("unreal_no_aim", PLUGIN_VERSION, FCVAR_SERVER | FCVAR_SPONLY);

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

	new cur_config_version = 0;
	cfg_read_int("general", "config_version", cur_config_version, cur_config_version);

	if (cur_config_version != config_version)
	{
		log_amx("Create new config, because version changed from %i to %i", cur_config_version, config_version);
		cfg_clear();
		cfg_write_int("general", "config_version", config_version);
	}


	new iBlockWeaponCount = 0;
	cfg_read_int("general","block_weapon_count",iBlockWeaponCount,iBlockWeaponCount);
	cfg_read_int("general","aim_block_method",g_iAimBlockMethod,g_iAimBlockMethod);
	cfg_read_bool("general","block_score",g_bBlockScoreAttr,g_bBlockScoreAttr);
	cfg_read_bool("general","block_score_attack",g_bBlockScoreAttrAttack,g_bBlockScoreAttrAttack);
	cfg_read_int("general","block_score_delay",g_iBlockScoreSendDelay,g_iBlockScoreSendDelay);
	cfg_read_bool("general","block_score_local_dead",g_bBlockScoreLocalDead,g_bBlockScoreLocalDead);
	cfg_read_flt("general","block_score_radar_staytime",g_fRadarStayTime,g_fRadarStayTime);
	cfg_read_flt("general","block_score_radar_deadtime",g_fRadarDeadTime,g_fRadarDeadTime);
	cfg_read_bool("general","block_bad_cmd",g_bBlockBadCmd,g_bBlockBadCmd);
	cfg_read_bool("general","block_speedhack",g_bBlockSpeedHack,g_bBlockSpeedHack);
	cfg_read_bool("general","block_speedhack_mouseduck",g_bBlockSpeedHackDuck,g_bBlockSpeedHackDuck);
	cfg_read_flt("general","block_speedhack_time",g_fSpeedHackTime,g_fSpeedHackTime);
	cfg_read_bool("general","block_backtrack",g_bBlockBackTrack,g_bBlockBackTrack);
	cfg_read_bool("general","random_seed_when_moving",g_bCustomSeedWhenMoving,g_bCustomSeedWhenMoving);
	new flags[64] = "";
	cfg_read_str("general", "vip_flags", flags, flags, charsmax(flags));

	cfg_read_str("general", "block_bad_cmd_banstr", g_sBadMovementBanString, g_sBadMovementBanString, charsmax(g_sBadMovementBanString));
	cfg_read_int("general", "block_bad_cmd_warncount", g_iMaxMovementWarns, g_iMaxMovementWarns);
	cfg_read_flt("general", "block_bad_cmd_warntime", g_fMoveWarnTime, g_fMoveWarnTime);
	
	cfg_read_str("general", "block_speedhack_banstr", g_sSpeedHackBanString, g_sSpeedHackBanString, charsmax(g_sSpeedHackBanString));
	cfg_read_int("general", "block_speedhack_warncount", g_iMaxSpeedWarns, g_iMaxSpeedWarns);
	cfg_read_flt("general", "block_speedhack_warntime", g_fSpeedWarnTime, g_fSpeedWarnTime);
	
	// next block code for check readwrite access to cfg
	new bool:test_read_write_cfg = !g_bBlockBadCmd;
	
	cfg_write_bool("general","block_bad_cmd", test_read_write_cfg);
	cfg_read_bool("general","block_bad_cmd", test_read_write_cfg, test_read_write_cfg);
	cfg_write_bool("general","block_bad_cmd", g_bBlockBadCmd);

	if (test_read_write_cfg == g_bBlockBadCmd)
	{
		log_error(AMX_ERR_MEMACCESS, "Can't read/write cfg. Please reinstall server with needed access.");
		set_fail_state("Can't read/write cfg. Please reinstall server with needed access.");
		return;
	}

	if (g_fSpeedHackTime < 0.05)
	{
		g_fSpeedHackTime = 0.05;
		cfg_write_flt("general","block_speedhack_time",g_fSpeedHackTime);
	}

	if (g_fSpeedHackTime > 0.26)
	{
		g_fSpeedHackTime = 0.26;
		cfg_write_flt("general","block_speedhack_time",g_fSpeedHackTime);
	}
	
	if (g_fRadarStayTime < 0.1)
		g_fRadarStayTime = 0.1;

	if (g_fRadarDeadTime < 0.01)
		g_fRadarDeadTime = 0.01;

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
	
	if (g_iAimBlockMethod == 1 || g_iAimBlockMethod == 3 || g_iAimBlockMethod == 5)
	{	
		RegisterHookChain(RG_PM_Move, "PM_Move_Post", .post = true);
	}

	if (g_iAimBlockMethod == 2 || g_iAimBlockMethod == 5 || g_bBlockBadCmd || g_bBlockSpeedHack)
	{
		RegisterHookChain(RG_PM_Move, "PM_Move_Pre", .post = false);
	}
	
	if (g_bBlockBadCmd || g_bBlockScoreAttr || g_iAimBlockMethod == 1 || g_iAimBlockMethod == 3 || g_iAimBlockMethod == 5)
	{
		register_forward(FM_CmdStart, "FM_CmdStart_Pre", ._post = false);
	}

	if (g_bCustomSeedWhenMoving)
	{
		register_forward(FM_CmdStart, "FM_CmdStart_Post", ._post = true);
	}

	if (g_bBlockBadCmd || g_iAimBlockMethod == 5)
	{
		register_forward(FM_UpdateClientData, "FM_UpdateClientData_Post", ._post = true);
	}

	if (g_iAimBlockMethod == 1 || g_iAimBlockMethod == 3 || g_iAimBlockMethod == 5)
	{	
		cfg_set_path("reaimdetector");

		new iNoSpread = 0;
		cfg_read_int("NOSPREAD","NOSPREAD_DETECTION",iNoSpread,iNoSpread);
		if (iNoSpread > 0)
		{
			log_amx("Detected NOSPREAD_DETECTION = %i in reaimdetector.cfg!",iNoSpread);
			cfg_write_int("NOSPREAD","NOSPREAD_DETECTION",0);
			server_cmd("reaim_reloadcfg");
			log_amx("Reloaded reaimdetector.cfg!");
		}
	}

	if (g_bBlockScoreAttr)
	{
		g_bShowDef = get_cvar_float("mp_scoreboard_showdefkit") != 0.0;

		g_iScoreAttribMsg = get_user_msgid("ScoreAttrib");
		g_iScoreInfoMsg = get_user_msgid("ScoreInfo");

		bind_pcvar_num(get_cvar_pointer("mp_forcechasecam"), g_iForcechasecam);
		bind_pcvar_num(get_cvar_pointer("mp_forcecamera"), g_iForcecamera);
		bind_pcvar_num(get_cvar_pointer("mp_fadetoblack"), g_iFadetoblack);

		register_message(g_iScoreAttribMsg, "ScoreAttrib_HOOK");
	}

	if (g_bBlockSpeedHack)
	{
		RegisterHookChain(RG_CBasePlayer_Spawn, "RG_Player_Spawn_Post", .post = true);
		RegisterHookChain(RG_PM_PlayStepSound, "PM_PlayStepSound_Pre", .post = false);
	}

	if (g_bBlockBackTrack || g_iAimBlockMethod == 5)
	{
		register_forward(FM_AddToFullPack, "AddToFullPack_Post", ._post = true);
	}

	if (flags[0] != EOS)
	{
		g_iVipFlags = read_flags(flags);
	}
	
	log_amx("AimBlocker [v%s] loaded!", PLUGIN_VERSION);
	log_amx("Settings: ");
	log_amx("  aim_block_method = %s", g_iAimBlockMethod == 0 ? "none" : g_iAimBlockMethod == 1 ? "[angle delay]" : g_iAimBlockMethod == 2 ? "[key delay]" : g_iAimBlockMethod == 3 ? "[2x angle delay]": g_iAimBlockMethod == 4 ? "[2x key delay]" : g_iAimBlockMethod == 5 ? "[2x angle delay] + [key delay] + [punch delay/rnd]" : "unknown");
	log_amx("  block_weapon_count = %i",iBlockWeaponCount);
	log_amx("  block_bad_cmd = %i",g_bBlockBadCmd);
	log_amx("  block_bad_cmd_banstr = %s", g_sBadMovementBanString);
	log_amx("  block_bad_cmd_warncount = %i",g_iMaxMovementWarns);
	log_amx("  block_bad_cmd_warntime = %f",g_fMoveWarnTime);
	log_amx("  block_score = %i",g_bBlockScoreAttr);
	log_amx("  block_score_attack = %i",g_bBlockScoreAttrAttack);
	log_amx("  block_score_local_dead = %i",g_bBlockScoreLocalDead);
	log_amx("  block_score_radar_staytime = %f",g_fRadarStayTime);
	log_amx("  block_score_radar_deadtime = %f",g_fRadarDeadTime);
	log_amx("  block_speedhack = %i (you can use 'hackdetector lite' instead)",g_bBlockSpeedHack);
	log_amx("  block_speedhack_mouseduck = %i (also can block +duck mwheelup)",g_bBlockSpeedHackDuck);
	log_amx("  block_speedhack_time = %f",g_fSpeedHackTime);
	log_amx("  block_speedhack_banstr = %s", g_sSpeedHackBanString);
	log_amx("  block_speedhack_warncount = %f",g_iMaxSpeedWarns);
	log_amx("  block_speedhack_warntime = %f",g_fSpeedWarnTime);
	log_amx("  block_backtrack = %i (not tested)",g_bBlockBackTrack);
	log_amx("  VIP TAB flags: %s [bin %X]",flags, g_iVipFlags == -2 ? 0 : g_iVipFlags);
}

public BanUserWithReason(const id, const reason[])
{
	static banstr[256];
	static userauth[64];
	static userid[16];
	static username[33];
	static userip[16];
	
	formatex(userid, charsmax(userid), "%i", get_user_userid(id));
	get_user_name(id, username, charsmax(username));
	get_user_ip(id, userip, charsmax(userip), true);
	get_user_authid(id, userauth, charsmax(userauth));
	
	copy(banstr,charsmax(banstr), reason);
	
	replace_all(banstr,charsmax(banstr),"[userid]",userid);
	replace_all(banstr,charsmax(banstr),"[username]",username);
	replace_all(banstr,charsmax(banstr),"[ip]",userip);
	replace_all(banstr,charsmax(banstr),"[steamid]",userauth);
	
	server_cmd("%s", banstr);
	
	log_to_file("unreal_aim_blocker.log", "[BAN] %s", banstr);
}

public AddToFullPack_Post(es_handle, e, ent, host, hostflags, bool:player, pSet) 
{
	if(!player || host > MaxClients || ent > MaxClients)
		return FMRES_IGNORED;

	if (g_iAimBlockMethod == 5 && ent == host)
	{
		static Float:vAngles[3];
		get_es(es_handle, ES_Angles, vAngles);
		vAngles[0] += random_float(-0.5, 0.5);
		set_es(es_handle, ES_Angles, vAngles);
	}
	
	// TODO replace to new REAPI version methods
	if (g_bBlockBackTrack)
	{
		static Float:animtime = 0.0;
		get_es(es_handle, ES_AnimTime, animtime);
		animtime *= 1.2;
		set_es(es_handle, ES_AnimTime, animtime);
	}
	
	return FMRES_IGNORED;
}

public RG_Player_Spawn_Post(id)
{
	get_entvar(id, var_origin, g_vOldStepOrigin[id]);
	g_fStepTime[id] = 0.0;
	g_fOldStepVol[id] = 0.0;
	return HC_CONTINUE;
}

public PM_PlayStepSound_Pre(step, Float:vol, id)
{
	if (g_fStepTime[id] == 0.0)
	{
		get_entvar(id, var_origin, g_vOldStepOrigin[id]);
	}
	
	new Float:fGameTime = get_gametime();

	if (fGameTime - g_fStepTime[id] < g_fSpeedHackTime && g_fOldStepVol[id] == vol)
	{
		if (g_iStepCounter[id] > 2)
		{
			/*if (fGameTime - g_fSpeedHackWarnTime[id] < g_fSpeedWarnTime)
			{
				g_iSpeedHackWarns[id]++;
			}*/
			g_iSpeedHackWarns[id]++;
			if (g_iMaxSpeedWarns > 0 && g_iSpeedHackWarns[id] > g_iMaxSpeedWarns)
			{
				g_iSpeedHackWarns[id] = 0;
				if (strlen(g_sSpeedHackBanString) > 0)
				{
					BanUserWithReason(id, g_sSpeedHackBanString);
				}
				force_drop_client_reason(id, "SPEEDHACK DETECTED");
			}
			g_fSpeedHackWarnTime[id] = fGameTime;
			//log_amx("[%i] SpeedHack detected [%f] = %f!", id, fGameTime - g_fStepTime[id],vol);
			set_entvar(id, var_origin, g_vOldStepOrigin[id]);
		}
		else 
		{
			//log_amx("[%i] SpeedHack warn [%f] = %f!", id,fGameTime - g_fStepTime[id],vol);
			if(g_iStepCounter[id] < 0)
				g_iStepCounter[id] = 0;
			g_iStepCounter[id]++;
		}
	}
	else 
	{
		if (fGameTime - g_fSpeedHackWarnTime[id] > g_fSpeedWarnTime)
		{
			if (g_iSpeedHackWarns[id] > 0)
			{
				g_iSpeedHackWarns[id]--;
			}
		}
		g_iStepCounter[id]--;
		if (g_iStepCounter[id] <= 0)
		{
			get_entvar(id, var_origin, g_vOldStepOrigin[id]);
			g_fStepTime[id] = 0.0;
			return HC_CONTINUE;
		}
	}

	g_fOldStepVol[id] = vol;
	g_fStepTime[id] = fGameTime;
	return HC_CONTINUE;
}

public clear_client(id)
{
	g_bCurScore[id] = g_bWaitForBuyZone[id] = false;
	g_vAngles_old1[id][0] = g_vAngles_old1[id][1] = g_vAngles_old1[id][2] = 0.0;
	g_vAngles_cur1[id][0] = g_vAngles_cur1[id][1] = g_vAngles_cur1[id][2] = 0.0;
	g_vAngles_old2[id][0] = g_vAngles_old2[id][1] = g_vAngles_old2[id][2] = 0.0;
	g_vAngles_cur2[id][0] = g_vAngles_cur2[id][1] = g_vAngles_cur2[id][2] = 0.0;
	g_vPunchAngle[id][0] = g_vPunchAngle[id][1] = g_vPunchAngle[id][2] = 0.0;
	g_vOldStepOrigin[id][0] = g_vOldStepOrigin[id][1] = g_vOldStepOrigin[id][2] = 0.0;
	g_iButtons[id][0] = g_iButtons[id][1] = 0;
	g_iFpsCounter[id] = 0;
	g_iCmdMsecCounter[id] = 0;
	g_iBlockMove[id] = 0;
	g_bUserBot[id] = false;
	g_fOldStepVol[id] = 0.0;
	g_fStepTime[id] = 0.0;
	g_iStepCounter[id] = 0;
	g_fRadarUpdateTime[id] = 0.0;
	g_fSpeedHackWarnTime[id] = 0.0;
	g_fMovementWarnTime[id] = 0.0;
	g_iSpeedHackWarns[id] = 0;
	g_iMoveHackWarns[id] = 0;
}

public client_disconnected(id)
{
	clear_client(id);
}

public client_connectex(id)
{
	clear_client(id);
}

public client_putinserver(id)
{
	clear_client(id);
	g_vCL_movespeedkey[id] = 0.52;
	g_vCL_forwardspeed[id] = 400.0;
	g_fSpeedHistory[id][0] = g_fSpeedHistory[id][1] = g_fSpeedHistory[id][2] = 200.0;
	g_iButtons[id][0] = g_iButtons[id][1] = 0;
	g_bUserBot[id] = is_user_bot(id) || is_user_hltv(id);
	if (g_bBlockBadCmd && !g_bUserBot[id])
	{
		g_bCvarChecking[id] = true;
		query_client_cvar(id, "cl_movespeedkey", "update_client_movespeedkey");
		query_client_cvar(id, "cl_forwardspeed", "update_client_forwardspeed");
		query_client_cvar(id, "cl_backspeed", "update_client_forwardspeed");
		query_client_cvar(id, "cl_sidespeed", "update_client_forwardspeed");
		set_task(5.0, "query_client_movespeed", id);
	}
}

public update_client_movespeedkey(id, const cvar[], const value[])
{
	g_vCL_movespeedkey[id] = str_to_float(value);
	// max playable speed
	if (g_vCL_movespeedkey[id] <= 0.01 || g_vCL_movespeedkey[id] > 0.52)
	{
		g_vCL_movespeedkey[id] = 0.52;
	}
}

public update_client_forwardspeed(id, const cvar[], const value[])
{
	new Float:fSpeed = str_to_float(value);
	// reset default
	if (fSpeed < 399.0)
	{
		g_vCL_forwardspeed[id] = 400.0;
		if (g_bCvarChecking[id])
		{
			client_cmd(id, "echo [RESET BROKEN SPEED CVARS FROM [%i] TO DEFAULT [400] STEAM VALUES]", floatround(fSpeed));
			client_cmd(id, "cl_forwardspeed 400");
			client_cmd(id, "cl_backspeed 400");
			client_cmd(id, "cl_sidespeed 400");
		}
	}
	else if (g_bCvarChecking[id] && g_vCL_forwardspeed[id] > 0.0 && g_vCL_forwardspeed[id] != fSpeed)
	{
		g_vCL_forwardspeed[id] = 400.0;
		client_cmd(id, "echo [RESET NOT SYNC SPEED CVARS [%i] TO DEFAULT [400] STEAM VALUES]", floatround(fSpeed));
		client_cmd(id, "cl_forwardspeed 400");
		client_cmd(id, "cl_backspeed 400");
		client_cmd(id, "cl_sidespeed 400");
	}
	else 
	{
		g_vCL_forwardspeed[id] = fSpeed;
	}
}

public query_client_movespeed(id)
{
	if (!g_bUserBot[id] && is_user_connected(id))
	{
		g_bCvarChecking[id] = false;
		query_client_cvar(id, "cl_movespeedkey", "update_client_movespeedkey");
		query_client_cvar(id, "cl_forwardspeed", "update_client_forwardspeed");
		set_task(5.0, "query_client_movespeed", id);
	}
}

public plugin_end()
{
	ArrayDestroy(g_aBlockWeapons);
}

public PM_Move_Post(const id)
{
	static Float:vTmpAngles[3];
	if (id > 0 && id <= MaxClients && !g_bUserBot[id])
	{	
		if (g_iAimBlockMethod == 1)
		{
			get_pmove(pm_oldangles, vTmpAngles);
			set_pmove(pm_oldangles, g_vAngles_old1[id]);
			g_vAngles_old1[id][0] = vTmpAngles[0];
			g_vAngles_old1[id][1] = vTmpAngles[1];
			g_vAngles_old1[id][2] = vTmpAngles[2];
			get_pmove(pm_angles, vTmpAngles);
			set_pmove(pm_angles, g_vAngles_cur1[id]);
			g_vAngles_cur1[id][0] = vTmpAngles[0];
			g_vAngles_cur1[id][1] = vTmpAngles[1];
			g_vAngles_cur1[id][2] = vTmpAngles[2];
		}
		else if (g_iAimBlockMethod == 3 || g_iAimBlockMethod == 5)
		{
			get_pmove(pm_oldangles, vTmpAngles);
			set_pmove(pm_oldangles, g_vAngles_old1[id]);
			g_vAngles_old1[id][0] = g_vAngles_old2[id][0];
			g_vAngles_old1[id][1] = g_vAngles_old2[id][1];
			g_vAngles_old1[id][2] = g_vAngles_old2[id][2];
			g_vAngles_old2[id][0] = vTmpAngles[0];
			g_vAngles_old2[id][1] = vTmpAngles[1];
			g_vAngles_old2[id][2] = vTmpAngles[2];
			get_pmove(pm_angles, vTmpAngles);
			set_pmove(pm_angles, g_vAngles_cur1[id]);
			g_vAngles_cur1[id][0] = g_vAngles_cur2[id][0];
			g_vAngles_cur1[id][1] = g_vAngles_cur2[id][1];
			g_vAngles_cur1[id][2] = g_vAngles_cur2[id][2];
			g_vAngles_cur2[id][0] = vTmpAngles[0];
			g_vAngles_cur2[id][1] = vTmpAngles[1];
			g_vAngles_cur2[id][2] = vTmpAngles[2];
		}
	}
	return HC_CONTINUE;
}

public PM_Move_Pre(const id)
{
	static Float:vTmpAngles[3];
	if (id > 0 && id <= MaxClients && !g_bUserBot[id])
	{	
		if (g_iAimBlockMethod == 2 || g_iAimBlockMethod == 5 || (g_bBlockSpeedHack && !g_bBlockSpeedHackDuck))
		{
			new cmd = get_pmove(pm_cmd);
			if (g_iAimBlockMethod == 2 || g_iAimBlockMethod == 4 || g_iAimBlockMethod == 5)
				set_ucmd(cmd,ucmd_buttons, get_entvar(id, var_button));
			if (g_bBlockSpeedHack)
			{
				if (get_ucmd(cmd, ucmd_buttons) & IN_DUCK)
				{
					if (!g_bBlockSpeedHackDuck)
					{
						g_iStepCounter[id] = 0;
						g_fOldStepVol[id] = 0.0;
					}
					else 
					{
						g_iStepCounter[id]--;
					}
				}
			}
		}

		if (g_iStepCounter[id] > 2)
		{
			set_pmove(pm_origin, g_vOldStepOrigin[id]);
		}

		if (g_bBlockBadCmd)
		{
			if (g_iBlockMove[id] > 0)
			{
				new Float:mult = 1.0 + (float(g_iBlockMove[id]) / 15.0);

				get_pmove(pm_velocity, vTmpAngles);
				vTmpAngles[0] /= mult;
				vTmpAngles[1] /= mult;
				set_pmove(pm_velocity, vTmpAngles);

				get_entvar(id, var_velocity, vTmpAngles);
				vTmpAngles[0] /= mult;
				vTmpAngles[1] /= mult;
				set_entvar(id, var_velocity, vTmpAngles);
				
				if (g_iBlockMove[id] == 2 || g_iBlockMove[id] > g_iMoveHackWarns[id])
				{
					g_iMoveHackWarns[id]++;
					if (g_iMaxMovementWarns && g_iMoveHackWarns[id] > g_iMaxMovementWarns)
					{
						g_iMoveHackWarns[id] = 0;
						if (strlen(g_sBadMovementBanString) > 0)
						{
							BanUserWithReason(id, g_sBadMovementBanString);
						}
						force_drop_client_reason(id, "MOVEMENT HACK DETECTED");
					}
					g_fMovementWarnTime[id] = get_gametime();
				}
			}
		}
	}

	return HC_CONTINUE;
}

new drop_reason[MAX_PLAYERS + 1][256];

public force_drop_client(id)
{
	if (is_user_connected(id))
	{
		clear_client(id);
		rh_drop_client(id, drop_reason[id]);
	}
}

public force_drop_client_reason(id, const reason[])
{
	if (is_user_connected(id))
	{
		copy(drop_reason[id],charsmax(drop_reason[]),reason);
		set_task(0.01,"force_drop_client",id);
	}
}

// Set it to true for use unreliable messages (check sv_minrate if you see all 'dead' more than 100 msec)
new const bool:USE_UNRELIABLE = false;
new Float:MAGIC_SPEED = 200.0;

public FM_CmdStart_Pre(id, handle)
{
	if (id > 0 && id <= MaxClients && !g_bUserBot[id])
	{	
		new Float:fGameTime = get_gametime();
		new btn = get_uc(handle, UC_Buttons);
		if (g_bBlockBadCmd)
		{
			new iMsec = get_uc(handle, UC_Msec);

			if (iMsec == 0)
			{
				g_iFpsCounter[id]++;
				if (g_iFpsCounter[id] > 5)
				{
					g_iFpsCounter[id] = -999;
					force_drop_client_reason(id, "BAD FPS");
					return FMRES_SUPERCEDE;
				}
			}
			else 
			{
				g_iFpsCounter[id] = 0;
			}

			new Float:fForward = 0.0;
			get_uc(handle, UC_ForwardMove, fForward);
			new Float:fSide = 0.0;
			get_uc(handle, UC_SideMove, fSide);
			new Float:fUp = 0.0;
			get_uc(handle, UC_UpMove, fUp);

			if ( fForward != 0.0 || fSide != 0.0 || fUp != 0.0 )
			{
				if (btn & IN_MOVERIGHT == 0 && btn & IN_MOVELEFT == 0 && fSide != 0.0)
				{
					g_iBlockMove[id]++;
				}
				else if (btn & IN_FORWARD == 0 && btn & IN_BACK == 0 && fForward != 0.0)
				{
					g_iBlockMove[id]++;
				}
				else if (btn & IN_MOVERIGHT != 0 && btn & IN_MOVELEFT == 0 && fSide < -1.0)
				{
					g_iBlockMove[id]++;
				}
				else if (btn & IN_MOVERIGHT == 0 && btn & IN_MOVELEFT != 0 && fSide > 1.0)
				{
					g_iBlockMove[id]++;
				}
				else if (btn & IN_FORWARD != 0 && btn & IN_BACK == 0 && fForward < -1.0)
				{
					g_iBlockMove[id]++;
				}
				else 
				{
					new Float:fMaxMov1 = g_fSpeedHistory[id][0];
					new Float:fMaxMov2 = g_fSpeedHistory[id][1];
					new Float:fMaxMov3 = g_fSpeedHistory[id][2];

					if (fMaxMov1 <= g_vCL_forwardspeed[id] && fMaxMov2 <= g_vCL_forwardspeed[id] && fMaxMov3 <= g_vCL_forwardspeed[id])
					{
						new Float:fmov = xs_sqrt(fForward * fForward + fSide * fSide + fUp * fUp);
						new Float:fmov2 = fmov / g_vCL_movespeedkey[id];
						new Float:fmov3 = fmov * 1.25;
						new Float:fmov4 = fmov2 * 1.25;

						if (floatabs(fmov - fMaxMov1) > 5.0 && floatabs(fmov2 - fMaxMov1) > 5.0 &&
							floatabs(fmov - fMaxMov2) > 5.0 && floatabs(fmov2 - fMaxMov2) > 5.0 &&
							floatabs(fmov - fMaxMov3) > 5.0 && floatabs(fmov2 - fMaxMov3) > 5.0 &&
							floatabs(fmov - MAGIC_SPEED) > 0.01 && floatabs(fmov2 - MAGIC_SPEED) > 0.01)
						{
							if (g_iBlockMove[id] == 0)
							{
								if (floatabs(fmov3 - fMaxMov1) > 5.0 && floatabs(fmov4 - fMaxMov1) > 5.0 && 
									floatabs(fmov3 - fMaxMov2) > 5.0 && floatabs(fmov4 - fMaxMov2) > 5.0 &&
									floatabs(fmov3 - fMaxMov3) > 5.0 && floatabs(fmov4 - fMaxMov3) > 5.0)
								{
									g_iBlockMove[id]++;
								}
								else 
								{
									g_iBlockMove[id] = 0;
								}
							}
							else 
							{
								g_iBlockMove[id]++;
							}
						}
						else 
						{
							g_iBlockMove[id] = 0;
						}
						if (g_iBlockMove[id] > 0)
						{
							//log_amx("[%i] [warn:%i] [btn:%X] m1 = %.2f, m2 = %.2f, m3 = %.2f, m4 = %.2f, max1 = %.2f, max2 = %.2f, max3 = %.2f, side = %.2f, fwd = %.2f, up = %.2f", id, g_iBlockMove[id], btn, fmov,fmov2,fmov3,fmov4,fMaxMov1,fMaxMov2,fMaxMov3,fSide,fForward,fUp);
						}
					}
				}
			}
			else 
			{
				g_iBlockMove[id] = 0;
			}
			
			if (g_iMaxMovementWarns > 0 && g_iBlockMove[id] >= 1 && g_iBlockMove[id] <= 3)
			{
				client_cmd(id, "-strafe");
			}
			
			if (g_iBlockMove[id] > 0)
			{
				//log_amx("[%i] [warn:%i] [btn:%X] side = %.2f, fwd = %.2f, up = %.2f", id, g_iBlockMove[id], btn, fSide,fForward,fUp);
			}
			
			if (g_iBlockMove[id] == 0)
			{
				if (fGameTime - g_fMovementWarnTime[id] > g_fMoveWarnTime)
				{
					if (g_iMoveHackWarns[id] > 0)
					{
						g_iMoveHackWarns[id]--;
					}
				}
			}
			/*if (g_iBlockMove[id] > 0)
				log_amx("[%i] [warn:%i]", id, g_iBlockMove[id]);*/
		}

		if (g_bBlockScoreAttr)
		{
			// Use score attrib message [like in softblocker]
			new bool:oldScore = (g_iButtons[id][1] & IN_SCORE) > 0;
			g_bCurScore[id] = (btn & IN_SCORE) > 0;

			if (g_bBlockScoreAttrAttack)
			{
				if (g_bCurScore[id])
				{
					set_member(id, m_flNextAttack, 0.1);
				}
			}

			if (g_bBlockScoreLocalDead)
			{
				if (g_bWaitForBuyZone[id])
				{
					if (rg_get_user_buyzone(id))
					{
						UpdateUserScoreForPlayer(id, id);
						g_bWaitForBuyZone[id] = false;
						
						// force update scoreboard 
						
						message_begin(USE_UNRELIABLE ? MSG_ONE_UNRELIABLE : MSG_ONE, g_iScoreInfoMsg, _,id);
						write_byte(33); // is safe!
						write_short(0);
						write_short(0);
						write_short(0);
						write_short(0);
						message_end();
					}
					else 
					{						
						if (g_bRadarFix[id] && floatabs(fGameTime - g_fRadarUpdateTime[id]) > g_fRadarDeadTime)
						{
							g_bRadarFix[id] = !g_bRadarFix[id];
							UpdateUserScoreForPlayer(id, id);
							g_fRadarUpdateTime[id] = fGameTime;
						}
						else if (!g_bRadarFix[id] && floatabs(fGameTime - g_fRadarUpdateTime[id]) > g_fRadarStayTime)
						{
							g_bRadarFix[id] = !g_bRadarFix[id];
							message_begin(MSG_ONE_UNRELIABLE, g_iScoreAttribMsg, _, id);
							write_byte(id);
							write_byte(SCORE_STATUS_DEAD);
							message_end();
							g_fRadarUpdateTime[id] = fGameTime;
						}
					}
				}
				else
				{
					if (!rg_get_user_buyzone(id))
					{
						g_bWaitForBuyZone[id] = true;
					}
				}
			}

			if (oldScore == true && g_bCurScore[id] == false)
			{
				g_iScoreSendCounter[id] = -1;
				if (!is_user_bot(id))
				{
					new bool:in_buyzone = true;

					if (g_bBlockScoreLocalDead)
					{
						in_buyzone = rg_get_user_buyzone(id);
					}

					for(new iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
					{
						if (iPlayer == id)
						{
							if (in_buyzone)
							{
								UpdateUserScoreForPlayer(id, iPlayer);
								continue;
							}
							else 
							{
								g_bWaitForBuyZone[id] = true;
							}
						}

						if (is_user_connected(iPlayer))
						{
							if (get_member(id, m_iTeam) == get_member(iPlayer, m_iTeam))
							{
								continue;
							}

							message_begin(MSG_ONE_UNRELIABLE, g_iScoreAttribMsg, _, id);
							write_byte(iPlayer);
							write_byte(SCORE_STATUS_DEAD);
							message_end();
						}
					}

					
					// force update scoreboard 
					message_begin(USE_UNRELIABLE ? MSG_ONE_UNRELIABLE : MSG_ONE, g_iScoreInfoMsg, _,id);
					write_byte(33); // is safe!
					write_short(0);
					write_short(0);
					write_short(0);
					write_short(0);
					message_end();
				}
			}
			else 
			{
				if (oldScore == false && g_bCurScore[id] == true)
				{
					if (g_iBlockScoreSendDelay > 0)
					{
						g_iScoreSendCounter[id] = g_iBlockScoreSendDelay;
					}
					else 
					{
						if (!is_user_bot(id))
						{
							for(new iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
							{
								if (is_user_connected(iPlayer))
								{
									UpdateUserScoreForPlayer(id, iPlayer);
								}
							}

							// force update scoreboard 
							message_begin(USE_UNRELIABLE ? MSG_ONE_UNRELIABLE : MSG_ONE, g_iScoreInfoMsg, _,id);
							write_byte(33); // is safe!
							write_short(0);
							write_short(0);
							write_short(0);
							write_short(0);
							message_end();
						}
					}
				}
				else if (g_iBlockScoreSendDelay > 0)
				{
					g_iScoreSendCounter[id]--;
					if (g_iScoreSendCounter[id] == 0)
					{
						g_iScoreSendCounter[id] = -1;
						if (!is_user_bot(id))
						{
							for(new iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
							{
								if (is_user_connected(iPlayer))
								{
									UpdateUserScoreForPlayer(id, iPlayer);
								}
							}

							// force update scoreboard 
							message_begin(USE_UNRELIABLE ? MSG_ONE_UNRELIABLE : MSG_ONE, g_iScoreInfoMsg, _,id);
							write_byte(33); // is safe!
							write_short(0);
							write_short(0);
							write_short(0);
							write_short(0);
							message_end();
						}
					}
				}
			}
		}

		if (g_iAimBlockMethod == 2 || g_iAimBlockMethod == 4 || g_iAimBlockMethod == 5)
		{
			set_uc(handle, UC_Buttons, g_iButtons[id][g_iAimBlockMethod == 4 ? 0 : 1]);
		}
		
		g_iButtons[id][0] = g_iButtons[id][1];
		g_iButtons[id][1] = btn;
	}
	return FMRES_IGNORED;
}

public FM_CmdStart_Post(id)
{
	static Float:vVelocity[3];
	get_entvar(id, var_velocity, vVelocity);
	if (xs_vec_len(vVelocity) > 10.0)
	{
		set_member(id, random_seed, random_num(0, 2147483646));
	}
}

// Use score attrib message [like in softblocker]
public ScoreAttrib_HOOK(msgid, dest, id) 
{
	if (id <= 0 || id > MaxClients) 
	{
		return PLUGIN_CONTINUE;
	}

	if (!g_bCurScore[id])
	{
		new target = get_msg_arg_int(1);
		if (target == id)
		{
			if (g_bBlockScoreLocalDead)
			{
				if (!rg_get_user_buyzone(id))
				{
					return PLUGIN_HANDLED;
				}
			}

			new flags = get_msg_arg_int(2);
			if (flags & SCORE_STATUS_VIP == 0  && (g_iVipFlags != -2 && get_user_flags(id) & g_iVipFlags))
			{
				set_msg_arg_int(2, ARG_BYTE, flags | SCORE_STATUS_VIP);
			}
			return PLUGIN_CONTINUE;
		}
		else if (get_member(id, m_iTeam) == get_member(target, m_iTeam))
		{
			new flags = get_msg_arg_int(2);
			if (flags & SCORE_STATUS_VIP == 0  && (g_iVipFlags != -2 && get_user_flags(id) & g_iVipFlags))
			{
				set_msg_arg_int(2, ARG_BYTE, flags | SCORE_STATUS_VIP);
			}
			return PLUGIN_CONTINUE;
		}
		return PLUGIN_HANDLED;
	}

	new flags = get_msg_arg_int(2);
	if (flags & SCORE_STATUS_VIP == 0  && (g_iVipFlags != -2 && get_user_flags(id) & g_iVipFlags))
	{
		set_msg_arg_int(2, ARG_BYTE, flags | SCORE_STATUS_VIP);
	}
	return PLUGIN_CONTINUE;
}

public FM_UpdateClientData_Post(id, weapons, cd)
{
	if (id <= 0 || id > MaxClients) 
	{
		return FMRES_IGNORED;
	}

	if (g_bBlockBadCmd)
	{
		new Float:fGameTime = get_gametime();
		static Float:fCurSpeed = 0.0;
		get_cd(cd, CD_MaxSpeed, fCurSpeed);

		// reset default
		if (fCurSpeed == 0.0)
			fCurSpeed = 900.0;
		if (fCurSpeed == 1.0)
			fCurSpeed = 230.0;

		if (fCurSpeed != 1.0 && fCurSpeed != g_fSpeedHistory[id][0] && 
			fCurSpeed != g_fSpeedHistory[id][1] && 
			fCurSpeed != g_fSpeedHistory[id][2])
		{
			g_fSpeedHistory[id][0] = g_fSpeedHistory[id][1];
			g_fSpeedHistory[id][1] = g_fSpeedHistory[id][2];
			g_fSpeedHistory[id][2] = fCurSpeed;
		}

	
		if (fCurSpeed > 400.0)
		{
			g_fSpeedHistoryTime[id] = fGameTime;
		}
		else
		{
			if (g_fSpeedHistoryTime[id] > 0.0 && fGameTime - g_fSpeedHistoryTime[id] > 5.0)
			{
				g_fSpeedHistoryTime[id] = 0.0;

				if (g_fSpeedHistory[id][0] > 400.0)
				{
					g_fSpeedHistory[id][0] = 400.0;
				}

				if (g_fSpeedHistory[id][1] > 400.0)
				{
					g_fSpeedHistory[id][1] = 400.0;
				}

				if (g_fSpeedHistory[id][2] > 400.0)
				{
					g_fSpeedHistory[id][2] = 400.0;
				}
			}
		}
	}

	if (g_iAimBlockMethod == 5)
	{
		static Float:vAngles[3];
		static Float:vVelocity[3];
		get_cd(cd, CD_ViewOfs, vAngles);
		if (vAngles[2] == -8.0)
		{
			vAngles[2] = -7.0;
		}
		set_cd(cd, CD_ViewOfs, vAngles);
		get_cd(cd, CD_PunchAngle, vAngles);
		set_cd(cd, CD_PunchAngle, g_vPunchAngle[id]);
		get_entvar(id, var_velocity, vVelocity);
		if (xs_vec_len(vVelocity) > 10.0)
		{
			g_vPunchAngle[id][0] = vAngles[0] * 1.1;
			g_vPunchAngle[id][1] = vAngles[1] * 1.1;
		}
		else 
		{
			g_vPunchAngle[id][0] = vAngles[0] * 1.02;
			g_vPunchAngle[id][1] = vAngles[1] * 1.02;
		}
	}
	return FMRES_IGNORED;
}

public fw_block_weapon_secondary(const weapon)
{
	new id = get_member(weapon, m_pPlayer);
	new Float:fSecondary = get_member(weapon, m_Weapon_flNextSecondaryAttack);

	if (get_member(id,m_bOwnsShield))
	{
		if (fSecondary >= 1000.0)
		{
			set_member(weapon, m_Weapon_flNextSecondaryAttack, 0.0);
		}
	}
	else if (fSecondary < 1000.0)
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

#define CAMERA_MODE_SPEC_ANYONE				0
#define CAMERA_MODE_SPEC_ONLY_TEAM			1
#define CAMERA_MODE_SPEC_ONLY_FIRST_PERSON 	2

#define FADETOBLACK_OFF						0
#define FADETOBLACK_STAY					1
#define FADETOBLACK_AT_DYING				2


stock GetForceCamera()
{
	new retVal = 0;

	if (g_iFadetoblack != FADETOBLACK_STAY)
	{
		retVal = g_iForcechasecam;

		if (retVal == CAMERA_MODE_SPEC_ANYONE)
			retVal = g_iForcecamera;
	}
	else
		retVal = CAMERA_MODE_SPEC_ONLY_FIRST_PERSON;

	return retVal;
}

stock UpdateUserScoreForPlayer(id, iPlayer)
{
	new iState = SCORE_STATUS_NONE;

	if (get_entvar(iPlayer,var_deadflag) != DEAD_NO)
	{
		iState |= SCORE_STATUS_DEAD;
	}
	else 
	{
		if (get_member(iPlayer,m_bHasC4))
		{
			iState |= SCORE_STATUS_BOMB;
		}

		if (get_member(iPlayer,m_bIsVIP) || (g_iVipFlags != -2 && get_user_flags(iPlayer) & g_iVipFlags))
		{
			iState |= SCORE_STATUS_VIP;
		}
		
		if (g_bShowDef && get_member(iPlayer,m_bHasDefuser))
		{
			iState |= SCORE_STATUS_DEFKIT;
		}

		if (iState & (SCORE_STATUS_BOMB | SCORE_STATUS_DEFKIT) && GetForceCamera() != CAMERA_MODE_SPEC_ANYONE)
		{
			new bool:bIsNotTeam = false;
	#if REAPI_VERSION > 524300
			bIsNotTeam = rg_player_relationship(id, iPlayer) != GR_TEAMMATE;
	#else
			bIsNotTeam = get_member(iPlayer, m_iTeam) != get_member(id, m_iTeam);
	#endif
			if (bIsNotTeam)
			{
				if (iState & SCORE_STATUS_BOMB)
				{
					iState -= SCORE_STATUS_BOMB;
				}

				if (iState & SCORE_STATUS_DEFKIT)
				{
					iState -= SCORE_STATUS_DEFKIT;
				}
			}
		}
	}
	message_begin(MSG_ONE, g_iScoreAttribMsg, _,id);
	write_byte(iPlayer);
	write_byte(iState);
	message_end();
}

stock bool:rg_get_user_buyzone(const pClient) {
    new iSignals[UnifiedSignals];
    get_member(pClient, m_signals, iSignals);

    return bool:(SignalState:iSignals[US_State] & SIGNAL_BUY);
}
