#include <amxmodx>
#include <reapi>
#include <hamsandwich>
#include <fakemeta>
#include <easy_cfg>
#include <cssdk_const>
#include <xs>

#pragma ctrlchar '\'

new const DEFAULT_BLOCKWEAPON_LIST[][] = { "weapon_p228", "weapon_xm1014", "weapon_c4", "weapon_mac10", "weapon_elite", "weapon_fiveseven",
									 "weapon_ump45", "weapon_galil", "weapon_mp5navy", "weapon_m249", "weapon_m3", "weapon_tmp", "weapon_deagle", "weapon_ak47", "weapon_p90" };

new Array:g_aBlockWeapons;

new g_iAimBlockMethod = 1;
new g_iScoreAttribMsg = 0;
new g_iScoreInfoMsg = 0;
new g_iForcechasecam = 0;
new g_iForcecamera = 0;
new g_iFadetoblack = 0;

new g_iButtons[MAX_PLAYERS + 1] = {0, ...};
//new g_iButtons_old[MAX_PLAYERS + 1] = {0, ...};
new g_iCmdCounter[MAX_PLAYERS + 1] = {0, ...};
new g_iCmdMsecCounter[MAX_PLAYERS + 1] = {0, ...};
new g_iBlockMove[MAX_PLAYERS + 1] = {0, ...};
new g_iStepCounter[MAX_PLAYERS + 1] = {0, ...};

new bool:g_bBlockScoreAttr = true;
new bool:g_bBlockScoreAttrAttack = false;
new bool:g_bBlockScoreLocalDead = false;
new bool:g_bShowDef = false;
new bool:g_bBlockBadCmd = false;
new bool:g_bBlockSpeedHack = false;

new bool:g_bCurScore[MAX_PLAYERS + 1] = {false, ...};
new bool:g_bWaitForBuyZone[MAX_PLAYERS + 1] = {false, ...};
new bool:g_bRadarFix[MAX_PLAYERS + 1] = {false, ...};
new bool:g_bUserBot[MAX_PLAYERS + 1] = {false, ...};

new Float:g_fOldStepVol[MAX_PLAYERS + 1] = {0.0, ...};
new Float:g_fStepTime[MAX_PLAYERS + 1] = {0.0, ...};
new Float:g_fRadarUpdateTime[MAX_PLAYERS + 1] = {0.0, ...};
new Float:g_fRadarStayTime = 0.45;
new Float:g_fRadarDeadTime = 0.05;
new Float:g_fSpeedHackTime = 0.30;

new Float:g_vAngles1[MAX_PLAYERS + 1][3];
new Float:g_vAngles2[MAX_PLAYERS + 1][3];
new Float:g_vCmdCheckTime[MAX_PLAYERS + 1] = {0.0, ...};
new Float:g_vCL_movespeedkey[MAX_PLAYERS + 1] = {0.0, ...};
new Float:g_vOldStepOrigin[MAX_PLAYERS + 1][3];


new const PLUGIN_VERSION[] = "2.9";

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

	new iBlockWeaponCount = 0;
	cfg_read_int("general","block_weapon_count",iBlockWeaponCount,iBlockWeaponCount);
	cfg_read_int("general","aim_block_method",g_iAimBlockMethod,g_iAimBlockMethod);
	cfg_read_bool("general","block_score",g_bBlockScoreAttr,g_bBlockScoreAttr);
	cfg_read_bool("general","block_score_attack",g_bBlockScoreAttrAttack,g_bBlockScoreAttrAttack);
	cfg_read_bool("general","block_score_local_dead",g_bBlockScoreLocalDead,g_bBlockScoreLocalDead);
	cfg_read_flt("general","block_score_radar_staytime",g_fRadarStayTime,g_fRadarStayTime);
	cfg_read_flt("general","block_score_radar_deadtime",g_fRadarDeadTime,g_fRadarDeadTime);
	cfg_read_bool("general","block_bad_cmd",g_bBlockBadCmd,g_bBlockBadCmd);
	cfg_read_bool("general","block_speedhack",g_bBlockSpeedHack,g_bBlockSpeedHack);
	cfg_read_flt("general","block_speedhack_time",g_fSpeedHackTime,g_fSpeedHackTime);
	
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
	
	if (g_iAimBlockMethod == 1)
	{	
		RegisterHookChain(RG_PM_Move, "PM_Move_Post", .post = true);
	}

	if (g_iAimBlockMethod == 2 || g_bBlockBadCmd)
	{
		RegisterHookChain(RG_PM_Move, "PM_Move_Pre", .post = false);
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
		RegisterHookChain(RG_PM_PlayStepSound, "PM_PlayStepSound_Pre", .post = false);
	}

	log_amx("AimBlocker [v%s] loaded!", PLUGIN_VERSION);
	log_amx("Settings: ");
	log_amx("  aim_block_method = %i",g_iAimBlockMethod);
	log_amx("  block_weapon_count = %i",iBlockWeaponCount);
	log_amx("  block_bad_cmd = %i",g_bBlockBadCmd);
	log_amx("  block_score = %i",g_bBlockScoreAttr);
	log_amx("  block_score_attack = %i",g_bBlockScoreAttrAttack);
	log_amx("  block_score_local_dead = %i",g_bBlockScoreLocalDead);
	log_amx("  block_score_radar_staytime = %f",g_fRadarStayTime);
	log_amx("  block_score_radar_deadtime = %f",g_fRadarDeadTime);
	log_amx("  block_speedhack = %i",g_bBlockSpeedHack);
	log_amx("  block_speedhack_time = %f",g_fSpeedHackTime);

}

public PM_PlayStepSound_Pre(step, Float:vol, id)
{
	if (g_fStepTime[id] == 0.0)
	{
		get_entvar(id, var_origin, g_vOldStepOrigin[id]);
	}

	if (get_gametime() - g_fStepTime[id] < g_fSpeedHackTime && g_fOldStepVol[id] == vol)
	{
		if (g_iStepCounter[id] > 2)
		{
			static Float:tmpOrig[3];
			get_entvar(id, var_origin, tmpOrig);
			set_entvar(id, var_origin, g_vOldStepOrigin[id]);
			set_entvar(id, var_oldorigin, tmpOrig);
		}
		else 
		{
			g_iStepCounter[id]++;
		}
	}
	else 
	{
		if (g_iStepCounter[id] > 0)
		{
			g_iStepCounter[id]--;
		}
		else 
			get_entvar(id, var_origin, g_vOldStepOrigin[id]);
	}

	g_fOldStepVol[id] = vol;
	g_fStepTime[id] = get_gametime();
}

public clear_client(id)
{
	g_bCurScore[id] = g_bWaitForBuyZone[id] = false;
	g_vAngles1[id][0] = g_vAngles1[id][1] = g_vAngles1[id][2] = 0.0;
	g_vAngles2[id][0] = g_vAngles2[id][1] = g_vAngles2[id][2] = 0.0;
	g_vOldStepOrigin[id][0] = g_vOldStepOrigin[id][1] = g_vOldStepOrigin[id][2] = 0.0;
	g_iButtons[id] = /*g_iButtons_old[id] =*/ 0;
	g_vCmdCheckTime[id] = 0.0;
	g_iCmdCounter[id] = 0;
	g_iCmdMsecCounter[id] = 0;
	g_iBlockMove[id] = 0;
	g_bUserBot[id] = false;
	g_fOldStepVol[id] = 0.0;
	g_fStepTime[id] = 0.0;
	g_iStepCounter[id] = 0;
}

public client_disconnected(id)
{
	clear_client(id);
}

public client_connectex(id)
{
	clear_client(id);
	g_vCmdCheckTime[id] = get_gametime();
}

public client_putinserver(id)
{
	g_vCL_movespeedkey[id] = 0.52;
	g_bUserBot[id] = is_user_bot(id) || is_user_hltv(id);
	if (g_bBlockBadCmd && !g_bUserBot[id])
	{
		query_client_cvar(id, "cl_movespeedkey", "update_client_movespeedkey");
		set_task(5.0, "query_client_movespeedkey", id);
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

public query_client_movespeedkey(id)
{
	if (!g_bUserBot[id] && is_user_connected(id))
	{
		query_client_cvar(id, "cl_movespeedkey", "update_client_movespeedkey");
		set_task(5.0, "query_client_movespeedkey", id);
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
			set_pmove(pm_oldangles, g_vAngles1[id]);
			g_vAngles1[id][0] = vTmpAngles[0];
			g_vAngles1[id][1] = vTmpAngles[1];
			g_vAngles1[id][2] = vTmpAngles[2];
			get_pmove(pm_angles, vTmpAngles);
			set_pmove(pm_angles, g_vAngles2[id]);
			g_vAngles2[id][0] = vTmpAngles[0];
			g_vAngles2[id][1] = vTmpAngles[1];
			g_vAngles2[id][2] = vTmpAngles[2];
		}
	}
	return HC_CONTINUE;
}

public PM_Move_Pre(const id)
{
	static Float:vTmpAngles[3];
	if (id > 0 && id <= MaxClients && !g_bUserBot[id])
	{	
		if (g_iAimBlockMethod == 2)
		{
			new cmd = get_pmove(pm_cmd);
			set_ucmd(cmd,ucmd_buttons, get_entvar(id, var_button));
		}

		if (g_iStepCounter[id] > 2)
		{
			set_pmove(pm_origin, g_vOldStepOrigin[id]);
		}

		if (g_bBlockBadCmd)
		{
			if (g_iBlockMove[id] > 0)
			{
				get_pmove(pm_velocity, vTmpAngles);
				vTmpAngles[0] /= 1.2;
				vTmpAngles[1] /= 1.2;
				set_pmove(pm_velocity, vTmpAngles);

				if (g_iBlockMove[id] > 1)
				{
					get_entvar(id, var_velocity, vTmpAngles);
					vTmpAngles[0] /= 2.0;
					vTmpAngles[1] /= 2.0;
					set_entvar(id, var_velocity, vTmpAngles);
				}
			}
		}
	}
}

public FM_CmdStart_Pre(id, handle)
{
	if (id > 0 && id <= MaxClients && !g_bUserBot[id])
	{	
		new btn = get_uc(handle, UC_Buttons);
		new bool:bHandled = false;

		if (g_bBlockBadCmd)
		{
			new iMsec = get_uc(handle, UC_Msec);
			new Float:fMaxMov = get_entvar(id,var_maxspeed);

			if (iMsec < 1)
			{
				set_task(0.01,"force_drop_client_bad_fps",id);
				return FMRES_SUPERCEDE;
			}
			else if (fMaxMov > 0.0 && is_user_alive(id))
			{
				new Float:fForward = 0.0;
				get_uc(handle, UC_ForwardMove, fForward);
				new Float:fSide = 0.0;
				get_uc(handle, UC_SideMove, fSide);
				new Float:fUp = 0.0;
				get_uc(handle, UC_UpMove, fUp);

				if ( fForward != 0.0 || fSide != 0.0 || fUp != 0.0 )
				{
					new Float:fmov = xs_sqrt((fForward * fForward) + (fSide * fSide) + (fUp * fUp));
					new Float:fmov2 = fmov / g_vCL_movespeedkey[id];

					if (btn & IN_MOVERIGHT == 0 && btn & IN_MOVELEFT == 0 && fSide != 0.0)
					{
						g_iBlockMove[id]++;
						//log_amx("[%i] bad cmd1 fmov = %.2f, fmov2 = %.2f, fMaxMov = %.2f [%.2f %.2f %.2f]", id,fmov,fmov2,fMaxMov, fForward, fSide, fUp);
					}
					else if (btn & IN_FORWARD == 0 && btn & IN_BACK == 0 && fForward != 0.0)
					{
						g_iBlockMove[id]++;
						//log_amx("[%i] bad cmd2 fmov = %.2f, fmov2 = %.2f, fMaxMov = %.2f [%.2f %.2f %.2f]", id,fmov,fmov2,fMaxMov, fForward, fSide, fUp);
					}
					else if (btn & IN_MOVERIGHT != 0 && btn & IN_MOVELEFT == 0 && fSide < -1.0)
					{
						g_iBlockMove[id]++;
						//log_amx("[%i] bad cmd3 fmov = %.2f, fmov2 = %.2f, fMaxMov = %.2f [%.2f %.2f %.2f]", id,fmov,fmov2,fMaxMov, fForward, fSide, fUp);
					}
					else if (btn & IN_MOVERIGHT == 0 && btn & IN_MOVELEFT != 0 && fSide > 1.0)
					{
						g_iBlockMove[id]++;
						//log_amx("[%i] bad cmd4 fmov = %.2f, fmov2 = %.2f, fMaxMov = %.2f [%.2f %.2f %.2f]", id,fmov,fmov2,fMaxMov, fForward, fSide, fUp);
					}
					else if (btn & IN_FORWARD != 0 && btn & IN_BACK == 0 && fForward < -1.0)
					{
						g_iBlockMove[id]++;
						//log_amx("[%i] bad cmd5 fmov = %.2f, fmov2 = %.2f, fMaxMov = %.2f [%.2f %.2f %.2f]", id,fmov,fmov2,fMaxMov, fForward, fSide, fUp);
					}
					else if (floatabs(fmov - fMaxMov) > 5.0 && floatabs(fmov2 - fMaxMov) > 5.0)
					{
						if (g_iBlockMove[id] == 0)
						{
							new Float:fmov3 = fmov * 1.25;
							new Float:fmov4 = fmov2 * 1.25;
							if (floatabs(fmov3 - fMaxMov) > 5.0 && floatabs(fmov4 - fMaxMov) > 5.0)
							{
								g_iBlockMove[id]++;
								//log_amx("[%i] bad fmov = %.2f, fmov2 = %.2f, fMaxMov = %.2f [%.2f %.2f %.2f]", id,fmov,fmov2,fMaxMov, fForward, fSide, fUp);
							}
							else 
							{
								//log_amx("[%i] good2 fmov = %.2f, fmov2 = %.2f, fMaxMov = %.2f [%.2f %.2f %.2f]", id,fmov,fmov2,fMaxMov, fForward, fSide, fUp);
								g_iBlockMove[id] = 0;
							}
						}
						else 
						{
							g_iBlockMove[id]++;
							//log_amx("[%i] bad fmov = %.2f, fmov2 = %.2f, fMaxMov = %.2f [%.2f %.2f %.2f]", id,fmov,fmov2,fMaxMov, fForward, fSide, fUp);
						}
					}
					else 
					{
						//log_amx("[%i] good fmov = %.2f, fmov2 = %.2f, fMaxMov = %.2f [%.2f %.2f %.2f]", id,fmov,fmov2,fMaxMov, fForward, fSide, fUp);
						g_iBlockMove[id] = 0;
					}
				}
				else 
				{
					g_iBlockMove[id] = 0;
				}
			}
		}

		if (g_bBlockScoreAttr)
		{
			// Use score attrib message [like in softblocker]
			new bool:oldScore = (g_iButtons[id] & IN_SCORE) > 0;
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
						message_begin(MSG_ONE_UNRELIABLE, g_iScoreInfoMsg, _,id);
						write_byte(33); // is safe!
						write_short(0);
						write_short(0);
						write_short(0);
						write_short(0);
						message_end();
					}
					else 
					{
						if (g_bRadarFix[id] && floatabs(get_gametime() - g_fRadarUpdateTime[id]) > g_fRadarDeadTime)
						{
							g_bRadarFix[id] = !g_bRadarFix[id];
							UpdateUserScoreForPlayer(id, id);
							g_fRadarUpdateTime[id] = get_gametime();
						}
						else if (!g_bRadarFix[id] && floatabs(get_gametime() - g_fRadarUpdateTime[id]) > g_fRadarStayTime)
						{
							g_bRadarFix[id] = !g_bRadarFix[id];
							message_begin(MSG_ONE_UNRELIABLE, g_iScoreAttribMsg, _, id);
							write_byte(id);
							write_byte(SCORE_STATUS_DEAD);
							message_end();
							g_fRadarUpdateTime[id] = get_gametime();
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
					message_begin(MSG_ONE_UNRELIABLE, g_iScoreInfoMsg, _,id);
					write_byte(33); // is safe!
					write_short(0);
					write_short(0);
					write_short(0);
					write_short(0);
					message_end();
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
					message_begin(MSG_ONE_UNRELIABLE, g_iScoreInfoMsg, _,id);
					write_byte(33); // is safe!
					write_short(0);
					write_short(0);
					write_short(0);
					write_short(0);
					message_end();
				}
			}
		}

		if (g_iAimBlockMethod == 2)
		{
			/*new tmpbutton = get_entvar(id, var_oldbuttons);
			set_entvar(id, var_oldbuttons, g_iButtons_old[id]);
			g_iButtons_old[id] = tmpbutton;*/
			set_uc(handle, UC_Buttons, g_iButtons[id]);
			bHandled = true;
		}
		
		g_iButtons[id] = btn;

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
			return PLUGIN_CONTINUE;
		}
		else if (get_member(id, m_iTeam) == get_member(target, m_iTeam))
		{
			return PLUGIN_CONTINUE;
		}
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
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
#if REAPI_VERSION > 524300
		if (rg_player_relationship(id, iPlayer) != GR_TEAMMATE)
#else
		if (get_member(iPlayer, m_iTeam) != get_member(id, m_iTeam))
#endif
			iState &= ~(SCORE_STATUS_BOMB | SCORE_STATUS_DEFKIT);
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

stock force_drop_client_bad_fps(id)
{
	if (is_user_connected(id))
	{
		clear_client(id);
		rh_drop_client(id, "BAD FPS");
	}
}