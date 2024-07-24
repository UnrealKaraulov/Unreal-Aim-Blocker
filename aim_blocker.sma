#include <amxmodx>
#include <reapi>
#include <hamsandwich>
#include <fakemeta>
#include <easy_cfg>
#include <cssdk_const>

#pragma ctrlchar '\'

new const DEFAULT_BLOCKWEAPON_LIST[][] = { "weapon_p228", "weapon_xm1014", "weapon_c4", "weapon_mac10", "weapon_elite", "weapon_fiveseven",
									 "weapon_ump45", "weapon_galil", "weapon_mp5navy", "weapon_m249", "weapon_m3", "weapon_tmp", "weapon_deagle", "weapon_ak47", "weapon_p90" };

new Array:g_aBlockWeapons;

new g_iAimBlockMethod = 1;
new g_iScoreAttribMsg = 0;
new g_iScoreInfoMsg = 0;

new bool:g_bBlockScoreAttr = true;
new bool:g_bBlockScoreAttrAttack = false;
new bool:g_bShowDef = false;

new g_iForcechasecam = 0;
new g_iForcecamera = 0;
new g_iFadetoblack = 0;

new bool:g_bCurScore[MAX_PLAYERS + 1] = {false, ...};

public plugin_init()
{
	register_plugin("Unreal Aim Blocker", "2.3", "karaulov");
	create_cvar("unreal_no_aim", "2.3", FCVAR_SERVER | FCVAR_SPONLY);

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
	cfg_read_bool("general","block_score_attr",g_bBlockScoreAttr,g_bBlockScoreAttr);
	cfg_read_bool("general","block_attr_attack",g_bBlockScoreAttrAttack,g_bBlockScoreAttrAttack);
	cfg_read_int("general","aim_block_method",g_iAimBlockMethod,g_iAimBlockMethod);


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


	if (g_iAimBlockMethod > 0)
	{
		if (g_iAimBlockMethod == 1)
		{	
			RegisterHookChain(RG_PM_Move, "PM_Move_HOOK", .post = true);
		}
	}
	
	register_forward(FM_CmdStart, "FM_CmdStart_Pre", false);

	if (g_iAimBlockMethod == 1)
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
		g_iScoreAttribMsg = get_user_msgid("ScoreAttrib");
		g_iScoreInfoMsg = get_user_msgid("ScoreInfo");
		register_message(g_iScoreAttribMsg, "ScoreAttrib_HOOK");
		g_bShowDef = get_cvar_float("mp_scoreboard_showdefkit") != 0.0;
		g_iForcechasecam = get_cvar_num("mp_forcechasecam");
		g_iForcecamera = get_cvar_num("mp_forcecamera");
		g_iFadetoblack = get_cvar_num("mp_fadetoblack");

	}
}

public client_disconnected(id)
{
	g_bCurScore[id] = false;
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
		new bool:bHandled = false;
		
		if (g_bBlockScoreAttr)
		{
			// Use score attrib message [like in softblocker]
			new bool:oldScore = (buttons[id] & IN_SCORE) > 0;
			g_bCurScore[id] = (btn & IN_SCORE) > 0;

			if (g_bBlockScoreAttrAttack)
			{
				if (g_bCurScore[id])
				{
					if (g_iAimBlockMethod != 1)
					{
						set_member(id, m_flNextAttack, 0.1);
					}
				}
			}

			if (oldScore == true && g_bCurScore[id] == false)
			{
				if (!is_user_bot(id))
				{
					for(new iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
					{
						message_begin(MSG_ONE, g_iScoreAttribMsg, _, id);
						write_byte(iPlayer);
						write_byte(SCORE_STATUS_DEAD);
						message_end();
					}
				}
			}
			else if (oldScore == false && g_bCurScore[id] == true)
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
					message_begin(MSG_ONE, g_iScoreInfoMsg, _,id);
					write_byte(33);
					write_short(0);
					write_short(0);
					write_short(0);
					write_short(0);
					message_end();
				}
			}
		}

		if (g_iAimBlockMethod == 1)
		{
			set_uc(handle, UC_Buttons, buttons[id]);
			bHandled = true;
		}
		
		buttons[id] = btn;

		if (bHandled)
		{
			return FMRES_HANDLED;
		}
	}
	return FMRES_IGNORED;
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
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
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
	
	if (get_member(iPlayer,m_bHasC4))
	{
		iState |= SCORE_STATUS_BOMB;
	}

	if (get_member(iPlayer,m_bIsVIP))
	{
		iState |= SCORE_STATUS_VIP;
	}
	
	if (g_bShowDef && get_member(iPlayer,m_bHasDefuser))
	{
		iState |= SCORE_STATUS_DEFKIT;
	}

	if (iState & (SCORE_STATUS_BOMB | SCORE_STATUS_DEFKIT) && GetForceCamera() != CAMERA_MODE_SPEC_ANYONE)
	{
		if (rg_player_relationship(id, iPlayer) != GR_TEAMMATE)
			iState &= ~(SCORE_STATUS_BOMB | SCORE_STATUS_DEFKIT);
	}

	message_begin(MSG_ONE, g_iScoreAttribMsg, _,id);
	write_byte(iPlayer);
	write_byte(iState);
	message_end();
}