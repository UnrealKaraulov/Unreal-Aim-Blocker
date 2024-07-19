#include <amxmodx>
#include <reapi>
#include <hamsandwich>

// Comment next line for disable weapon block feature
#define ENABLE_WEAPON_BLOCK

public plugin_init()
{
	register_plugin("Unreal Aim Blocker", "1.4", "karaulov");
	create_cvar("unreal_no_aim", "1.4", FCVAR_SERVER | FCVAR_SPONLY);
#if defined ENABLE_WEAPON_BLOCK
	// Remove not needed weapons from block list (add comments or remove from list)
	new const BLOCK_WEAPONS_LIST[][] = { "weapon_p228", "weapon_xm1014", "weapon_c4", "weapon_mac10", "weapon_elite", "weapon_fiveseven",
									 "weapon_ump45", "weapon_galil", "weapon_mp5navy", "weapon_m249", "weapon_m3", "weapon_tmp", "weapon_deagle", "weapon_ak47", "weapon_p90" };
	for (new i = 0; i < sizeof(BLOCK_WEAPONS_LIST); i++)
	{
		RegisterHam(Ham_Weapon_PrimaryAttack, BLOCK_WEAPONS_LIST[i], "fw_block_weapon_secondary", 1);
		RegisterHam(Ham_Item_Deploy, BLOCK_WEAPONS_LIST[i], "fw_block_weapon_secondary", 1);
	}
#endif
	RegisterHookChain(RG_PM_Move, "PM_Move_POST", .post = true);
}

// Bypass server side PSILENT [karaul0v method]
public PM_Move_POST(const id)
{
  static Float:vAngles[3];
  get_pmove(pm_oldangles, vAngles);
  set_pmove(pm_angles, vAngles);
  return HC_CONTINUE;
}

#if defined ENABLE_WEAPON_BLOCK
public fw_block_weapon_secondary(const weapon)
{
	if (get_member(weapon,m_Weapon_flNextSecondaryAttack) < 1000.0)
		set_member(weapon, m_Weapon_flNextSecondaryAttack, 2000.0);
}
#endif