#include <sourcemod>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf2condhooks>
#include <tf2utils>
#include <tf2items>
#include <WeaponAttachmentAPI>
#pragma newdecls required
#pragma semicolon 1
// #define VDECODE_FLAG_ALLOWWORLD  (1<<2)

// ConVar g_bEnablePlugin; // Convar that enables plugin
ConVar g_bApplyClassChangesToBots; // Convar that decides if attributes should apply to bots.
ConVar g_bApplyClassChangesToMvMBots; // Convar that decides if attributes should apply to MvM bots.

Handle g_hSDKFinishBuilding;
Handle g_Maplist = INVALID_HANDLE;

bool g_bIsMVM = false; // Is the mode MvM?
bool IS_MEDIEVAL = false;
bool IS_HALLOWEEN = false;
bool IS_SAXTON = false;

int g_particles[2048];
float g_lastHit[MAXPLAYERS+1];
float g_nextHit[MAXPLAYERS+1];
float g_lastFire[MAXPLAYERS+1];
float g_meleeStart[MAXPLAYERS+1];
float g_lastFlamed[MAXPLAYERS+1];
float g_temperature[MAXPLAYERS+1];
float g_playerUpgrades[MAXPLAYERS+1][8];
int g_TrueLastButtons[MAXPLAYERS+1];
int g_LastButtons[MAXPLAYERS+1];
int g_consecHits[MAXPLAYERS+1];
int g_condFlags[MAXPLAYERS+1];
int g_lastHeal[MAXPLAYERS+1];
int g_lockOn[MAXPLAYERS+1];
int g_spawnPumpkin[MAXPLAYERS+1];
int g_spawnHealth[MAXPLAYERS+1];
int g_spyTaunt[MAXPLAYERS+1];
int g_engyDispenser[MAXPLAYERS+1];
int g_Flames[MAXPLAYERS+1];
int g_bisonHit[2048];
float g_Grenades[2048];
int g_flagHelpers[2048];
int g_flameAttacker[MAXPLAYERS+1];
int g_dispenserStatus[2048];
int g_moneyFrames[2048];
int g_manglerCharge[2048];
int g_jumpCount[MAXPLAYERS+1];
float g_buildingHeal[2048];
float g_holstering[MAXPLAYERS+1];
float g_holsterPri[MAXPLAYERS+1];
float g_holsterSec[MAXPLAYERS+1];
float g_holsterMel[MAXPLAYERS+1];
float g_meterPri[MAXPLAYERS+1];
float g_meterSec[MAXPLAYERS+1];
float g_meterMel[MAXPLAYERS+1];
float g_lastVoice[MAXPLAYERS+1];
float g_lastVaccHeal[MAXPLAYERS+1];
float g_flameDamage[MAXPLAYERS+1];
float g_syringeHit[MAXPLAYERS+1];
float g_spyTauntTime[MAXPLAYERS+1];
float g_critHealReset[MAXPLAYERS+1];
float g_bonkedDebuff[MAXPLAYERS+1][2];
float g_flameHit[2048];
float g_flagTime[2048];
float g_sapperTime[2048];

// int CART = -1;
// float CARTSPEED = 200.0;
float g_nextParticleCheck = 0.0;
int g_FilteredEntity = -1;
int g_Maplist_Serial = -1;
int LAST_DAMAGE = 8980;
float IRON_DETECT = 80.0;
float PARACHUTE_TIME = 6.0;
float FIRE_TIME = 4.0;
float HAND_MAX = 8.0;
float PRESSURE_TIME = 8.0;
float PRESSURE_FORCE = 2.25;
float PRESSURE_COST = 33.33;
float HYPE_COST = 12.0;
#define TF_CONDFLAG_VACCMIN			(1 << 0)
#define TF_CONDFLAG_VACCMED			(1 << 1)
#define TF_CONDFLAG_VACCMAX      	(1 << 2)
#define TF_CONDFLAG_VOLCANO      	(1 << 3)
#define TF_CONDFLAG_HEAT	      	(1 << 4)
#define TF_CONDFLAG_HEATSPAWN		(1 << 5)
#define TF_CONDFLAG_EATING			(1 << 6)
#define TF_CONDFLAG_HEALSTEAL		(1 << 7)
#define TF_CONDFLAG_HOVER			(1 << 8)
#define TF_CONDFLAG_FAKE			(1 << 9)
#define TF_CONDFLAG_INFIRE			(1 << 10)
#define TF_CONDFLAG_INMELEE			(1 << 11)
#define TF_CONDFLAG_QUICK			(1 << 12)
#define TF_CONDFLAG_HEATER			(1 << 13)
#define TF_CONDFLAG_FANHIT			(1 << 14)
#define TF_CONDFLAG_FANFLY			(1 << 15)
#define TF_CONDFLAG_BLJUMP			(1 << 16)
#define TF_CONDFLAG_CAPPING			(1 << 17)
#define TF_CONDFLAG_SPYTAUNT		(1 << 18)
#define TF_CONDFLAG_UBERBOOST		(1 << 19)
#define TF_CONDFLAG_INSPAWN			(1 << 20)
#define TF_CONDFLAG_ALWAYS			(1 << 21)
#define TF_CONDFLAG_BASED			(1 << 22)
#define TF_CONDFLAG_CLEAVER			(1 << 23)
#define TF_CONDFLAG_UPGRADE			(1 << 24)
#define TF_CONDFLAG_NOGRADE			(1 << 25)
#define TF_CONDFLAG_DIVE			(1 << 26)
#define TF_CONDFLAG_RAZOR			(1 << 27)
#define TF_CONDFLAG_BONK			(1 << 28)
#define TF_CONDFLAG_LOSER			(1 << 30)

#define EF_BONEMERGE                (1 << 0)
#define EF_NOSHADOW                 (1 << 4)
#define EF_PARENT_ANIMATES          (1 << 9)

#define CPS_NOFLAGS           	 	0
#define CPS_RENDER            		(1 << 0)
#define CPS_NOATTACHMENT    		(1 << 1)

#define METER_CLASS "meter_label"

#define ANNOTATION_OFFSET 8750

enum struct Entity
{
	bool exists;
	float spawn_time;
}

public Plugin myinfo =
{
	name = "Bad Weapon Reprogramming",
	author = "ShSilver",
	description = "For use in Bad Weapon Rehabilitation Servers",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart()
{
	char sFilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "gamedata/rehab.txt");
	if(!FileExists(sFilePath)) {
		SetFailState("Gamedata file not found. Expected gamedata/rehab.txt");
	}
	GameData data = new GameData("rehab");
	if (!data) {
		SetFailState("Failed to open gamedata.rehab.txt. Unable to load plugin");
	}

	// g_bEnablePlugin = CreateConVar("sm_bwaplugin_enable", "1",
	// "Enables/Disables the plugin. Default = 1, 0 to disable.",
	// FCVAR_PROTECTED, true, 0.0, true, 1.0);
	g_bApplyClassChangesToBots = CreateConVar("sm_bwaplugin_bots_apply", "1",
	"Should changes apply to Bots? Enabling this could cause issues. Default = 1, 1 to enable.",
	FCVAR_PROTECTED, true, 0.0, true, 1.0);
	g_bApplyClassChangesToMvMBots = CreateConVar("sm_bwaplugin_botsmvm_apply", "0",
	"Should changes apply to MvM Bots? Enabling this could cause issues. Default = 0, 1 to enable.",
	FCVAR_PROTECTED, true, 0.0, true, 1.0);

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(data, SDKConf_Virtual, "CBaseObject::FinishedBuilding");
	g_hSDKFinishBuilding = EndPrepSDKCall();

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_builtobject", Event_BuildObject);
	HookEvent("teamplay_flag_event", Event_FlagEvent);
	HookEvent("teamplay_capture_blocked", Event_BlockCapture);
	HookEvent("mvm_wave_complete", Event_WaveComplete);
	HookEvent("teamplay_round_win", Event_RoundWin);

	AddCommandListener(PlayerListener,"taunt");
	AddCommandListener(PlayerListener,"+taunt");
	AddCommandListener(PlayerListener,"eureka_teleport");
	AddCommandListener(VoiceListener, "voicemenu");
	AddCommandListener(VoiceListener, "sm_sniper");
	AddCommandListener(StartUpgrade, "sm_upgrade");
	AddCommandListener(ExitUpgrade, "sm_exitupgrade");
	AddCommandListener(PlayerUpgrade, "sm_playerupgrade");
	AddCommandListener(PlayerReset, "sm_playerreset");

	AddGameLogHook(LogGameMessage);
	
	for (int i = 1 ; i <= MaxClients ; i++)
	{
		if(IsClientInGame(i))
			OnClientPutInServer(i);
		g_temperature[i]=0.5;
		g_holsterPri[i]=1.0;
		g_holsterSec[i]=1.0;
		g_holsterMel[i]=1.0;
		g_playerUpgrades[i][0] = 0.0;
		g_playerUpgrades[i][1] = 1.0;
		g_playerUpgrades[i][2] = 1.0;
		g_playerUpgrades[i][3] = 1.0;
		g_playerUpgrades[i][4] = 1.0;
		g_playerUpgrades[i][5] = 1.0;
		g_playerUpgrades[i][6] = 1.0;
		g_playerUpgrades[i][7] = 0.0;
	}

	char[] mapName = new char[64];
	GetCurrentMap(mapName,64);
	if(StrContains(mapName,"degroot") != -1 || StrContains(mapName,"harveste") != -1 || StrContains(mapName,"2castle") != -1 ||
	   StrContains(mapName,"morrigan") != -1 || StrContains(mapName,"burghausen") != -1 || StrContains(mapName,"graveshift") != -1)
	{
		IS_MEDIEVAL = true;
	}
	else
		IS_MEDIEVAL = false;

	g_Maplist = CreateArray(ByteCountToCells(33));

	// Bind the map list file to the "halloween" map list
	char mapListPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, mapListPath, sizeof(mapListPath), "configs/halloween_maps.txt");
	SetMapListCompatBind("halloween", mapListPath);

	if(StrContains(mapName,"vsh_") != -1)
		IS_SAXTON = true;
	else
		IS_SAXTON = false;

	AddFileToDownloadsTable("sound/vo/scout_mvm_sniper01.wav");
	AddFileToDownloadsTable("sound/vo/pyro_mvm_sniper01.wav");
	AddFileToDownloadsTable("sound/vo/demoman_mvm_sniper01.wav");
	AddFileToDownloadsTable("sound/vo/sniper_mvm_sniper01.wav");
	AddFileToDownloadsTable("sound/vo/spy_mvm_sniper01.wav");
	
	CreateTimer(0.5, HookSpawns, 0);
}
public void Round_Start(Handle event, const char[] name, bool dontBroadcast)
{
    CreateTimer(0.5, HookSpawns, 0); //this one too
}
Action HookSpawns(Handle Timer,int dummy)
{
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "func_respawnroom")) != -1)
	{
		SDKUnhook(ent, SDKHook_Touch, SpawnTouch);
		SDKUnhook(ent, SDKHook_EndTouchPost, SpawnEndTouch);
		SDKHook(ent, SDKHook_Touch, SpawnTouch);
		SDKHook(ent, SDKHook_EndTouchPost, SpawnEndTouch);
	}
	return Plugin_Continue;
}
Action SpawnTouch(int spawn, int client)
{
	if (client > MaxClients || client < 1)
		return Plugin_Continue;
	if (!IsClientInGame(client))
		return Plugin_Continue;
	if (GetEntProp(spawn, Prop_Send, "m_iTeamNum") == GetClientTeam(client))
		g_condFlags[client]|=TF_CONDFLAG_INSPAWN;
	return Plugin_Continue;
}
void SpawnEndTouch(int spawn, int client)
{
	if (client > MaxClients || client < 1)
		return;
	if (!IsClientInGame(client))
		return;
	if (GetEntProp(spawn, Prop_Send, "m_iTeamNum") == GetClientTeam(client))
		g_condFlags[client]&=~TF_CONDFLAG_INSPAWN;
}

public void OnClientPutInServer (int iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamageAlive, OnTakeDamage);
	SDKHook(iClient, SDKHook_OnTakeDamageAlivePost, OnTakeDamagePost);
	SDKHook(iClient, SDKHook_WeaponSwitch, WeaponSwitch);
	SDKHook(iClient, SDKHook_TraceAttack, OnTraceAttack);
	SDKHook(iClient, SDKHook_WeaponEquip, OnWeaponEquip);
}

public void OnMapStart()
{
	PrecacheSound("weapons/samurai/tf_marked_for_death_indicator.wav",true);
	PrecacheSound("weapons/rocket_pack_boosters_charge.wav",true);
	PrecacheSound("weapons/barret_arm_shot.wav",true);
	PrecacheSound("weapons/barret_arm_fizzle.wav",true);
	PrecacheSound("weapons/widow_maker_pump_action_back.wav",true);
	PrecacheSound("weapons/widow_maker_pump_action_forward.wav",true);
	PrecacheSound("weapons/revolver_reload_cylinder_arm.wav",true);
	PrecacheSound("player/recharged.wav",true);
	PrecacheSound("player/spy_uncloak.wav",true);
	PrecacheSound("player/spy_uncloak_feigndeath.wav",true);
	PrecacheSound("items/gunpickup2.wav",true);
	PrecacheSound("items/smallmedkit1.wav",true);
	PrecacheSound("player/flame_out.wav",true);
	PrecacheSound("weapons/explode1.wav",true);
	PrecacheSound("weapons/pipe_bomb1.wav",true);
	PrecacheSound("weapons/stickybomblauncher_det.wav",true);
	PrecacheSound("weapons/det_pack_timer.wav",true);
	PrecacheSound("weapons/bottle_impact_hit_flesh1.wav",true);
	PrecacheSound("weapons/medigun_no_target.wav",true);
	PrecacheSound("misc/flame_engulf.wav",true);
	PrecacheSound("misc/halloween/spell_fireball_impact.wav",true);
	PrecacheSound("weapons/syringegun_shoot.wav",true);
	PrecacheSound("weapons/tf_medic_syringe_overdose.wav",true);
	PrecacheSound("weapons/syringegun_shoot_crit.wav",true);
	PrecacheSound("weapons/tf_medic_syringe_overdose_crit.wav",true);
	PrecacheSound("weapons/drg_pomson_drain_01.wav",true);
	PrecacheSound("weapons/cbar_hit1.wav",true);
	PrecacheSound("weapons/cbar_hit2.wav",true);
	PrecacheSound("ui/cyoa_ping_in_progress.wav",true);
	PrecacheSound("weapons/fx/rics/arrow_impact_crossbow_heal.wav",true);
	PrecacheSound("weapons/syringegun_reload_air2.wav",true);
	PrecacheSound("weapons/flare_detonator_explode.wav",true);
	PrecacheSound("weapons/vaccinator_toggle.wav",true);
	PrecacheSound("misc/halloween/spell_overheal.wav",true);
	PrecacheSound("mvm/giant_soldier/giant_soldier_explode.wav",true);
	PrecacheSound("misc/halloween/spell_skeleton_horde_cast.wav",true);
	PrecacheSound("misc/banana_slip.wav",true);
	PrecacheSound("misc/sniper_railgun_double_kill.wav",true);
	PrecacheSound("weapons/tf2_backshot_shotty.wav",true);
	PrecacheSound("items/ammo_pickup.wav",true);
	PrecacheSound("misc/rd_finale_beep01.wav",true);
	PrecacheSound("weapons/sniper_bolt_forward.wav",true);
    PrecacheSound("items/powerup_pickup_precision.wav",true);
    PrecacheSound("items/powerup_pickup_reduced_damage.wav",true);
	PrecacheSound("weapons/sniper_rifle_classic_shoot.wav",true);
	PrecacheSound("weapons/sniper_rifle_classic_shoot_crit.wav",true);
	PrecacheSound("vo/sword_idle09.mp3",true);
	PrecacheSound("vo/sword_hit08.mp3",true);
	PrecacheSound("vo/scout_mvm_sniper01.wav",true);
	PrecacheSound("vo/soldier_mvm_sniper01.mp3",true);
	PrecacheSound("vo/pyro_mvm_sniper01.wav",true);
	PrecacheSound("vo/demoman_mvm_sniper01.wav",true);
	PrecacheSound("vo/heavy_mvm_sniper01.mp3",true);
	PrecacheSound("vo/engineer_mvm_sniper01.mp3",true);
	PrecacheSound("vo/medic_mvm_sniper01.mp3",true);
	PrecacheSound("vo/sniper_mvm_sniper01.wav",true);
	PrecacheSound("vo/spy_mvm_sniper01.wav",true);
	PrecacheSound("weapons/explode2.wav",true);
	PrecacheSound("player/cyoa_pda_beep6.wav",true);
	PrecacheSound("vo/taunts/demo/taunt_demo_exert_04.mp3",true);
	PrecacheSound("vo/taunts/demo/taunt_demo_exert_06.mp3",true);
	PrecacheSound("vo/taunts/demo/taunt_demo_exert_08.mp3",true);
	PrecacheSound("vo/taunts/demo/taunt_demo_flip_exert_03.mp3",true);
	PrecacheSound("weapons/stickybomblauncher_charge_up.wav",true);
	PrecacheSound("weapons/cow_mangler_over_charge.wav",true);
	PrecacheSound("weapons/rocket_reload.wav",true);
	PrecacheSound("weapons/grenade_launcher_worldreload.wav",true);
	PrecacheSound("vo/taunts/soldier/soldier_taunt_flip_fun_04.mp3",true); //TODO execute when diving
	PrecacheSound("vo/soldier_painsharp01.mp3",true); //TODO execute when landing
	PrecacheSound("vo/soldier_painsharp02.mp3",true);
	PrecacheSound("vo/soldier_painsharp03.mp3",true);
	PrecacheSound("vo/soldier_painsharp04.mp3",true);
	PrecacheSound("vo/soldier_painsharp05.mp3",true);
	PrecacheSound("vo/soldier_painsharp06.mp3",true);
	PrecacheSound("vo/soldier_painsharp07.mp3",true);
	PrecacheSound("vo/soldier_painsharp08.mp3",true);
	PrecacheSound("vo/taunts/soldier/soldier_taunt_flip_end_01.mp3",true); //TODO execute when landing correct
	PrecacheSound("vo/taunts/soldier/soldier_taunt_flip_end_02.mp3",true);
	PrecacheSound("vo/taunts/soldier/soldier_taunt_flip_end_03.mp3",true);
	PrecacheSound("vo/taunts/soldier/soldier_taunt_flip_end_05.mp3",true);
	PrecacheModel("models/weapons/w_models/w_syringe_proj.mdl",true);
	PrecacheModel("models/weapons/c_models/c_leechgun/c_leech_proj.mdl",true);
	PrecacheModel("models/workshop/weapons/c_models/c_chocolate/plate_chocolate.mdl",true);
	PrecacheModel("models/workshop/weapons/c_models/c_quadball/w_quadball_grenade.mdl",true);
	PrecacheModel("models/props_vehicles/train_engine.mdl",true);
	PrecacheModel("models/props_vehicles/train_enginecar.mdl",true);
	PrecacheModel("models/props_medieval/medieval_meat.mdl",true);
	if (GameRules_GetProp("m_bPlayingMannVsMachine"))
		g_bIsMVM = true;
	
	char[] mapName = new char[64];
	GetCurrentMap(mapName,64);
	if(StrContains(mapName,"degroot") != -1 || StrContains(mapName,"harveste") != -1 || StrContains(mapName,"2castle") != -1 ||
	   StrContains(mapName,"morrigan") != -1 || StrContains(mapName,"burghausen") != -1 || StrContains(mapName,"graveshift") != -1)
	{
		IS_MEDIEVAL = true;
	}
	else
		IS_MEDIEVAL = false;

	if(StrContains(mapName,"vsh_") != -1)
		IS_SAXTON = true;
	else
		IS_SAXTON = false;

	if (ReadMapList(g_Maplist,g_Maplist_Serial,"halloween",MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_NO_DEFAULT)	!= INVALID_HANDLE)
	{
		LogMessage("Loaded/Updated Halloween map list");
	}
	else if (g_Maplist_Serial == -1)
	{
		SetFailState("Halloween map list can't be loaded,");
	}

	if(IsHalloweenMap(mapName))
		IS_HALLOWEEN = true;
	else
		IS_HALLOWEEN = false;
}

public void OnEntityCreated(int iEnt, const char[] classname)
{
	if(IsValidEdict(iEnt))
	{
		if(StrContains(classname,"healthkit") != -1)
		{
			// SDKHook(iEnt, SDKHook_StartTouch, Event_PickUpHealthStart);
			SDKHook(iEnt, SDKHook_Touch, Event_PickUpHealth);
		}
		if(StrContains(classname, "ammopack") != -1 || StrContains(classname, "ammo_pack") != -1)
		{
			SDKHook(iEnt, SDKHook_SpawnPost, Event_SpawnAmmo);
			SDKHook(iEnt, SDKHook_StartTouch, Event_PickUpAmmo);
		}
		else if(StrEqual(classname,"tf_projectile_energy_ball"))
		{
			SDKHook(iEnt, SDKHook_SpawnPost, manglerSpawn);
		}
		else if(StrEqual(classname,"tf_projectile_mechanicalarmorb"))
		{
			SDKHook(iEnt, SDKHook_SpawnPost, orbSpawn);
			SDKHook(iEnt, SDKHook_StartTouch, flareTouch);
		}
		else if(StrEqual(classname, "tf_projectile_energy_ring"))
		{
			SDKHook(iEnt, SDKHook_SpawnPost, laserSpawn);
			SDKHook(iEnt, SDKHook_Touch, laserTouch);
		}
		else if(StrEqual(classname, "tf_projectile_flare"))
		{
			SDKHook(iEnt, SDKHook_SpawnPost, flareSpawn);
			SDKHook(iEnt, SDKHook_StartTouch, flareTouch);
		}
		else if(StrEqual(classname, "tf_projectile_syringe")) //syringe
		{
			SDKHook(iEnt, SDKHook_SpawnPost, needleSpawn);
		}
		else if(StrEqual(classname, "tf_projectile_rocket")) //syringe
		{
			SDKHook(iEnt, SDKHook_StartTouch, rocketTouch);
		}
		else if(StrEqual(classname,"obj_sentrygun") || StrEqual(classname,"obj_dispenser") || StrEqual(classname,"obj_teleporter") || StrContains(classname,"sapper",false) != -1)
		{
			g_buildingHeal[iEnt] = 0.0;
			SDKHook(iEnt, SDKHook_SetTransmit, BuildingThink);
			SDKHook(iEnt, SDKHook_OnTakeDamage, BuildingDamage);
		}
		else if(StrEqual(classname,"tf_gas_manager"))
		{
			SDKHook(iEnt, SDKHook_Touch, GasTouch);
		}
		else if(StrEqual(classname,"item_teamflag")) //m_nFlagStatus
		{
			SDKHook(iEnt, SDKHook_Think, FlagThink);
			SDKHook(iEnt, SDKHook_Touch, FlagTouch);
			g_flagTime[iEnt] = 0.0;
			g_flagHelpers[iEnt] = 0;
		}
		else if(StrEqual(classname,"tf_flame_manager"))
		{
			SDKHook(iEnt, SDKHook_SpawnPost, FlameSpawn);
			SDKHook(iEnt, SDKHook_Touch, FlameTouch);
		}
		// else if(StrEqual(classname,"tf_projectile_balloffire"))
		// {
		// 	SDKHook(iEnt, SDKHook_Touch, FireTouch);
		// }
		else if(StrEqual(classname,"tf_projectile_pipe"))
		{
			SDKHook(iEnt, SDKHook_SpawnPost, PipeSpawn);
			// SDKHook(iEnt, SDKHook_Think, PipeSet);
		}
		else if(StrEqual(classname, "tf_logic_medieval"))
		{
			AcceptEntityInput(iEnt,"Kill");
			IS_MEDIEVAL = true;
		}
		else if(StrEqual(classname, "tf_logic_medieval"))
		{
			AcceptEntityInput(iEnt,"Kill");
			IS_MEDIEVAL = true;
		}
		else if(StrEqual(classname, "trigger_capture_area"))
		{
			SDKHook(iEnt, SDKHook_StartTouch, PointTouchStart);
			SDKHook(iEnt, SDKHook_EndTouch, PointTouchEnd);
		}
		else if(StrContains(classname, "currencypack") != -1)
		{
			SDKHook(iEnt, SDKHook_SpawnPost, OnMoneySpawn);
		}
		else if(StrEqual(classname, "tank_boss"))
		{
			SDKHook(iEnt, SDKHook_TraceAttack, OnTraceAttack);
			SDKHook(iEnt, SDKHook_OnTakeDamageAlive, OnTakeDamage);
			SDKHook(iEnt, SDKHook_OnTakeDamageAlivePost, OnTakeDamagePost);
		}
		// else if(StrEqual(classname, "info_particle_system"))
		// {
		// 	SDKHook(iEnt, SDKHook_StartTouch, TouchParticle);
		// }
		// else if(StrEqual(classname, "team_train_watcher")) //payload
		// {
		// 	PrintToServer("SET FOR TRAIN ENT %d",iEnt);
		// 	SetVariantInt(1);
		// 	AcceptEntityInput(iEnt,"SetTrainCanRecede");
		// 	SetVariantInt(10);
		// 	AcceptEntityInput(iEnt,"SetTrainRecedeTimeAndUpdate");
		// }
		// else if(StrContains(classname,"tf_weapon") != -1 || StrContains(classname,"saxxy") != -1 || StrContains(classname,"tf_wearable") != -1)
		// {
		// 	SDKHook(iEnt, SDKHook_Spawn, WeaponSpawn);
		// }
		// else if(StrEqual(classname, "instanced_scripted_scene"))
		// {
		// 	SDKHook(iEnt, SDKHook_SpawnPost, sceneSpawn);
		// }
		// if(StrContains(classname,"tf_projectile") != -1)
		// {
		// 	SDKHook(iEnt, SDKHook_SpawnPost, projSpawn);	
		// }
		// PrintToChatAll(classname);
    }
}

public Action LogGameMessage(const char[] message)
{
	if(StrContains(message,"player_extinguished") && (StrContains(message,"tf_weapon_flamethrower") != -1 || StrContains(message,"tf_weapon_rocketlauncher_fireball") != -1))
	{
		int idStartPos = StrContains(message,"<")+1;
		int idEndPos = StrContains(message,"[U:1:") - 2;
		if(idEndPos < 0)
			idEndPos = StrContains(message,"<BOT>") - 1;
		char[] id = new char[MAX_NAME_LENGTH];
		strcopy(id,MAX_NAME_LENGTH,message[idStartPos]);
		id[idEndPos-idStartPos] = 0;
		int user = GetClientOfUserId(StringToInt(id));
		//refund airblast pressure on extinguish
		CreateTimer(0.06,ResetPressure,user);
	}
	else if(StrContains(message,"player_extinguished") && StrContains(message,"flaregun_revenge") != -1)
	{
		int idStartPos = StrContains(message,"<")+1;
		int idEndPos = StrContains(message,"[U:1:") - 2;
		if(idEndPos < 0)
			idEndPos = StrContains(message,"<BOT>") - 1;
		char[] id = new char[MAX_NAME_LENGTH];
		strcopy(id,MAX_NAME_LENGTH,message[idStartPos]);
		id[idEndPos-idStartPos] = 0;
		int user = GetClientOfUserId(StringToInt(id));
		//reward manmelter with crit progress
		g_meterSec[user]+=33.3;
		RequestFrame(RemoveMeltCrit,user);
	}
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Handle hEvent, const char[] cName, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(IS_SAXTON)
	{
		if(TF2_GetClientTeam(iClient)==TFTeam_Blue)
		{
			return Plugin_Changed;
		}
	}

	int melee = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Melee, true);
	int meleeIndex = -1;
	if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
	if(meleeIndex==173)
	{
		g_meterMel[iClient] = GetEntProp(iClient, Prop_Send, "m_iHealPoints")+0.0;
	}

	if(!IsFakeClient(iClient) || !g_bIsMVM)
	{
		char[] event = new char[64];
		GetEventName(hEvent,event,64);
		DataPack pack = new DataPack();
		pack.Reset();
		pack.WriteCell(iClient);
		pack.WriteString(event);
		float time=0.1;
		if(IsFakeClient(iClient))
		{
			time=0.33;
			CreateTimer(0.25,BotWeapons,iClient);
		}
		CreateTimer(time,PlayerSpawn,pack);
	}

	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
	ClientCommand(iClient, "r_screenoverlay \"\"");
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") | FCVAR_CHEAT);
	return Plugin_Changed;
}
public Action BotWeapons(Handle timer, int iClient)
{
	if(IsValidClient(iClient))
	{
		if(IsFakeClient(iClient))
		{
			int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
			int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
			int melee = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Melee, true);
			char class1[64],class2[64],class3[64];
			if(IsValidEdict(primary))
			{
				int primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
				GetEntityClassname(primary,class1,64);
				TF2Items_OnGiveNamedItem_Post(iClient, class1, primaryIndex, GetEntProp(primary, Prop_Send, "m_iEntityLevel"), GetEntProp(primary, Prop_Send, "m_iEntityQuality"), primary);
			}
			if(IsValidEdict(secondary))
			{
				int secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
				GetEntityClassname(secondary,class2,64);
				TF2Items_OnGiveNamedItem_Post(iClient, class2, secondaryIndex, GetEntProp(secondary, Prop_Send, "m_iEntityLevel"), GetEntProp(secondary, Prop_Send, "m_iEntityQuality"), secondary);
			}
			if(IsValidEdict(melee))
			{
				int meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
				GetEntityClassname(melee,class3,64);
				TF2Items_OnGiveNamedItem_Post(iClient, class3, meleeIndex, GetEntProp(melee, Prop_Send, "m_iEntityLevel"), GetEntProp(melee, Prop_Send, "m_iEntityQuality"), melee);
			}
		}
	}
	return Plugin_Changed;
}
public Action PlayerSpawn(Handle timer, DataPack dPack)
{
	dPack.Reset();
	int iClient = dPack.ReadCell();
	char[] event = new char[64];
	dPack.ReadString(event,64);

	if (IsValidClient(iClient))
	{
		int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
		int primaryIndex = -1;
		if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
		int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
		int secondaryIndex = -1;
		if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
		int melee = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Melee, true);
		int meleeIndex = -1;
		if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
		
		if(g_bIsMVM)
		{
			if(strcmp(event,"player_spawn") != 0)
			{
				if(!(g_condFlags[iClient] & TF_CONDFLAG_NOGRADE))
				{
					FakeClientCommand(iClient,"sm_upgrade");
					g_condFlags[iClient] = TF_CONDFLAG_INSPAWN;
				}
				else
				{
					g_condFlags[iClient] = TF_CONDFLAG_INSPAWN | TF_CONDFLAG_NOGRADE;
				}
			}
		}
		else
		{
			g_condFlags[iClient] = TF_CONDFLAG_INSPAWN;
		}
		TF2Attrib_SetByDefIndex(iClient,177,1.0); //weapon switch
		TF2Attrib_SetByDefIndex(iClient,68,0.0); //increase player capture value
		TF2Attrib_SetByDefIndex(iClient,400,0.0); //cannot pick up intelligence
		TF2Attrib_SetByDefIndex(iClient,239,1.0); //ubercharge rate bonus for healer

		switch(TF2_GetPlayerClass(iClient))
		{
			case TFClass_Engineer:
			{
				//southern hospitality range
				float range = 1.0;
				if(IsValidEdict(g_engyDispenser[iClient]))
				{
					if(g_bIsMVM) //mvm radius
					{
						Address addr = TF2Attrib_GetByName(melee, "clip size bonus");
						if(addr != Address_Null)
						{
							float value = TF2Attrib_GetValue(addr);
							range += value;
						}
					}
					char class[64];
					GetEntityClassname(g_engyDispenser[iClient],class,64);
					if(g_dispenserStatus[g_engyDispenser[iClient]]==1 && StrEqual(class,"obj_dispenser"))
						TF2Attrib_SetByDefIndex(melee,345,range+3.0); //engy dispenser radius increased
					else
						TF2Attrib_SetByDefIndex(melee,345,range); //engy dispenser radius increased
				}
				else
					TF2Attrib_SetByDefIndex(melee,345,range); //engy dispenser radius increased
			}
		}
		if(g_bIsMVM && !IsFakeClient(iClient)) //mvm stats
		{
			float reg,spe,jum,bul,bla,fir,cri,met;
			reg = g_playerUpgrades[iClient][0]; reg = reg < 0.0 ? 0.0 : reg;
			spe = g_playerUpgrades[iClient][1]; spe = spe < 1.0 ? 1.0 : spe;
			jum = g_playerUpgrades[iClient][2]; jum = jum < 1.0 ? 1.0 : jum;
			bul = g_playerUpgrades[iClient][3]; bul = bul > 1.0 ? 1.0 : bul;
			bla = g_playerUpgrades[iClient][4]; bla = bla > 1.0 ? 1.0 : bla;
			fir = g_playerUpgrades[iClient][5]; fir = fir > 1.0 ? 1.0 : fir;
			cri = g_playerUpgrades[iClient][6]; cri = cri > 1.0 ? 1.0 : cri;
			met = g_playerUpgrades[iClient][7]; met = met < 0.0 ? 0.0 : met;
			TF2Attrib_SetByName(iClient, "health regen", reg);
			TF2Attrib_SetByName(iClient, "major move speed bonus", spe);
			TF2Attrib_SetByName(iClient, "major increased jump height", jum);
			TF2Attrib_SetByName(iClient, "dmg taken from bullets reduced", bul);
			TF2Attrib_SetByName(iClient, "dmg taken from blast reduced", bla);
			TF2Attrib_SetByName(iClient, "dmg taken from fire reduced", fir);
			TF2Attrib_SetByName(iClient, "dmg taken from crit reduced", cri);
			TF2Attrib_SetByName(iClient, "metal regen", met);
		}

		switch(primaryIndex)
		{
			//Baby Face's Blaster
			case 772:
			{
				SetEntPropFloat(iClient, Prop_Send, "m_flHypeMeter", g_meterPri[iClient]);
			}
			//The Pomson 6000
			case 588:
			{
				float clip = 20.0;
				if(g_bIsMVM) //mvm force
				{
					Address addr = TF2Attrib_GetByName(primary, "clip size bonus");
					if(addr != Address_Null)
					{
						float value = TF2Attrib_GetValue(addr);
						clip *= value;
					}
				}
				SetEntPropFloat(primary, Prop_Send, "m_flEnergy", clip);
			}
			//The Blutsauger
			case 36:
			{
				int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
				SetEntData(primary, iAmmoTable, 25, _, true);
			}
			//Natascha
			case 41:
			{
				float maxammo = 1.5;
				if(g_bIsMVM)
				{
					Address addr = TF2Attrib_GetByName(primary, "clip size bonus");
					if(addr != Address_Null)
					{
						float value = TF2Attrib_GetValue(addr);
						maxammo += value/2.0;
					}
				}
				TF2Attrib_SetByDefIndex(primary,76,maxammo); //maxammo primary increased
				int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
				SetEntProp(iClient, Prop_Data, "m_iAmmo", RoundFloat(200*maxammo) , _, primaryAmmo);
			}
			//Loch-n-Load
			case 308:
			{
				int clip = 2;
				if(g_bIsMVM)
				{
					Address addr = TF2Attrib_GetByName(primary, "clip size upgrade atomic");
					if(addr != Address_Null)
					{
						float value = TF2Attrib_GetValue(addr);
						clip += RoundFloat(value);
					}
				}
				int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
				SetEntData(primary, iAmmoTable, clip, _, true);
			}
			//Dragon's Fury
			case 1178:
			{
				g_meterPri[iClient]=100.0;
			}
			//Hitman's Heatmaker
			case 752:
			{
				if(!TF2_IsPlayerInCondition(iClient,TFCond_FocusBuff)) //make sure tracers reset on death
				{
					TF2Attrib_SetByDefIndex(primary,144,3.0);
					TF2Attrib_SetByDefIndex(primary,51,0.0);
				}
			}
			//Cow Mangler 5000
			case 441:
			{
				SetEntPropFloat(primary, Prop_Send, "m_flEnergy", 15.0);
			}
		}

		switch(secondaryIndex)
		{
			//The Enforcer
			case 460:
			{
				if(g_meterSec[iClient]<1000)
					g_meterSec[iClient] = 0.0;
			}
			//Jarate, Mad Milk
			case 58,222,1121,1083,1105:
			{
				if(StrEqual(event,"player_spawn") || g_meterSec[iClient] < 0.3) //reset meter it on spawn, or if haven't had item for over 0.3 seconds
				{
					int iOffset = GetEntProp(secondary, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
					int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
					SetEntData(iClient, iAmmoTable+iOffset, -1, 4, true);//wipe ammo
					SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, 1);
					SetEntPropFloat(secondary, Prop_Send, "m_flLastFireTime",GetGameTime());
					SetEntPropFloat(secondary, Prop_Send, "m_flEffectBarRegenTime",GetGameTime());
				}
			}
			//The Razorback
			case 57:
			{
				// //set sheild status txt
				SetEntProp(secondary, Prop_Data, "m_fEffects", 129);
			}
			//The Diamondback
			case 525:
			{
				TF2_RemoveCondition(iClient,TFCond_Kritzkrieged);
			}
			//The Manmelter
			case 595:
			{
				if(StrEqual(event,"player_spawn"))
					g_meterSec[iClient]=0.0;
			}
			
		}

		switch(meleeIndex)
		{
			//The Eyelander
			case 132,266,482,1082:
			{
				RequestFrame(updateHeads,iClient);
			}
			//persian persuader
			case 404:
			{
				switch(primaryIndex)
				{
					case 405,608,1101:
					{
						//skip boots and BASE
					}
					default: //grenade launchers
					{
						int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
						SetEntProp(iClient, Prop_Data, "m_iAmmo", 8, _, primaryAmmo);
					}
				}
				switch(secondaryIndex)
				{
					case 131,406,1099,1144:
					{
						//skip shields
					}
					case 130: //ScotRes
					{
						int secondaryAmmo = GetEntProp(secondary, Prop_Send, "m_iPrimaryAmmoType");
						SetEntProp(iClient, Prop_Data, "m_iAmmo", 18, _, secondaryAmmo);
					}
					case 265: //Stickyjumper
					{
						int secondaryAmmo = GetEntProp(secondary, Prop_Send, "m_iPrimaryAmmoType");
						SetEntProp(iClient, Prop_Data, "m_iAmmo", 32, _, secondaryAmmo);
					}
					default: //other stickybombs
					{
						int secondaryAmmo = GetEntProp(secondary, Prop_Send, "m_iPrimaryAmmoType");
						if(TF2_GetPlayerClass(iClient)==TFClass_Soldier)
							SetEntProp(iClient, Prop_Data, "m_iAmmo", 16, _, secondaryAmmo); //shotgun
						else
							SetEntProp(iClient, Prop_Data, "m_iAmmo", 12, _, secondaryAmmo);
					}
				}
			}
			//Sun-On-A-Stick
			case 349:
			{
				if(strcmp(event,"player_spawn") == 0)
				{
					g_meterMel[iClient] = 0.0;
					g_condFlags[iClient] |= TF_CONDFLAG_HEATSPAWN;
				}
				else
					SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",g_meterMel[iClient],2); //set SOAS HEAT meter
			}
			//Neon Annihilator
			case 813, 834:
			{
				if(strcmp(event,"player_spawn") == 0 || GetEntPropFloat(melee, Prop_Send, "m_flLastFireTime") == 0.0)
				{
					SetEntProp(melee, Prop_Send, "m_bBroken",1);
					g_meterMel[iClient] = 0.0;
				}
			}
			//Scotsman's skullcutter
			case 172:
			{
				switch(secondaryIndex)
				{
					case 59: //screen
					{
						TF2Attrib_SetByDefIndex(secondary,249,1.5*1.2); //shield recharge rate
					}
					case 131,1099,1144: //targe, turner
					{
						TF2Attrib_SetByDefIndex(secondary,249,1.2); //shield recharge rate
					}
				}
			}
			//Conniver's Kunai
			case 356:
			{
				// TF2Attrib_SetByDefIndex(melee,217,0.0); //sanguisuge
				if(strcmp(event,"player_spawn") == 0)
				{
					TF2Attrib_SetByDefIndex(melee,125,-40.0); //max health additive penalty
					SetEntityHealth(iClient,85);
					g_meterMel[iClient] = 0.0;
				}
			}
		}
		
		int building = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Building, true);
		if(IS_MEDIEVAL)
		{
			if(building != GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon"))
				EquipPlayerWeapon(iClient, melee);
				// SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon",melee);
			switch(secondaryIndex)
			{
				case 46,163,222,812,833,1121,1145:
				{
					//scout exceptions
				}
				case 129,133,226,354,444,1001,1101:
				{
					//soldier exceptions
				}
				case 39,1081,1180:
				{
					//pyro exceptions
				}
				case 131,406,1099,1144:
				{
					//demo exceptions
				}
				case 42,159,311,433,863,1002,1190:
				{
					//heavy exceptions
				}
				case 140,1086,30668:
				{
					//engineer exceptions
				}
				//medic exceptions
				case 57,58,231,642,1083,1105:
				{
					//sniper exceptions
				}
				//spy exceptions
				default:
				{
					RemoveEdict(secondary);
				}
			}
			switch(primaryIndex)
			{
				//scout exceptions
				//soldier exceptions
				//pyro exceptions
				case 405,608,1101:
				{
					//demo exceptions
				}
				//heavy exceptions
				//engineer exceptions
				case 305,1079:
				{
					//medic exceptions
				}
				case 56,1005,1092:
				{
					//sniper exceptions
				}
				//spy exceptions
				default:
				{
					RemoveEdict(primary);
				}
			}
		}

		//reset variables for client on spawn
		g_lastFire[iClient] = 0.0;
		g_meleeStart[iClient] = 0.0;
		g_lastHit[iClient] = 0.0;
		g_nextHit[iClient] = 0.0;
		g_lastFlamed[iClient] = 0.0;
		g_temperature[iClient] = 0.0;
		g_lastHeal[iClient] = 0;
		g_lockOn[iClient] = 0;
		g_holstering[iClient] = 0.0;
		g_spawnPumpkin[iClient] = 0;
		g_lastVoice[iClient] = 0.0;
		g_lastVaccHeal[iClient] = 0.0;
		g_flameDamage[iClient] = 0.0;
		g_flameAttacker[iClient] = 0;
		g_syringeHit[iClient] = 0.0;
		g_critHealReset[iClient] = 0.0;
		g_bonkedDebuff[iClient][0] = 0.0;
		g_bonkedDebuff[iClient][1] = 0.0;
		g_jumpCount[iClient] = 0;
		
		TF2Attrib_SetByDefIndex(iClient,69,1.0); //set attr indexes for third degree
		SetEntityGravity(iClient,1.0); //reset jetpack gravity;
	}
	return Plugin_Changed;
}

public void TF2Items_OnGiveNamedItem_Post(int iClient, char[] cName, int itemIndex, int itemLevel, int itemQuality, int item)
{
	// SDKHook(item, SDKHook_Reload, DetectReload);
	bool notDisguise = true;
	TFClassType playerClass = TF2_GetPlayerClass(iClient);
	if(playerClass==TFClass_Spy)
	{
		if(StrContains(cName,"revolver")==-1 && StrContains(cName,"builder")==-1 && StrContains(cName,"sapper")==-1 && StrContains(cName,"knife")==-1 && StrContains(cName,"invis")==-1)
			notDisguise=false;
	}
	if((!IsFakeClient(iClient) || !g_bIsMVM) && notDisguise)
	{
		// TFClassType playerClass = TF2_GetPlayerClass(iClient);
		// int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
		int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
		// int melee = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Melee, true);
		// int watch = TF2Util_GetPlayerLoadoutEntity(iClient, 6, true);
		int building = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Building, true);
		int pda = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_PDA, true);
		int item1 = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Item1, true);
		if((IsValidEdict(building) && item==building)||(IsValidEdict(pda) && item==pda)||(IsValidEdict(item1) && item==item1))
			TF2Attrib_SetByDefIndex(item,2029,1.0); //allowed in medieval mode

		if (StrContains(cName,"scattergun")>=0||StrContains(cName,"primary")>=0||StrContains(cName,"popper")>=0||StrContains(cName,"brawler")>=0||
			StrContains(cName,"rocketlauncher")>=0||StrContains(cName,"cannon")>=0||StrContains(cName,"flamethrower")>=0||StrContains(cName,"particle")>=0||
			(StrContains(cName,"parachute")>=0&&playerClass==TFClass_DemoMan)||(StrContains(cName,"wearable")>=0&&playerClass==TFClass_DemoMan)||
			StrContains(cName,"minigun")>=0||(StrContains(cName,"shotgun")>=0&&playerClass==TFClass_Engineer)||StrContains(cName,"pomson")>=0||
			StrContains(cName,"syringegun")>=0||StrContains(cName,"syringegun")>=0||StrContains(cName,"crossbow")>=0||StrContains(cName,"sniperrifle")>=0||
			StrContains(cName,"compound")>=0)
		{
			g_meterPri[iClient] = 0.0;
			g_holsterPri[iClient] = 1.0;
		}
		if (StrContains(cName,"pistol")>=0||StrContains(cName,"lunchbox")>=0||StrContains(cName,"jar")>=0||StrContains(cName,"secondary")>=0||StrContains(cName,"cleaver")>=0||
			(StrContains(cName,"shotgun")>=0&&playerClass!=TFClass_Engineer)||StrContains(cName,"buff_item")>=0||StrContains(cName,"raygun")>=0||
			(StrContains(cName,"wearable")>=0&&playerClass!=TFClass_DemoMan)||(StrContains(cName,"parachute")>=0&&playerClass==TFClass_Soldier)||
			StrContains(cName,"flaregun")>=0||StrContains(cName,"rocketpack")>=0||StrContains(cName,"pipebomblauncher")>=0||StrContains(cName,"demoshield")>=0||
			StrContains(cName,"mechanical")>=0||StrContains(cName,"laser")>=0||StrContains(cName,"medigun")>=0||StrContains(cName,"smg")>=0||StrContains(cName,"revolver")>=0)
		{
			g_meterSec[iClient] = 0.0;
			g_holsterSec[iClient] = 1.0;
		}
		if (StrContains(cName,"_bat")>=0||StrContains(cName,"saxxy")>=0||StrContains(cName,"shovel")>=0||StrContains(cName,"katana")>=0||
			StrContains(cName,"fireaxe")>=0||StrContains(cName,"slap")>=0||StrContains(cName,"breakable")>=0||StrContains(cName,"weapon_bottle")>=0||
			StrContains(cName,"sword")>=0||StrContains(cName,"stickbomb")>=0||StrContains(cName,"fists")>=0||StrContains(cName,"robot_arm")>=0||
			StrContains(cName,"wrench")>=0||StrContains(cName,"bonesaw")>=0||StrContains(cName,"club")>=0||StrContains(cName,"knife")>=0)
		{
			g_consecHits[iClient] = 0; //at -1, the consecutive hits won't be counted
			TF2Attrib_SetByDefIndex(item,15,1.0); //crit mod disabled
			g_meterMel[iClient] = 0.0;
			g_holsterMel[iClient] = 1.0;
		}

		//class-specific changes
		switch(playerClass)
		{
			case TFClass_Sniper:
			{
				//modify sniper ammo
				if(StrContains(cName,"sniperrifle",false) != -1) //ignore bows
				{					
					TF2Attrib_SetByDefIndex(item,77,0.625); //set max ammo
					if(itemIndex != 526 && itemIndex != 30665) //set tracers
					{ 
						TF2Attrib_SetByDefIndex(item,647,1.0); //sniper fires tracer HIDDEN
						if(itemIndex != 230) TF2Attrib_SetByDefIndex(item,144,3.0); //set_weapon_mode
						if(itemIndex == 752) TF2Attrib_SetByDefIndex(item,51,0.0); //set_weapon_mode
					}
					//set clip and reserve
					int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
					int clip = 4; //default clip size
					switch(itemIndex)
					{
						// case 1098: //Classic clip bonus
						// 	clip = 6;
						case 526, 30665: //Machina clip penalty
							clip = 3;
					}
					if(g_bIsMVM) //mvm clip
					{
						Address addr = TF2Attrib_GetByName(item, "clip size bonus");
						if(addr != Address_Null)
						{
							float value = TF2Attrib_GetValue(addr);
							clip = RoundFloat(clip * value);
						}
					}
					TF2Attrib_SetByDefIndex(item,303,4.0); //set base clip ammo
					SetEntData(item, iAmmoTable, clip, 4, true);
					SetEntProp(item, Prop_Send, "m_iClip1",clip);
					int reserve = 16;
					if(g_bIsMVM) //mvm reserve
					{
						Address addr = TF2Attrib_GetByName(item, "maxammo primary increased");
						if(addr != Address_Null)
						{
							float value = TF2Attrib_GetValue(addr);
							reserve = RoundFloat(reserve * value);
						}
					}
					int primaryAmmo = GetEntProp(item, Prop_Send, "m_iPrimaryAmmoType");
					SetEntProp(iClient, Prop_Data, "m_iAmmo", reserve, _, primaryAmmo);
				}
			}
			case TFClass_Pyro: 
			{
				// modify pyro airblast
				if((StrContains(cName,"flamethrower",false) != -1 || StrContains(cName,"fireball",false) != -1) && itemIndex!=594) //ignore phlog
				{
					SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 100.0, 0);
					SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, 10);
					float force = 1.0;
					if(g_bIsMVM) //mvm force
					{
						Address addr = TF2Attrib_GetByName(item, "melee range multiplier");
						if(addr != Address_Null)
						{
							float value = TF2Attrib_GetValue(addr);
							force *= value;
						}
					}
					TF2Attrib_SetByDefIndex(item,164,force); //airblast force
				}
			}
			case TFClass_Spy:
			{
				if(StrContains(cName,"invis",false) != -1) //cloaking speed
				{
					TF2Attrib_SetByDefIndex(item,221,0.75); //mult decloak rate
				}
				if(StrContains(cName,"revolver",false) != -1) TF2Attrib_SetByDefIndex(item,106,0.85); //spread bonus //TF2Attrib_SetByDefIndex(item,51,1.0); //revolver use hit locations
			}
			case TFClass_DemoMan:
			{
				switch(itemIndex) //shield speeds
				{
					//screen
					case 59: TF2Attrib_SetByDefIndex(secondary,249,1.5); //shield recharge rate
					//targe, turner
					case 131,1099,1144: TF2Attrib_SetByDefIndex(secondary,249,1.0); //shield recharge rate
				}
				if(IsValidEdict(secondary) && (StrContains(cName,"saxxy",false) != -1 || StrContains(cName,"sword",false) != -1 || StrContains(cName,"katana",false) != -1 || StrContains(cName,"bottle",false) != -1 || StrContains(cName,"stickbomb",false) != -1))
				{
					int secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
					switch(secondaryIndex)
					{
						//screen
						case 59: TF2Attrib_SetByDefIndex(secondary,249,1.5); //shield recharge rate
						//targe, turner
						case 131,1099,1144: TF2Attrib_SetByDefIndex(secondary,249,1.0); //shield recharge rate
					}
				}
			}
		}

		switch(itemIndex) //melee crit changes
		{
			// add 3-hit crit combo to (most) melee weapons - exemptions including swords & knives or those with "no random crits" and/or situational (mini)crits; KGB, SoaS, Skullcutter, atomizer made exempt
			case 349,43,357,416,38,1000,457,813,834,307,132,266,327,404,482,1082,155,232,450,37,1003,447,173,310,413,171,325:
			{
				g_consecHits[iClient] = -1; //at -1, the consecutive hits won't be counted
				TF2Attrib_SetByDefIndex(item,15,0.0); //crit mod disabled
			}
			default:
			{
				if(TF2_GetPlayerClass(iClient) == TFClass_Spy || StrContains(cName,"sword",false) != -1 || StrContains(cName,"katana",false) != -1 || StrContains(cName,"knife",false) != -1 || StrContains(cName,"stickbomb",false) != -1)
				{
					g_consecHits[iClient] = -1; //no random crits
					TF2Attrib_SetByDefIndex(item,15,0.0); //crit mod disabled
				}
			}
		}

		//weapon-specific changes
		switch(itemIndex)
		{
			//PRIMARIES
			//The Classic
			case 1098:
			{
				TF2Attrib_SetByDefIndex(item,306,1.0); //headshots only at full charge
				// TF2Attrib_SetByDefIndex(item,4,1.5); //clip size bonus
				TF2Attrib_SetByDefIndex(item,75,1.33); //aiming movespeed increased
				TF2Attrib_SetByDefIndex(item,636,1.0); //sniper crit no scope
			}
			//Brass Beast
			case 312:
			{
				TF2Attrib_SetByDefIndex(item,738,0.7); //spinup damge resistance
			}
			//Huo-Long Heater
			case 811,832:
			{
				TF2Attrib_SetByDefIndex(item,1,1.0); //damage penalty
				TF2Attrib_SetByDefIndex(item,21,0.9); //damage penalty vs non-burning players
				TF2Attrib_SetByDefIndex(item,795,1.15); //damage bonus vs burning
				TF2Attrib_SetByDefIndex(item,431,3.0); //spinup ammo drain
			}
			//Baby Face's Blaster
			case 772:
			{
				TF2Attrib_SetByDefIndex(item,733,2.0); //hype lost on damge
				// g_meterPri[iClient]=0.0;
				// SetEntPropFloat(iClient, Prop_Send, "m_flHypeMeter", g_meterPri[iClient]);
			}
			//Liberty Launcher
			case 414:
			{
				// 
			}
			//The Pomson 6000
			case 588:
			{
				TF2Attrib_SetByDefIndex(item,337,0.0); //victim loses medigun charge
				TF2Attrib_SetByDefIndex(item,338,0.0); //victim loses cloak
				TF2Attrib_SetByDefIndex(item,6,0.8); //fire rate bonus
				TF2Attrib_SetByDefIndex(item,97,0.85); //reload speed bonus
				float clip = 20.0;
				if(g_bIsMVM) //mvm force
				{
					Address addr = TF2Attrib_GetByName(item, "clip size bonus");
					if(addr != Address_Null)
					{
						float value = TF2Attrib_GetValue(addr);
						clip *= value;
					}
				}
				TF2Attrib_SetByDefIndex(item,335,clip/20.0); //clip size upgrade
				TF2Attrib_SetByDefIndex(item,103,1.5); //projectile speed
			}
			//The Back Scatter
			case 1103:
			{
				//
			}
			//The Shortstop
			case 220:
			{
				TF2Attrib_SetByDefIndex(item,241,1.35); //reload time increased hidden
				TF2Attrib_SetByDefIndex(item,476,0.875); //damage bonus HIDDEN
			}
			//Syringe Gun
			case 17,204:
			{
				TF2Attrib_SetByDefIndex(item,280,9.0); //projectile override
			}
			//The Blutsauger
			case 36:
			{
				TF2Attrib_SetByDefIndex(item,280,9.0); //projectile override
				TF2Attrib_SetByDefIndex(item,3,0.63); //clip size penalty
			}
			//The Overdose
			case 412:
			{
				TF2Attrib_SetByDefIndex(item,280,9.0); //projectile override
				TF2Attrib_SetByDefIndex(item,1,0.8); //damage penalty
				TF2Attrib_SetByDefIndex(item,792,1.25); //move speed bonus resource level
			}
			//The Phlogistinator
			case 594:
			{
				TF2Attrib_SetByDefIndex(item,350,1.0); //ragdolls become ash
				TF2Attrib_SetByDefIndex(item,436,0.0); //ragdolls plasma effect
			}
			//Natascha
			case 41:
			{
				TF2Attrib_SetByDefIndex(item,32,0.0); //slow on hit
				TF2Attrib_SetByDefIndex(item,738,1.0); //spinup damge resistance
				TF2Attrib_SetByDefIndex(item,740,0.33); //reduced_healing_from_medics
				float maxammo = 1.5;
				if(g_bIsMVM)
				{
					Address addr = TF2Attrib_GetByName(item, "clip size bonus");
					if(addr != Address_Null)
					{
						float value = TF2Attrib_GetValue(addr);
						maxammo += value/2.0;
					}
				}
				TF2Attrib_SetByDefIndex(item,76,maxammo); //maxammo item increased
			}
			//Bazaar Bargain
			case 402:
			{
				TF2Attrib_SetByDefIndex(item,41,1.5); //sniper charge
				TF2Attrib_SetByDefIndex(item,268,1.0); //mult sniper charge penalty DISPLAY ONLY
				TF2Attrib_SetByDefIndex(item,46,1.5); //sniper zoom penalty
			}
			//Loch-n-Load
			case 308:
			{
				TF2Attrib_SetByDefIndex(item,547,0.8); //deploy speed bonus
				TF2Attrib_SetByDefIndex(item,3,0.5); //clip size penalty
				TF2Attrib_SetByDefIndex(item,137,1.0); //dmg bonus vs buildings
			}
			//Sydney Sleeper
			case 230:
			{
				TF2Attrib_SetByDefIndex(item,41,1.0); //sniper charge
				TF2Attrib_SetByDefIndex(item,175,2.0); //jarate duration
				TF2Attrib_SetByDefIndex(item,869,1.0); //crits become minicrits
				TF2Attrib_SetByDefIndex(item,42,3.0); //weapon mode
				// TF2Attrib_SetByDefIndex(item,6,0.67); //fire rate bonus
				SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, 1);
			}
			//Air Strike
			case 1104:
			{
				TF2Attrib_SetByDefIndex(item,100,0.8); //Blast radius decreased
			}
			//The Machina
			case 526,30665:
			{
				TF2Attrib_SetByDefIndex(item,304,1.0); //sniper full charge damage bonus
				TF2Attrib_SetByDefIndex(item,266,1.0); //projectile penetration
				TF2Attrib_SetByDefIndex(item,3,0.75); //clip size penalty
			}
			//Tomislav
			case 424:
			{
				TF2Attrib_SetByDefIndex(item,87,0.8); //minigun spinup time decreased
				TF2Attrib_SetByDefIndex(item,5,1.3); //fire rate penalty
				TF2Attrib_SetByDefIndex(item,106,0.8); //spread bonus
				TF2Attrib_SetByDefIndex(item,2,1.0); //damage bonus
				TF2Attrib_SetByDefIndex(item,77,0.75); //maxammo item reduced
				int primaryAmmo = GetEntProp(item, Prop_Send, "m_iPrimaryAmmoType");
				SetEntProp(iClient, Prop_Data, "m_iAmmo", 150, _, primaryAmmo);
			}
			//Loose Cannon
			case 996:
			{
				TF2Attrib_SetByDefIndex(item,207,0.75); //blast dmg to self decreased
			}
			//Backburner
			case 40,1146:
			{
				//
			}
			//Iron Bomber
			case 1151:
			{
				TF2Attrib_SetByDefIndex(item,100,0.7); //blast radius decreased
				TF2Attrib_SetByDefIndex(item,787,1.3); //fuse bonus
				TF2Attrib_SetByDefIndex(item,5,1.2); //fire rate penalty
			}
			//Crusader's Crossbow
			case 305,1079:
			{
				int primaryAmmo = GetEntProp(item, Prop_Send, "m_iPrimaryAmmoType");
				SetEntProp(iClient, Prop_Data, "m_iAmmo", 15, _, primaryAmmo);
				TF2Attrib_SetByDefIndex(item,77,0.1); //maxammo item reduced
			}
			//Cow Mangler 5000
			case 441:
			{
				// float clip = 20.0;
				// if(g_bIsMVM) //mvm force
				// {
				// 	Address addr = TF2Attrib_GetByName(item, "clip size bonus");
				// 	if(addr != Address_Null)
				// 	{
				// 		float value = TF2Attrib_GetValue(addr);
				// 		clip *= value;
				// 	}
				// }
				// TF2Attrib_SetByDefIndex(item,335,clip/20.0); //clip size upgrade
				TF2Attrib_SetByDefIndex(item,335,0.75); //clip size upgrade
				TF2Attrib_SetByDefIndex(item,75,1.75); //aiming movespeed increased
			}
			//Soda Popper
			case 448:
			{
				TF2Attrib_SetByDefIndex(item,97,0.85); //reload speed bonus
			}
			//Dragon's Fury
			case 1178:
			{
				g_meterPri[iClient]=100.0;
			}

			//SECONDARIES
			//Panic Attack
			case 1153:
			{
				TF2Attrib_SetByDefIndex(item,348,1.0); //fire rate bonus
				TF2Attrib_SetByDefIndex(item,3,0.66); //clip size penalty
				TF2Attrib_SetByDefIndex(item,1,0.85); //damage penalty
				TF2Attrib_SetByDefIndex(item,808,0.0); //mult_spread_scales_consecutive
				TF2Attrib_SetByDefIndex(item,36,1.0); //spread penalty
				int clip = 4;
				if(g_bIsMVM) //mvm clip
				{
					Address addr = TF2Attrib_GetByName(item, "clip size bonus");
					if(addr != Address_Null)
					{
						float value = TF2Attrib_GetValue(addr);
						clip = RoundFloat(clip*value);
					}
				}
				int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
				SetEntData(item, iAmmoTable, clip, _, true);
			}
			//Flare Gun
			case 39,1081:
			{
				TF2Attrib_SetByDefIndex(item,2029,1.0); //allowed in medieval mode
			}
			//Pretty Boy's Pocket Pistol
			case 773:
			{
				TF2Attrib_SetByDefIndex(item,1,0.85); //damage penalty
			}
			//The Righteous Bison
			case 442:
			{
				TF2Attrib_SetByDefIndex(item,2,2.5); //damage bonus
				TF2Attrib_SetByDefIndex(item,6,0.8); //fire rate bonus
				TF2Attrib_SetByDefIndex(item,103,1.5); //projectile speed
			}
			//The Enforcer
			case 460:
			{
				TF2Attrib_SetByDefIndex(item,410,1.3); //damage bonus while disguised
				// TF2Attrib_SetByDefIndex(item,221,0.25); //mult decloak rate
				TF2Attrib_SetByDefIndex(item,34,1.2); //cloak drain penalty
				// if(g_meterSec[iClient]<1000)
				// 	g_meterSec[iClient] = 0.0;
			}
			//Buffalo Steak Sandvich
			case 311:
			{
				TF2Attrib_SetByDefIndex(item,798,1.0); //energy buff dmg taken multiplier
				TF2Attrib_SetByDefIndex(item,252,1.0); //damage force reduction
				TF2Attrib_SetByDefIndex(item,329,1.0); //airblast vulnerability multiplier
			}
			//Dalokohs Bar
			case 159, 433:
			{
				//
			}
			//Jarate, Mad Milk
			case 58,222,1121,1083,1105:
			{
				TF2Attrib_SetByDefIndex(item,2029,1.0); //allowed in medieval mode
				TF2Attrib_SetByDefIndex(item,856,3.0); //meter type
				TF2Attrib_SetByDefIndex(item,848,-1.0); //spawn doesn't affect resup
				TF2Attrib_SetByDefIndex(item,784,0.67); //extinguish reduces cooldown
				float time = 2.0;
				if(g_bIsMVM) //mvm time
				{
					Address addr = TF2Attrib_GetByName(item, "melee range multiplier");
					if(addr != Address_Null)
					{
						float value = TF2Attrib_GetValue(addr);
						time *= value;
					}
				}
				TF2Attrib_SetByDefIndex(item,278,time); //recharge rate
				if(itemIndex == 222 || itemIndex == 1121) //milk recharge
				{
					TF2Attrib_SetByDefIndex(item,2059,500.0); //damage to recharge
				}
				else //jarate splash reduction
				{
					TF2Attrib_SetByDefIndex(item,100,1.0); //Blast radius decreased
				}
			}
			//The Gas Passer
			case 1180:
			{
				TF2Attrib_SetByDefIndex(item,2029,1.0); //allowed in medieval mode
				float time = 40.0;
				if(g_bIsMVM) //mvm time
				{
					Address addr = TF2Attrib_GetByName(item, "melee bounds multiplier");
					if(addr != Address_Null)
					{
						float value = TF2Attrib_GetValue(addr);
						time *= value;
					}
				}
				TF2Attrib_SetByDefIndex(item,801,time); //recharge time
				TF2Attrib_SetByDefIndex(item,2059,500.0); //damage to recharge
				TF2Attrib_SetByDefIndex(item,74,1.0); //burn time
				TF2Attrib_SetByDefIndex(item,875,1.0); //explode_on_ignite
				TF2Attrib_SetByDefIndex(item,784,0.67); //extinguish reduces cooldown
				TF2Attrib_SetByDefIndex(item,848,-1.0); //spawn doesn't affect resup
			}
			//The Razorback
			case 57:
			{
				//set sheild status txt
				SetEntProp(item, Prop_Data, "m_fEffects", 129);
			}
			//Cleaner's Carbine
			case 751:
			{
				TF2Attrib_SetByDefIndex(item,106,0.75); //spread bonus
				TF2Attrib_SetByDefIndex(item,5,1.2); //fire rate penalty
				TF2Attrib_SetByDefIndex(item,780,0.8333); //minicrit boost charge rate
			}
			//Thermal Thruster
			case 1179:
			{
				TF2Attrib_SetByDefIndex(item,840,0.4); //holster anim time
				TF2Attrib_SetByDefIndex(item,547,0.5); //deploy speed bonus
				TF2Attrib_SetByDefIndex(item,400,1.0); //cannot pick up intelligence
			}
			//B.A.S.E. Jumper
			case 1101:
			{
				TF2Attrib_SetByDefIndex(item,610,2.0); //increased air control
				TF2Attrib_SetByDefIndex(item,135,0.85); //rocket jump damage reduction
			}
			//The Vaccinator
			case 998:
			{
				TF2Attrib_SetByDefIndex(item,503,0.1); //bullet resist passive
				TF2Attrib_SetByDefIndex(item,504,0.1); //blast resist passive
				TF2Attrib_SetByDefIndex(item,505,0.1); //fire resist passive
				TF2Attrib_SetByDefIndex(item,506,0.4); //bullet resist deployed
				TF2Attrib_SetByDefIndex(item,507,0.4); //blast resist deployed
				TF2Attrib_SetByDefIndex(item,508,0.4); //fire resist deployed
			}
			//Darwin's Danger Shield
			case 231:
			{
				TF2Attrib_SetByDefIndex(item,26,15.0); //max health additive bonus
				TF2Attrib_SetByDefIndex(item,60,1.0); //fire resistance
				TF2Attrib_SetByDefIndex(item,527,0.0); //afterburn immunity
				// SetEntityHealth(iClient,140);
			}
			//The Diamondback
			case 525:
			{
				TF2Attrib_SetByDefIndex(item,296,0.0); //sapper kills collect crits
				TF2Attrib_SetByDefIndex(item,1,1.0); //damage penalty
				TF2Attrib_SetByDefIndex(item,3,0.67); //clip size penalty
				int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
				SetEntData(item, iAmmoTable, 4, _, true);
			}
			//Detonator
			case 351:
			{
				TF2Attrib_SetByDefIndex(item,207,1.2); //self blast damge increased
				TF2Attrib_SetByDefIndex(item,74,0.66); //weapon burn time reduced
			}
			//Short Circuit
			case 528:
			{
				TF2Attrib_SetByDefIndex(item,2,2.0); //damage bonus
				TF2Attrib_SetByDefIndex(item,614,1.0); //no metal from dispensers while active
			}
			//Buff Banner
			case 129,1001:
			{
				TF2Attrib_SetByDefIndex(item,76,1.5); //maxammo primary increased
			}
			//Scorch Shot
			case 740:
			{
				TF2Attrib_SetByDefIndex(item,1,0.75); //damage penalty
				// TF2Attrib_SetByDefIndex(item,59,1.0); //self dmg push force decreased
				TF2Attrib_SetByDefIndex(item,74,0.66); //weapon burn time reduced
			}
			//The Manmelter
			case 595:
			{
				TF2Attrib_SetByDefIndex(item,2,1.2); //damage bonus
				TF2Attrib_SetByDefIndex(item,367,1.0); //extinguish earns revenge crits
			}
			//Quick-Fix
			case 411:
			{
				TF2Attrib_SetByDefIndex(item,144,2.0); //set_weapon_mode
			}
			//Flying Guillotine
			case 812,833:
			{
				float time = 2.0;
				if(g_bIsMVM) //mvm time
				{
					Address addr = TF2Attrib_GetByName(item, "melee range multiplier");
					if(addr != Address_Null)
					{
						float value = TF2Attrib_GetValue(addr);
						time *= value;
					}
				}
				TF2Attrib_SetByDefIndex(item,278,time); //mult_item_meter_charge_rate
			}
			//The Mantreads
			case 444:
			{
				//
			}
			//The Winger
			case 449:
			{
				TF2Attrib_SetByDefIndex(item,3,0.5); //clip size penalty
				int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
				SetEntData(item, iAmmoTable, 6, _, true);
			}

			//MELEES
			//The Eyelander
			case 132,266,482,1082:
			{
				TF2Attrib_SetByDefIndex(item,736,2.1); //speed boost on kill
				TF2Attrib_SetByDefIndex(item,781,1.0); //is_a_sword
				TF2Attrib_SetByDefIndex(item,125,-15.0); //max health additive penalty
				RequestFrame(updateHeads,iClient);
			}
			//Boston Basher
			case 325:
			{
				//
			}
			//Sun-On-A-Stick
			case 349:
			{
				TF2Attrib_SetByDefIndex(item,1,0.8); //damage penalty
				TF2Attrib_SetByDefIndex(item,794,1.0); //dmg taken from fire reduced on active
				SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",0.0,2); //set SOAS HEAT meter
			}
			//Southern Hospitality
			case 155:
			{
				TF2Attrib_SetByDefIndex(item,61,1.0); //dmg taken from fire increased
				TF2Attrib_SetByDefIndex(item,2043,0.8); //upgrade rate decrease
			}
			//Claidheamh Mor
			case 327:
			{
				TF2Attrib_SetByDefIndex(item,5,1.2); //fire rate penalty
				TF2Attrib_SetByDefIndex(item,199,1/1.75); //holster speed bonus
				TF2Attrib_SetByDefIndex(item,412,1.0); //dmg taken increased
				TF2Attrib_SetByDefIndex(item,781,1.0); //is_a_sword
			}
			//Persian Persuader
			case 404:
			{
				TF2Attrib_SetByDefIndex(item,77,0.5); //maxammo primary reduced
				TF2Attrib_SetByDefIndex(item,79,0.5); //maxammo secondary reduced
				TF2Attrib_SetByDefIndex(item,781,1.0); //is_a_sword
			}
			//The Ubersaw
			case 37,1003:
			{
				TF2Attrib_SetByDefIndex(item,547,0.8); //deploy speed bonus
				TF2Attrib_SetByDefIndex(item,852,1.25); //mult_dmgtaken_active
			}
			//The Axtinguisher
			case 38,1000:
			{
				g_holsterMel[iClient] = 1.35;
				TF2Attrib_SetByDefIndex(item,772,1.0); //single wep holster time increased
			}
			//Ullapool Caber
			case 307:
			{
				TF2Attrib_SetByDefIndex(item,773,1.6); //deploy time increased
			}
			//Neon Annihilator
			case 813, 834:
			{
				TF2Attrib_SetByDefIndex(item,146,0.0); //damage applies to sappers
				TF2Attrib_SetByDefIndex(item,773,1.6); //deploy time increased
				SetEntPropFloat(item, Prop_Send, "m_flLastFireTime",GetGameTime());
			}
			//Disciplinary Action
			case 447:
			{
				TF2Attrib_SetByDefIndex(item,135,1.25); //rocket jump damage reduction
			}
			//Atomizer
			case 450:
			{
				TF2Attrib_SetByDefIndex(item,138,1.0); //damage penalty vs players
				TF2Attrib_SetByDefIndex(item,773,1.0); //single wep deploy time increased
				g_holsterMel[iClient] = 1.6;
				TF2Attrib_SetByDefIndex(item,772,1.0); //single wep holster time increased
			}
			//The Vita-Saw
			case 173:
			{
				TF2Attrib_SetByDefIndex(item,811,0.001); //ubercharge_preserved
				TF2Attrib_SetByDefIndex(item,125,0.0); //max health additive penalty
				TF2Attrib_SetByDefIndex(item,7,0.85); //heal rate penalty
				TF2Attrib_SetByDefIndex(item,1,0.67); //damage penalty
				TF2Attrib_SetByDefIndex(item,263,1.5); //melee_bounds_multiplier
				if(GetClientHealth(iClient)<150)
					SetEntityHealth(iClient,150);
				g_meterMel[iClient] = GetEntProp(iClient, Prop_Send, "m_iHealPoints")+0.0;
			}
			//Warrior's Spirit
			case 310:
			{
				TF2Attrib_SetByDefIndex(item,180,60.0); //heal on kill
				TF2Attrib_SetByDefIndex(item,412,1.0); //dmg taken increased
			}
			//Half-Zatoichi
			case 357:
			{
				TF2Attrib_SetByDefIndex(item,781,1.0); //is_a_sword
			}
			//Solemn Vow
			case 413:
			{
				TF2Attrib_SetByDefIndex(item,5,1.0); //fire rate penalty
				TF2Attrib_SetByDefIndex(item,851,0.9); //mult_player_movespeed_active
			}
			//Tribalman's shiv
			case 171:
			{
				TF2Attrib_SetByDefIndex(item,149,8.0); //bleeding duration
				TF2Attrib_SetByDefIndex(item,877,2.0); //speed boost on hit enemy
				TF2Attrib_SetByDefIndex(item,797,1.0); //dmg pierces resists absorbs
			}
			//Killing Gloves of Boxing
			case 43:
			{
				//
			}
			//Your Eternal Reward
			case 225,574:
			{
				TF2Attrib_SetByDefIndex(item,34,1.0); //cloak drain penalty
			}
			//Conniver's Kunai
			case 356:
			{
				TF2Attrib_SetByDefIndex(item,217,0.0); //sanguisuge
				TF2Attrib_SetByDefIndex(item,125,-40.0); //max health additive penalty
				TF2Attrib_SetByDefIndex(item,109,0.5); //health from packs decreased
			}
			//The Spy-cicle
			case 649:
			{
				TF2Attrib_SetByDefIndex(item,359,0.0); //melts in fire
				TF2Attrib_SetByDefIndex(item,361,0.0); //become fireproof on hit by fire
				SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",100.0,2); //durability meter
				SetEntPropFloat(item, Prop_Send, "m_flLastFireTime",GetGameTime());
			}
			//The Equalizer
			case 128:
			{
				TF2Attrib_SetByDefIndex(item,224,1.4); //increase damage below 50% HP
				TF2Attrib_SetByDefIndex(item,225,0.6); //decrease damage above 50% HP
			}
			//Eviction Notice
			case 426:
			{
				TF2Attrib_SetByDefIndex(item,128,1.0); //provide while active
				TF2Attrib_SetByDefIndex(item,1,0.5); //damage penalty
				TF2Attrib_SetByDefIndex(item,855,0.0); //max health drain
				TF2Attrib_SetByDefIndex(item,852,1.25); //mult_dmgtaken_active
				TF2Attrib_SetByDefIndex(item,547,0.8); //deploy speed bonus
			}
			//The Sandman
			case 44:
			{
				TF2Attrib_SetByDefIndex(item,278,1.0); //effect bar recharge rate
			}
			//Candy Cane
			case 317:
			{
				TF2Attrib_SetByDefIndex(item,65,1.0); //dmg taken from blast increased
				TF2Attrib_SetByDefIndex(item,77,0.5); //maxammo primary reduced
				// TF2Attrib_SetByDefIndex(item,67,1.25); //dmg taken from bullet increased
			}
			//Fan O'War
			case 355:
			{
				TF2Attrib_SetByDefIndex(item,199,0.75); //holster speed bonus
			}
			//Sharpened Volcano Fragment
			case 348:
			{
				TF2Attrib_SetByDefIndex(item,199,0.8); //holster speed bonus
				// TF2Attrib_SetByDefIndex(item,208,1.0); //Set DamageType Ignite
				// TF2Attrib_SetByDefIndex(item,1,1.0); //damage penalty
				// TF2Attrib_SetByDefIndex(item,21,0.8); //damage penalty vs non-burning players
			}
			//Hot Hand
			case 1181:
			{
				// TF2Attrib_SetByDefIndex(item,1,1.0); //damage penalty
			}
			//Third Degree
			case 593:
			{
				TF2Attrib_SetByDefIndex(item,1,0.85); //damage penalty
				TF2Attrib_SetByDefIndex(item,5,1.2); //fire rate penalty
				TF2Attrib_SetByDefIndex(item,360,0.0); //damage all connected
				TF2Attrib_SetByDefIndex(item,547,0.8); //deploy speed bonus
			}
			//The Shahanshah
			case 401:
			{
				TF2Attrib_SetByDefIndex(item,547,0.75); //deploy speed bonus
			}
			//The Jag
			case 329:
			{
				TF2Attrib_SetByDefIndex(item,95,0.67); //repair rate decreased
			}
			//Gloves of Running Urgently
			case 239,1084,1100:
			{
				g_holsterMel[iClient] = 1.5;
				TF2Attrib_SetByDefIndex(item,772,1.0); //single wep holster time increased
			}
			//Fists of Steel
			case 331:
			{
				g_holsterMel[iClient] = 2.0;
				TF2Attrib_SetByDefIndex(item,772,1.0); //single wep holster time increased
				TF2Attrib_SetByDefIndex(item,853,1.0); //mult_patient_overheal_penalty_active
				TF2Attrib_SetByDefIndex(item,800,0.6); //patient overheal penalty
				TF2Attrib_SetByDefIndex(item,239,1.0); //ubercharge rate bonus for healer
			}
			//The Homewrecker
			case 153,466:
			{
				TF2Attrib_SetByDefIndex(item,128,1.0); //provide while active
				TF2Attrib_SetByDefIndex(item,205,0.8); //damage from range
				TF2Attrib_SetByDefIndex(item,252,0.5); //damage force reduction
			}
			//The Amputator
			case 304:
			{
				TF2Attrib_SetByDefIndex(item,1,0.75); //damage penalty
				// TF2Attrib_SetByDefIndex(item,57,0.0); //health regen
			}
			//Pain Train
			case 154:
			{
				TF2Attrib_SetByDefIndex(item,412,1.1); //dmg taken increased
				TF2Attrib_SetByDefIndex(item,67,1.0); //dmg taken from bullets increased
			}
			//Holiday Punch
			case 656:
			{
				TF2Attrib_SetByDefIndex(item,1,0.85); //damage penalty
				TF2Attrib_SetByDefIndex(item,6,0.8); //fire rate bonus
			}
			//Scotsman's skullcutter
			case 172:
			{
				g_consecHits[iClient] = 0; //allow random crits
				if(IsValidEdict(secondary))
				{
					int secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
					switch(secondaryIndex)
					{
						//screen
						case 59: TF2Attrib_SetByDefIndex(secondary,249,1.5*1.2); //shield recharge rate
						//targe, turner
						case 131,1099,1144: TF2Attrib_SetByDefIndex(secondary,249,1.2); //shield recharge rate
					}
				}
			}
			//The Bushwacka
			case 232:
			{
				TF2Attrib_SetByDefIndex(item,218,1.0); //mark for death
				TF2Attrib_SetByDefIndex(item,773,1.3); //deploy time increased
			}

			//MISCS
			//Dead Ringer
			case 59:
			{
				TF2Attrib_SetByDefIndex(item,35,1.25); //mult cloak meter regen rate
				TF2Attrib_SetByDefIndex(item,83,1.0); //cloak consume rate decreased
				TF2Attrib_SetByDefIndex(item,726,0.0); //cloak_consume_on_feign_death_activate
			}
			//Cloak and Dagger
			case 60:
			{
				TF2Attrib_SetByDefIndex(item,83,0.825); //cloak consume rate decreased
				TF2Attrib_SetByDefIndex(item,253,-0.1); //mult cloak rate
			}
			//Red-Tape Recorder
			case 810, 831:
			{
				TF2Attrib_SetByDefIndex(item,429,0.5); //sapper health penalty
			}
		}
	}
}

public Action Event_PlayerDeath(Event event, const char[] cName, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	int victim = event.GetInt("victim_entindex");
	int weaponIndex = event.GetInt("weapon_def_index");
	int customKill = event.GetInt("customkill"); // 25=defensive sticky, airburst sticky, standard sticky
	int inflict = event.GetInt("inflictor_entindex");
	int victimMelee = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Melee, true);
	int victimMeleeIndex = -1;
	if(victimMelee >= 0) victimMeleeIndex = GetEntProp(victimMelee, Prop_Send, "m_iItemDefinitionIndex");

	g_flameDamage[victim] = 0.0;
	g_flameAttacker[victim] = 0;

	if(IsValidClient(attacker))
	{
		if(customKill!=TF_CUSTOM_DEFENSIVE_STICKY && customKill!=TF_CUSTOM_AIR_STICKY_BURST && customKill!=TF_CUSTOM_STANDARD_STICKY)
		{
			int primary = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Primary, true);
			int primaryIndex = -1;
			if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
			int secondary = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Secondary, true);
			int secondaryIndex = -1;
			if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
			int melee = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Melee, true);
			int meleeIndex = -1;
			if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");

			//credit "finished off" and shield kills with on-kill bonuses
			if(attacker != inflict)
			{
				if(inflict == -1)//finished off
				{
					// has booties?
					float addCharge = 0.0;
					if(weaponIndex == meleeIndex && (primaryIndex == 405 || primaryIndex == 608)) addCharge += 25; //add booties on-kill
					if(weaponIndex == meleeIndex && secondaryIndex == 1099) addCharge += 75; //add tide turner on-kill

					switch(weaponIndex)
					{
						case 317: //candy cane
						{
							//to be done
						}
						case 1104: //air strike
						{
							int heads = GetEntProp(attacker, Prop_Send, "m_iDecapitations");
							int vicheads = GetEntProp(victim, Prop_Send, "m_iDecapitations");
							SetEntProp(attacker, Prop_Send, "m_iDecapitations",heads+1+vicheads);
						}
						case 38,1000: //axtinguisher
						{
							TF2_AddCondition(attacker,TFCond_SpeedBuffAlly,3.1);
						}
						case 214: //powerjack
						{
							SetHudTextParams(0.1, -0.16, 0.1, 255, 255, 255, 255);
							ShowHudText(attacker,4,"+25 HP");
							TF2Util_TakeHealth(attacker,25.0);
						}
						case 132,266,482,1082: //eyelander
						{
							int heads = GetEntProp(attacker, Prop_Send, "m_iDecapitations");
							int vicheads = GetEntProp(victim, Prop_Send, "m_iDecapitations");
							SetEntProp(attacker, Prop_Send, "m_iDecapitations",heads+1+vicheads);
							RequestFrame(updateHeads,attacker);
							TF2_AddCondition(attacker,TFCond_SpeedBuffAlly,2.1);
						}
						case 357: //half-zatoichi
						{
							int maxHealth = 200;
							if(TF2_GetPlayerClass(attacker)==TFClass_DemoMan && primaryIndex != 405 && primaryIndex != 608)
								maxHealth = 175;
							else if(TF2_GetPlayerClass(attacker)==TFClass_Soldier && secondaryIndex == 226)
								maxHealth = 220;
							int currHealth = GetClientHealth(attacker);

							float healing = maxHealth/2+currHealth > maxHealth*1.5 ? maxHealth*1.5-currHealth : maxHealth/2.0;
							SetHudTextParams(0.1, -0.16, 0.1, 255, 255, 255, 255);
							ShowHudText(attacker,4,"+%.0f HP",healing);
							TF2Util_TakeHealth(attacker,healing,TAKEHEALTH_IGNORE_MAXHEALTH);
							int kills = GetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy");
							SetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy",kills+1);
						}
						case 327: //claidheamh mor
						{
							addCharge += 25;
							bool replenished = false;
							//check ammo to be replenished
							if(primaryIndex!=405 && primaryIndex!=608 && primaryIndex!=1101)
							{
								int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
								int clip = GetEntData(primary, iAmmoTable, 4);
								int maxClip = primaryIndex==308 ? 2 : 4;
								int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
								int ammoCount = GetEntProp(attacker, Prop_Data, "m_iAmmo", _, primaryAmmo);
								if(ammoCount>0 && clip<maxClip)
								{
									replenished = true;
									SetEntData(primary, iAmmoTable, ammoCount<maxClip-clip ? ammoCount : maxClip, _, true);
									SetEntProp(attacker, Prop_Data, "m_iAmmo", ammoCount<maxClip-clip ? 0 : ammoCount-maxClip+clip, _,primaryAmmo);
								}
							}
							if(replenished) EmitSoundToClient(attacker,"items/ammo_pickup.wav");
						}
						case 43: //KGB
						{
							TF2_AddCondition(attacker,TFCond_CritOnKill,6.0);
						}
						case 310: //warrior's spirit
						{
							SetHudTextParams(0.1, -0.16, 0.1, 255, 255, 255, 255);
							ShowHudText(attacker,4,"+60 HP");
							TF2Util_TakeHealth(attacker,60.0);
							int kills = GetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy");
							SetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy",kills+1);
						}
						case 141,1004: //frontier justice
						{
							//to be done
						}
						case 171: //tribalman's shiv
						{
							TF2_AddCondition(attacker,TFCond_SpeedBuffAlly,2.1);
						}
						case 461: //big earner
						{
							TF2_AddCondition(attacker,TFCond_SpeedBuffAlly,3.1);
						}
						case 1103: //back scatter on-kill
						{
							int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
							int clip = GetEntData(primary, iAmmoTable, 4);
							int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
							int ammoCount = GetEntProp(attacker, Prop_Data, "m_iAmmo", _, primaryAmmo);
							int max = 4;
							if(g_bIsMVM)
							{
								Address addr = TF2Attrib_GetByName(primary, "clip size bonus");
								if(addr != Address_Null)
								{
									float value = TF2Attrib_GetValue(addr);
									max = RoundFloat(max * value);
								}
							}
							if(ammoCount>0)
							{
								int amount = ammoCount > 1 && clip <= (max + 3) ? 2 : 1;
								EmitSoundToClient(attacker,"items/ammo_pickup.wav");
								SetEntData(primary, iAmmoTable, clip+amount, _, true);
								SetEntProp(attacker, Prop_Data, "m_iAmmo", ammoCount-amount, _,primaryAmmo);
							}
						}
						case 460: //enforcer disguise on kill
						{
							RequestFrame(SetDisguise,attacker);
						}
						case 939: //spooky skeleton
						{
							if(IS_HALLOWEEN) RequestFrame(SpawnSpooky,victim);
						}
					}

					if(addCharge>0)
					{
						float meter = GetEntPropFloat(attacker, Prop_Send,"m_flChargeMeter");
						if(meter+addCharge > 100) meter = 100.0;
						else meter+=addCharge;

						DataPack pack = new DataPack();
						pack.Reset();
						pack.WriteCell(attacker);
						pack.WriteFloat(meter);
						RequestFrame(updateShield,pack);
					}
				}
				else if(inflict == secondary) //shield bash kills
				{
					float addCharge = 0.0;
					if(primaryIndex == 405 || primaryIndex == 608) addCharge += 25; //add booties on-kill
					if(secondaryIndex == 1099) addCharge += 75; //add tide turner on-kill
					if(meleeIndex == 327) addCharge += 25; //add claid on-kill
					if(meleeIndex==132 || meleeIndex==266 || meleeIndex==482 || meleeIndex==1082) //eyelander on-kill
					{
						int heads = GetEntProp(attacker, Prop_Send, "m_iDecapitations");
						int vicheads = GetEntProp(victim, Prop_Send, "m_iDecapitations");
						SetEntProp(attacker, Prop_Send, "m_iDecapitations",heads+1+vicheads);
						RequestFrame(updateHeads,attacker);
						TF2_AddCondition(attacker,TFCond_SpeedBuffAlly,2.1);
					}
					if(meleeIndex==357) //half-zatoichi on-kill
					{
						int maxHealth = 200;
						if(TF2_GetPlayerClass(attacker)==TFClass_DemoMan && primaryIndex != 405 && primaryIndex != 608)
							maxHealth = 175;
						else if(TF2_GetPlayerClass(attacker)==TFClass_Soldier && secondaryIndex == 226)
							maxHealth = 220;
						int currHealth = GetClientHealth(attacker);

						float healing = maxHealth/2+currHealth > maxHealth*1.5 ? maxHealth*1.5-currHealth : maxHealth/2.0;
						SetHudTextParams(0.1, -0.16, 0.1, 255, 255, 255, 255);
						ShowHudText(attacker,4,"+%.0f HP",healing);
						TF2Util_TakeHealth(attacker,healing,TAKEHEALTH_IGNORE_MAXHEALTH);
						int kills = GetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy");
						SetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy",kills+1);
					}

					if(addCharge>100) addCharge = 100.0; 
					
					DataPack pack = new DataPack();
					pack.Reset();
					pack.WriteCell(attacker);
					pack.WriteFloat(addCharge);
					RequestFrame(updateShield,pack);
				}
			}

			switch(secondaryIndex)
			{
				case 58,1083,1105: //jarate recharges on kill
				{
					float secondaryLast = GetEntPropFloat(secondary, Prop_Send, "m_flLastFireTime");
					SetEntPropFloat(secondary, Prop_Send, "m_flLastFireTime", secondaryLast-8);
					float secondaryRegen = GetEntPropFloat(secondary, Prop_Send, "m_flEffectBarRegenTime");
					SetEntPropFloat(secondary, Prop_Send, "m_flEffectBarRegenTime", secondaryRegen-8);
				}
				case 751: //carbine recharges on kill
				{
					if(weaponIndex == secondaryIndex && !TF2_IsPlayerInCondition(attacker,TFCond_CritCola))
					{
						float secondaryRegen = GetEntPropFloat(secondary, Prop_Send, "m_flMinicritCharge");
						SetEntPropFloat(secondary, Prop_Send, "m_flMinicritCharge", secondaryRegen+20.0);
					}
				}
			}

			//diamondback, minicrits on kill
			if(TFClass_Spy==TF2_GetPlayerClass(attacker) && weaponIndex == meleeIndex && secondaryIndex==525)
			{
				float time = 5.1;
				if(g_bIsMVM) //add mvm crits on kill
				{
					Address addr = TF2Attrib_GetByName(melee, "critboost on kill");
					if(addr != Address_Null)
					{
						float value = TF2Attrib_GetValue(addr);
						time += value;
					}
				}
				TF2_AddCondition(attacker,TFCond_CritCola,time);
			}
			
			switch(weaponIndex)
			{
				case 811,832: //Heater explode on kill
				{
					if (attacker!=victim)
					{
						g_condFlags[victim] |= TF_CONDFLAG_HEATER;
						float victimPos[3];
						GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
						EmitAmbientSound("misc/halloween/spell_fireball_impact.wav",victimPos,victim);
						CreateParticle(victim,"ExplosionCore_MidAir_Flare",5.0,_,_,_,_,100.0,1.5,false);
						CreateParticle(victim,"heavy_ring_of_fire",2.0,_,_,_,_,5.0,_,false,false);

						DataPack pack = new DataPack();
						pack.Reset();
						pack.WriteCell(attacker);
						pack.WriteCell(victim);
						CreateTimer(0.015,updateRing,pack);
						CreateTimer(0.135,updateRing,pack);
						CreateTimer(0.255,updateRing,pack);
					}
				}
				case 132,266,482,1082: //eyelander
				{
					RequestFrame(updateHeads,attacker);
				}
				case 356: //Kunai health on kill
				{
					if(customKill == TF_CUSTOM_BACKSTAB)
					{
						// Address addr = TF2Attrib_GetByDefIndex(melee,125);
						float maxHP = RoundToFloor(g_meterMel[attacker])+0.0;
						//increase max HP by +45 up to +90
						maxHP = maxHP + 45.0 > 90.0 ? 90.0 : maxHP + 45.0;
						//heal 45 HP
						float currHP = GetClientHealth(attacker)+0.0;
						float health = currHP + 60 > (maxHP+85)*1.5 ? (maxHP+85)*1.5 - currHP : 60.0;
						TF2Attrib_SetByDefIndex(melee,125,-40+maxHP); //max health additive penalty
						g_meterMel[attacker] = maxHP;

						SetHudTextParams(0.1, -0.16, 0.2, 255, 255, 255, 255);
						ShowHudText(attacker,4,"+%.0f HP",health);
						TF2Util_TakeHealth(attacker,health,TAKEHEALTH_IGNORE_MAXHEALTH);
						
					}
				}
				case 649: //Spy-Cicle on kill
				{
					if(customKill == TF_CUSTOM_BACKSTAB)
					{
						float meter = GetEntPropFloat(attacker, Prop_Send,"m_flItemChargeMeter",2); //durability meter
						if (meter-67 > 0)
							SetEntPropFloat(attacker, Prop_Send,"m_flItemChargeMeter",meter-67.0,2);
						else
							MeltKnife(attacker,melee,15.0);
					}
				}
				case 1103: //back scatter on-kill
				{
					int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
					int clip = GetEntData(primary, iAmmoTable, 4);
					int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
					int ammoCount = GetEntProp(attacker, Prop_Data, "m_iAmmo", _, primaryAmmo);
					int max = 4;
					if(g_bIsMVM)
					{
						Address addr = TF2Attrib_GetByName(primary, "clip size bonus");
						if(addr != Address_Null)
						{
							float value = TF2Attrib_GetValue(addr);
							max = RoundFloat(max * value);
						}
					}
					if(ammoCount>0)
					{
						int amount = ammoCount > 1 && clip <= (max + 3) ? 2 : 1;
						EmitSoundToClient(attacker,"items/ammo_pickup.wav");
						SetEntData(primary, iAmmoTable, clip+amount, _, true);
						SetEntProp(attacker, Prop_Data, "m_iAmmo", ammoCount-amount, _,primaryAmmo);
					}
				}
				case 327: //claidheamh mor on-kill
				{
					bool replenished = false;
					//check ammo to be replenished
					if(primaryIndex!=405 && primaryIndex!=608 && primaryIndex!=1101)
					{
						int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
						int clip = GetEntData(primary, iAmmoTable, 4);
						int maxClip = primaryIndex==308 ? 2 : 4;
						int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
						int ammoCount = GetEntProp(attacker, Prop_Data, "m_iAmmo", _, primaryAmmo);
						if(ammoCount>0 && clip<maxClip)
						{
							replenished = true;
							SetEntData(primary, iAmmoTable, ammoCount<maxClip-clip ? ammoCount : maxClip, _, true);
							SetEntProp(attacker, Prop_Data, "m_iAmmo", ammoCount<maxClip-clip ? 0 : ammoCount-maxClip+clip, _,primaryAmmo);
						}
					}
					if(replenished) EmitSoundToClient(attacker,"items/ammo_pickup.wav");
				}
				case 460: //enforcer disguise on kill
				{
					RequestFrame(SetDisguise,attacker);
				}
				case 307: //caber, fix on-kill for explosive
				{
					if(customKill==42) //42 for explosion kill
					{
						//fulfill melee kill bonuses
						float addCharge = 0.0;
						if(primaryIndex == 405 || primaryIndex == 608) addCharge += 25; //add booties on-kill
						if(secondaryIndex == 1099) addCharge += 75; //add tide turner on-kill
						float meter = GetEntPropFloat(attacker, Prop_Send,"m_flChargeMeter");
						if(meter+addCharge > 100) meter = 100.0;
						else meter+=addCharge;

						DataPack pack = new DataPack();
						pack.Reset();
						pack.WriteCell(attacker);
						pack.WriteFloat(meter);
						RequestFrame(updateShield,pack);
					}
				}
				case 939: //spooky skeleton
				{
					if((IS_HALLOWEEN) && attacker!=victim) RequestFrame(SpawnSpooky,victim);
				}
			}

			if(victimMeleeIndex==939 && attacker!=victim) //bat outta hell
			{
				if(IS_HALLOWEEN) RequestFrame(SpawnSpooky,victim);
			}

			switch(meleeIndex)
			{
				case 355:
				{
					//marked speed buff for Fan O'War
					if(TF2Util_GetPlayerConditionProvider(victim,TFCond_MarkedForDeath)==attacker)
					{
						TF2_AddCondition(attacker,TFCond_SpeedBuffAlly,3.1);
					}
				}
				case 154:
				{
					//speed boost for killing user on objective Pain Train
					if(g_condFlags[victim] & TF_CONDFLAG_CAPPING)
					{
						TF2_AddCondition(attacker,TFCond_SpeedBuffAlly,3.1);
					}
				}
			}
			switch(secondaryIndex)
			{
				case 812,833: //Flying Guillotine recharge on kill
				{
					// float time = GetGameTime();
					float regen = GetEntPropFloat(secondary,Prop_Send,"m_flEffectBarRegenTime");
					if(regen-GetGameTime()>0)
					{
						g_meterSec[attacker] = regen-5.0;
						SetEntPropFloat(secondary,Prop_Send,"m_flEffectBarRegenTime",regen-5.0);
						SetEntPropFloat(secondary,Prop_Send,"m_flLastFireTime",regen-10.0);
						RequestFrame(FlushCleaver,attacker);
					}
				}
			}

			if(TF2_GetPlayerClass(attacker)==TFClass_Heavy && secondaryIndex==311)
			{
				//increase steak duration on kill
				float dur = TF2Util_GetPlayerConditionDuration(attacker,TFCond_CritCola);
				if(dur>0)
				{
					TF2Util_SetPlayerConditionDuration(attacker,TFCond_CritCola,dur+2);
					TF2Util_SetPlayerConditionDuration(attacker,TFCond_RestrictToMelee,dur+2);
				}
			}
			
			if(TF2_GetPlayerClass(attacker)==TFClass_Scout)
			{
				switch(meleeIndex)
				{
					case 349: //Sun-on-a-stick fill HEAT on kill
					{
						g_meterMel[attacker] = 100.0;
						SetEntPropFloat(attacker, Prop_Send,"m_flItemChargeMeter",100.0,2);

						if(TF2Util_GetPlayerBurnDuration(victim)>0.0 && TF2Util_GetPlayerConditionProvider(victim,TFCond_OnFire)==attacker) //auto activate HEAT
						{
							float position[3];
							GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", position);

							g_condFlags[attacker] |= TF_CONDFLAG_HEAT;
							EmitAmbientSound("misc/flame_engulf.wav",position,attacker);
							CreateParticle(attacker,"heavy_ring_of_fire",2.0,_,_,_,_,5.0,_,false,false);
						}
					}
					case 325: //Boston Basher On-Kill
					{
						if(attacker!=victim && TF2Util_GetPlayerConditionProvider(victim,TFCond_Bleeding)==attacker) //if killing target you inflicted bleed on, clean debuffs
						{
							DataPack pack = new DataPack();
							pack.Reset();
							pack.WriteCell(attacker);
							pack.WriteCell(1);
							RequestFrame(CleanDOT,pack);
						}
					}
					// case 317: //candy cane, no ammo spawn
					// {
					// 	g_spawnHealth[victim] = attacker;
					// }
				}
			}
			else if(TF2_GetPlayerClass(attacker)==TFClass_Soldier)
			{
				if(secondaryIndex==444 && g_condFlags[attacker] & TF_CONDFLAG_DIVE) //mantreads reload rocket while jumping
				{
					if(primaryIndex == 441)
					{
						float max = 15.0;
						float clip = GetEntPropFloat(primary, Prop_Send, "m_flEnergy");
						if(clip<max)
						{
							SetEntPropFloat(primary, Prop_Send, "m_flEnergy", clip+5.0);
						}
					}
					else
					{
						int max = primaryIndex == 414 ? 5 : 4;
						if(primaryIndex==1104)
						{
							int heads = GetEntProp(attacker, Prop_Send, "m_iDecapitations");
							max += heads>4 ? 4 : heads;
						}
						int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
						int clip = GetEntData(primary, iAmmoTable, 4);
						int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
						int ammoCount = GetEntProp(attacker, Prop_Data, "m_iAmmo", _, primaryAmmo);
						if(clip<max && ammoCount>0)
						{
							SetEntData(primary, iAmmoTable, clip+1, _, true);
							SetEntProp(attacker, Prop_Data, "m_iAmmo", ammoCount-1, _,primaryAmmo);
							EmitSoundToClient(attacker,"weapons/rocket_reload.wav");
						}
					}
				}
			}

			if(g_condFlags[victim] & TF_CONDFLAG_BONK)
			{
				//sandman refill ball on kill
				if(RoundFloat(g_bonkedDebuff[victim][0])==attacker && meleeIndex==44)
				{
					SetEntPropFloat(melee,Prop_Send,"m_flEffectBarRegenTime",GetGameTime());
				}
			}
		}
	}

	if(victimMeleeIndex==348)
	{
		//extinguish enemies ignited by user of Volcano Fragment
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				if(TF2Util_GetPlayerConditionProvider(i,TFCond_OnFire)==victim || TF2Util_GetPlayerConditionProvider(i,TFCond_BurningPyro)==victim)
				{
					g_condFlags[victim] &= ~TF_CONDFLAG_VOLCANO;
					ExtinguishEnemy(i);
				}
			}
		}
	}
	
	if(g_condFlags[victim] & TF_CONDFLAG_VOLCANO) //sharpened volcano, if player hit while burning dies they explode
	{
		int burner = TF2Util_GetPlayerConditionProvider(victim,TFCond_OnFire);
		float targetPos[3], victimPos[3];
		GetClientEyePosition(victim, victimPos);
		EmitAmbientSound("misc/halloween/spell_fireball_impact.wav",victimPos,victim);
		CreateParticle(victim,"ExplosionCore_MidAir_Flare",5.0,_,_,_,_,100.0,1.5,false);
		int burnerHP = GetClientHealth(burner);
		TF2Util_TakeHealth(burner,burnerHP+40>260?260.0-burnerHP:40.0,TAKEHEALTH_IGNORE_MAXHEALTH);//heal user
		for (int i = 1 ; i <= MaxClients ; i++)
		{
			if(IsValidClient(i,false))
			{
				GetClientEyePosition(i, targetPos);
				float dist = GetVectorDistance(victimPos,targetPos);
				if(victim != i && dist<=170 && TF2_GetClientTeam(i) != TF2_GetClientTeam(burner) &&
				   !TF2_IsPlayerInCondition(i,TFCond_Ubercharged) && !TF2_IsPlayerInCondition(i,TFCond_UberchargeFading) && !TF2_IsPlayerInCondition(i,TFCond_UberchargedCanteen))
				{
					bool hit = false;
					Handle hndl = TR_TraceRayFilterEx(targetPos, victimPos, MASK_SOLID, RayType_EndPoint, TraceFilter, i);
					if(TR_DidHit() == false)
						hit = true;
					else
					{
						int vic = TR_GetEntityIndex(hndl);
						char[] class = new char[64];
						if(IsValidEdict(vic)) GetEdictClassname(vic, class, 64);
						
						if(StrEqual(class,"func_respawnroomvisualizer") || !IsValidEdict(vic))
							hit = true;	
					}
					if(hit)
					{
						DataPack pack = new DataPack();
						pack.Reset();
						pack.WriteCell(i);
						pack.WriteCell(burner);
						RequestFrame(VolcanoBurst,pack);
					}
				}
			}
		}
		g_condFlags[victim] &= ~TF_CONDFLAG_VOLCANO;
	}

	if(g_condFlags[victim] & TF_CONDFLAG_BONK) //clear BONKED debuff
	{
		g_condFlags[victim] &= ~TF_CONDFLAG_BONK;
	}
	
	return Plugin_Continue;
}

public Action Event_BuildObject(Event event, const char[] cName, bool dontBroadcast)
{
	int user = GetClientOfUserId(GetEventInt(event, "userid"));
	int building = GetClientOfUserId(GetEventInt(event, "index"));
	if(IsValidClient(user))
	{
		TFClassType class = TF2_GetPlayerClass(user);
		switch(class)
		{
			case TFClass_Spy:
			{
				int sapper = TF2Util_GetPlayerLoadoutEntity(user, TFWeaponSlot_Building, true);
				int sapperIndex = -1;
				if(sapper != -1) sapperIndex = GetEntProp(sapper, Prop_Send, "m_iItemDefinitionIndex");
				//Red-Tape Recorder speed boost
				if(sapperIndex==810||sapperIndex==831)
				{
					g_sapperTime[building] = 3.0;
					TF2_AddCondition(user,TFCond_SpeedBuffAlly,3.1);
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_FlagEvent(Event event, const char[] cName, bool dontBroadcast)
{
	int player = GetEventInt(event, "player");
	int type = GetEventInt(event, "eventtype");
	char[] mapName = new char[64];
	GetCurrentMap(mapName,64);
	
	if(IsValidClient(player) && (type==TF_FLAGEVENT_PICKEDUP || (type==TF_FLAGEVENT_DEFENDED) && StrContains(mapName, "pd_" , false) == -1))
	{
		int melee = TF2Util_GetPlayerLoadoutEntity(player, TFWeaponSlot_Melee, true);
		int meleeIndex = -1;
		if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");

		//Pain Train speed boost on pickup and defense (except pd)
		if(meleeIndex==154)
		{
			TF2_AddCondition(player,TFCond_SpeedBuffAlly,3.1);
		}
	}
	return Plugin_Continue;
}

public Action Event_BlockCapture(Event event, const char[] cName, bool dontBroadcast)
{
	int blocker = GetEventInt(event, "blocker");

	if(IsValidClient(blocker))
	{
		int melee = TF2Util_GetPlayerLoadoutEntity(blocker, TFWeaponSlot_Melee, true);
		int meleeIndex = -1;
		if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");

		//Pain Train speed boost on block
		if(meleeIndex==154)
		{
			TF2_AddCondition(blocker,TFCond_SpeedBuffAlly,3.1);
		}
	}
	return Plugin_Continue;
}

public Action Event_WaveComplete(Event event, const char[] cName, bool dontBroadcast)
{
	for(int i=1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			g_condFlags[i] &= ~TF_CONDFLAG_INSPAWN;
			g_condFlags[i] &= ~TF_CONDFLAG_UPGRADE;
			g_condFlags[i] &= ~TF_CONDFLAG_NOGRADE;
		}
	}
	return Plugin_Continue;
}

public Action Event_RoundWin(Event event, const char[] cName, bool dontBroadcast)
{
	int winners = GetEventInt(event, "team");
	int losers;
	if(winners == 2)
		losers = 3;
	else
		losers = 2;
	
	for(int i=1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(IsPlayerAlive(i) && GetClientTeam(i) == losers)
				g_condFlags[i] |= TF_CONDFLAG_LOSER;
		}
	}
	return Plugin_Continue;
}

public void OnGameFrame()
{
	//modify spookiness 
	// ConVar holiday = FindConVar("tf_forced_holiday");
	// switch(holiday.IntValue)
	// {
	// 	case 2: IS_HALLOWEEN=true;
	// 	default:
	// 	{
	// 		char[] mapName = new char[64];
	// 		GetCurrentMap(mapName,64);
	// 		if(!IsHalloweenMap(mapName))
	// 			IS_HALLOWEEN=false;
	// 	}
	// }
	//delete stray particles
	if(g_nextParticleCheck < GetGameTime())
	{
		for (int i=MaxClients; i < 2048; i++)
		{
			if(IsValidEdict(i))
			{
				char class[64];
				GetEntityClassname(i,class,64);
				if (StrEqual(class, "info_particle_system", false) && g_particles[i]==0)
				{
					AcceptEntityInput(i, "Stop");
					AcceptEntityInput(i, "Kill");
					RemoveEdict(i);
				}
			}
		}
		g_nextParticleCheck = GetGameTime()+1.0;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		int iClient = i;
		if (IsValidClient(i,false) && IsPlayerAlive(i))
		{
			int clientFlags = GetEntityFlags(iClient);
			int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
			int primaryIndex = -1;
			if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
			int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
			int secondaryIndex = -1;
			if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
			int melee = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Melee, true);
			int meleeIndex = -1;
			if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
			int sapper = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Building, true);
			int sapperIndex = -1;
			if(sapper >= 0) sapperIndex = GetEntProp(sapper, Prop_Send, "m_iItemDefinitionIndex");
			int current = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");

			if(GetGameTime() - g_lastFlamed[iClient] > 6.0/66 && g_temperature[iClient]>0.0) //client temperature from flamethrowers
			{
				g_temperature[iClient] -= 0.03; //22 frames to decrease to 0, 28 frames total including grace period
				if(g_temperature[iClient]<0.0) g_temperature[iClient] = 0.0;
			}

			if(g_condFlags[iClient] & TF_CONDFLAG_BONK) //sandman debuff
			{
				if(g_bonkedDebuff[iClient][1]>0) g_bonkedDebuff[iClient][1] -= 0.015;
				if(g_bonkedDebuff[iClient][1]<0)
				{
					g_bonkedDebuff[iClient][0] = 0.0;
					g_bonkedDebuff[iClient][1] = 0.0;
					g_condFlags[iClient] &= ~TF_CONDFLAG_BONK;
				}
				SetHudTextParams(0.1, -0.16, 2.0, 255, 255, 255, 255);
				ShowHudText(iClient,1,"⋆ BONKED!");
			}

			if(g_flameDamage[iClient]>0 && g_flameAttacker[iClient]>0 && g_flameAttacker[iClient]<=MaxClients)
			{
				if(IsValidClient(g_flameAttacker[iClient],false))
				{
					float flamepos[3];
					GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", flamepos);
					int pri = TF2Util_GetPlayerLoadoutEntity(g_flameAttacker[iClient], TFWeaponSlot_Primary, true);

					if(isMiniKritzed(iClient,g_flameAttacker[iClient]))
						TF2_AddCondition(iClient,TFCond_MarkedForDeathSilent,0.015);
					SDKHooks_TakeDamage(iClient, pri, g_flameAttacker[iClient], g_flameDamage[iClient], DMG_IGNITE|DMG_SONIC, pri, NULL_VECTOR, flamepos);
					g_flameDamage[iClient] = -0.075;
					g_flameAttacker[iClient] = 0;
				}
			}
			else if(g_flameDamage[iClient]<0)
			{
				g_flameDamage[iClient] += 0.015;
			}

			//count airtime until pyro can jetpack boost or demo leaps
			if(g_condFlags[iClient] & TF_CONDFLAG_HOVER)
			{
				if((clientFlags & FL_ONGROUND))
				{
					g_condFlags[iClient] &= ~TF_CONDFLAG_HOVER;
					TF2_RemoveCondition(iClient,TFCond_AirCurrent);
				}
			}
			//count airtime for BASE Jumper
			if(secondaryIndex == 1101 || primaryIndex == 1101)
			{
				if(TF2_IsPlayerInCondition(iClient,TFCond_Parachute))
				{
					int channel = secondaryIndex == 1101 ? 3 : 2;
					g_meterSec[iClient] += 1.0/66;
					SetHudTextParams(-1.0, -0.4, 0.1, 255, 255, 255, 255);
					ShowHudText(iClient,channel,"%.0f%% CHUTE",(PARACHUTE_TIME-g_meterSec[iClient])*100/PARACHUTE_TIME);

					if((clientFlags & FL_ONGROUND) || g_meterSec[iClient] > PARACHUTE_TIME)
					{
						TF2_RemoveCondition(iClient,TFCond_Parachute);
						TF2_AddCondition(iClient,TFCond_ParachuteDeployed);
					}
				}
				else if(g_meterSec[iClient] != 0)
				{
					if(TF2_IsPlayerInCondition(iClient,TFCond_ParachuteDeployed) || (clientFlags & FL_ONGROUND))
						g_meterSec[iClient] = 0.0;
				}
			}

			//for extra blast jump counters
			if(TF2_IsPlayerInCondition(iClient,TFCond_BlastJumping) || g_condFlags[iClient] & TF_CONDFLAG_BLJUMP)
			{
				float vel[3];
				GetEntPropVector(iClient, Prop_Data, "m_vecVelocity",vel);
				if((clientFlags & FL_ONGROUND) && vel[2] == 0.0)
				{
					g_condFlags[iClient] &= ~TF_CONDFLAG_BLJUMP;
					TF2_RemoveCondition(iClient,TFCond_BlastJumping);
				}
				else if(g_condFlags[iClient] & TF_CONDFLAG_BLJUMP && !TF2_IsPlayerInCondition(iClient,TFCond_BlastJumping))
				{
					TF2_AddCondition(iClient,TFCond_BlastJumping,_,iClient);
				}
			}
			else if(g_condFlags[iClient] & TF_CONDFLAG_DIVE) //reset mantreads condition if not jumping
			{
				g_condFlags[iClient] &= ~TF_CONDFLAG_DIVE;
			}

			if (IsValidClient(i))
			{
				Address addr1 = TF2Attrib_GetByDefIndex(iClient,68);
				float capture = 1.0;
				if(addr1!=Address_Null) capture = TF2Attrib_GetValue(addr1);
				Address addr2 = TF2Attrib_GetByDefIndex(iClient,400);
				float intel = -1.0;
				if(addr2!=Address_Null) intel = TF2Attrib_GetValue(addr2);
				
				//vaccinator attributes
				if(TF2_IsPlayerInCondition(iClient,TFCond_UberBlastResist) || TF2_IsPlayerInCondition(iClient,TFCond_UberBulletResist) || TF2_IsPlayerInCondition(iClient,TFCond_UberFireResist))
				{
					//block capture
					if(intel==0.0&&capture==0.0)
					{
						TF2Attrib_SetByDefIndex(iClient,400,1.0);
						if(TF2_GetPlayerClass(iClient)==TFClass_Scout || meleeIndex==154) //scouts and pain train
							TF2Attrib_SetByDefIndex(iClient,68,-2.0);
						else
							TF2Attrib_SetByDefIndex(iClient,68,-1.0);
						FakeClientCommand(iClient,"dropitem");
					}

					//vacc regenerate HP
					float interval = 0.045;
					bool heal = true;
					if(g_lastVaccHeal[iClient]!=-1.0) //medic can't heal himself
					{
						if(TF2_IsPlayerInCondition(iClient,TFCond_Healing))
						{
							int healer = TF2Util_GetPlayerConditionProvider(iClient,TFCond_Healing);
							//don't heal if connected to medigun
							for(int idx=1; idx <= MaxClients; idx++)
							{
								if(GetHealingTarget(idx)==iClient)
								{
									heal = false;
								}
							}
							//if connected to level 1 dispenser: 0.075; level 2 dispenser: 0.135; level 3 dispenser: 0.24
							char class[64];
							GetEntityClassname(healer,class,64);
							if(heal & StrEqual(class,"obj_dispenser"))
							{
								switch(GetEntProp(healer, Prop_Send,"m_iUpgradeLevel"))
								{
									case 1: interval = 0.075;
									case 2: interval = 0.135;
									case 3: interval = 0.24;
								}
							}
						}
						if(g_bIsMVM)
						{
							Address addr = TF2Attrib_GetByName(primary, "healing mastery");
							if(addr != Address_Null)
							{
								float value = TF2Attrib_GetValue(addr);
								value = 1.0 + 0.25*value;
								interval /= value;
							}
						}
						if(heal && g_lastVaccHeal[iClient]+interval<=GetGameTime())
						{
							g_lastVaccHeal[iClient] = GetGameTime();
							TF2Util_TakeHealth(iClient,1.0);
							int healer=0;
							healer = TF2Util_GetPlayerConditionProvider(iClient,TFCond_UberBulletResist);
							if(!IsValidClient(healer)) healer = TF2Util_GetPlayerConditionProvider(iClient,TFCond_UberBlastResist);
							if(!IsValidClient(healer)) healer = TF2Util_GetPlayerConditionProvider(iClient,TFCond_UberFireResist);
							if(IsValidClient(healer))
							{
								int healing = GetEntProp(healer, Prop_Send, "m_iHealPoints");
								SetEntProp(healer, Prop_Send, "m_iHealPoints", healing + 1);
							}
						}
					}
				}
				else
				{
					if(intel==1.0&&(capture==-1.0||capture==-2.0))
					{
						TF2Attrib_SetByDefIndex(iClient,400,0.0); //cannot pick up intelligence
						TF2Attrib_SetByDefIndex(iClient,68,0.0); //increase player capture value
					}
				}

				//in mvm upgrade station
				if (g_bIsMVM && (g_condFlags[iClient] & TF_CONDFLAG_INSPAWN == TF_CONDFLAG_INSPAWN) && !(g_condFlags[iClient] & TF_CONDFLAG_UPGRADE == TF_CONDFLAG_UPGRADE) && !(g_condFlags[iClient] & TF_CONDFLAG_NOGRADE == TF_CONDFLAG_NOGRADE))
				{
					FakeClientCommand(iClient,"sm_upgrade");
				}
				if (g_bIsMVM && !(g_condFlags[iClient] & TF_CONDFLAG_INSPAWN == TF_CONDFLAG_INSPAWN) && (g_condFlags[iClient] & TF_CONDFLAG_NOGRADE == TF_CONDFLAG_NOGRADE))
				{
					g_condFlags[iClient] &= ~TF_CONDFLAG_NOGRADE;
				}
				
				switch(TF2_GetPlayerClass(iClient))
				{
					case TFClass_Scout:
					{
						switch(meleeIndex)
						{
							case 44: //sandman
							{
								float time = GetGameTime();
								float regen = GetEntPropFloat(melee,Prop_Send,"m_flEffectBarRegenTime");
								if(regen - time < 9.2 && !(g_condFlags[iClient] & TF_CONDFLAG_BASED))
									g_condFlags[iClient] |= TF_CONDFLAG_BASED;
								if(time > regen && g_condFlags[iClient] & TF_CONDFLAG_BASED)
									g_condFlags[iClient] &= ~TF_CONDFLAG_BASED;
							}
							case 349: //Sun-on-a-stick
							{
								if(g_condFlags[iClient] & TF_CONDFLAG_HEATSPAWN) //makes sure HEAT resets post-spawn
								{
									g_condFlags[iClient] &= ~TF_CONDFLAG_HEATSPAWN;
									SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",0.0,2);
								}
								//update HEAT meter
								SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
								float meter = GetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",2);
								if(g_condFlags[iClient] & TF_CONDFLAG_HEAT)
								{
									SetHudTextParams(-0.1, -0.1, 0.5, 255, 50, 50, 255);
									meter -= 0.19;
									if(meter<=0.0)
									{
										meter = 0.0;
										g_condFlags[iClient] &= ~TF_CONDFLAG_HEAT;
										SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
									}
									g_meterMel[iClient] = meter;
									SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",meter,2);
									
									float eyePos[3];
									WA_GetAttachmentPos(iClient, "weapon_bone", eyePos);
									float curPos[3];
									GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", curPos);
									CreateParticle(iClient,"superrare_burning1",0.015,_,_,eyePos[0]-curPos[0],eyePos[1]-curPos[1],eyePos[2]-curPos[2],_,_,_,true);
								}
								ShowHudText(iClient,4,"HEAT: %.0f%",meter);
							}

						}
						switch(primaryIndex)
						{
							//manage soda popper
							case 448:
							{
								float hype = GetEntPropFloat(iClient, Prop_Send,"m_flHypeMeter");
								int jumps = GetEntProp(iClient, Prop_Send,"m_iAirDash");
								if(clientFlags & FL_ONGROUND == FL_ONGROUND)
								{
									g_jumpCount[iClient]=0;
								}
								else
								{
									if(hype>=(HYPE_COST*(Pow(2.0,g_jumpCount[iClient]+0.0))))
									{
										if(jumps==1)
										{
											SetEntProp(iClient, Prop_Send,"m_iAirDash",0);
											hype-=HYPE_COST*(Pow(2.0,g_jumpCount[iClient]+0.0));
											SetEntPropFloat(iClient, Prop_Send,"m_flHypeMeter",hype);
											float pos[3];
											GetClientEyePosition(iClient,pos);
											EmitAmbientSound("misc/banana_slip.wav",pos,iClient,_,_,0.5);
											g_jumpCount[iClient]++;
										}
									}
									else
									{
										if(jumps==0) SetEntProp(iClient, Prop_Send,"m_iAirDash",1);
									}
								}
								
								if(hype>=(HYPE_COST*(Pow(2.0,g_jumpCount[iClient]+0.0))) && !TF2_IsPlayerInCondition(iClient,TFCond_CritHype))
								{
									TF2_AddCondition(iClient,TFCond_CritHype);
								}
								else if(TF2_IsPlayerInCondition(iClient,TFCond_CritHype))
								{
									if(hype<99.9) SetEntPropFloat(iClient, Prop_Send,"m_flHypeMeter",hype+0.1415);
									if(hype<(HYPE_COST*(Pow(2.0,g_jumpCount[iClient]+0.0))))
										TF2_RemoveCondition(iClient,TFCond_CritHype);
								}
							}
							//manage baby face
							case 772:
							{
								float hype = GetEntPropFloat(iClient, Prop_Send,"m_flHypeMeter");
								//adjust boost
								if(RoundFloat(g_meterPri[iClient])>RoundFloat(hype))
								{
									g_meterPri[iClient]=hype;
								}

								//TODO: use meterPri to gradually increase hype over time. completely remove boost loss on taking/losing damage in ontakedamage 
							}
						}
						switch(secondaryIndex)
						{
							case 222,1121: //mad milk
							{
								g_meterSec[iClient] += 0.015; //marker for meter in case of switch
							}
							case 812,833: //flying guillotine
							{
								float regen = GetEntPropFloat(secondary,Prop_Send,"m_flEffectBarRegenTime");
								if(regen!=g_meterSec[iClient] && regen!=0.0)
								{
									if(regen>g_meterSec[iClient]) g_meterSec[iClient] = regen;
									if(regen<g_meterSec[iClient])
									{
										SetEntPropFloat(secondary,Prop_Send,"m_flEffectBarRegenTime",regen-5.0);
										SetEntPropFloat(secondary,Prop_Send,"m_flLastFireTime",regen-10.0);
									}
								}
							}
						}
					}
					case TFClass_Soldier:
					{
						switch(primaryIndex)
						{
							case 414: //
							{
								//liberty launcher auto-reload
								if(current==primary)
								{
									if(g_meterPri[iClient]!=0) g_meterPri[iClient] = 0.0;
								}
								else
								{
									if(g_meterPri[iClient]>=1.0)
									{
										g_meterPri[iClient] = 0.0;
										int max = 5;
										int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
										int clip = GetEntData(primary, iAmmoTable, 4);
										int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
										int ammoCount = GetEntProp(iClient, Prop_Data, "m_iAmmo", _, primaryAmmo);
										if(clip<max && ammoCount>0)
										{
											SetEntData(primary, iAmmoTable, clip+1, _, true);
											SetEntProp(iClient, Prop_Data, "m_iAmmo", ammoCount-1, _,primaryAmmo);
											EmitSoundToClient(iClient,"weapons/rocket_reload.wav",_,_,SNDLEVEL_SCREAMING);
										}
									}
									else
										g_meterPri[iClient] += 0.015;
								}
							}
						}
						switch(meleeIndex)
						{
							//The Equalizer
							case 128:
							{
								if(IsPlayerAlive(iClient))
								{
									g_meterMel[iClient] += 0.015;
									int MaxHP = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, iClient);
									int Health = GetClientHealth(iClient);

									SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
									if(g_condFlags[iClient] & TF_CONDFLAG_QUICK)
									{
										ShowHudText(iClient,4,"RUSH: NOT READY");
									}
									else
									{
										if(Health<MaxHP/2)
										{
											ShowHudText(iClient,4,"RUSH: READY");
											if(g_meterMel[iClient]>=0.5)
											{
												float eyePos[3];
												WA_GetAttachmentPos(iClient, "weapon_bone", eyePos);
												float curPos[3];
												GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", curPos);
												CreateParticle(iClient,"unusual_steaming",0.01,_,_,eyePos[0]-curPos[0],eyePos[1]-curPos[1],eyePos[2]-curPos[2],_,_,_,true);
											}
										}
										else
										{
											ShowHudText(iClient,4,"RUSH: NOT READY");
										}
									}
									if(g_meterMel[iClient]>=0.5)
									{
										g_meterMel[iClient] = 0.0;
									}
									if(TF2_IsPlayerInCondition(iClient,TFCond_SpeedBuffAlly) && TF2Util_GetPlayerConditionDuration(iClient,TFCond_SpeedBuffAlly)<1.8)
									{
										if(current!=melee && TF2Util_GetPlayerConditionProvider(iClient,TFCond_SpeedBuffAlly)==iClient)
											TF2_RemoveCondition(iClient,TFCond_SpeedBuffAlly);
									}
								}
							}
						}
					}
					case TFClass_Pyro:
					{
						if(primaryIndex != 594 && primaryIndex !=1 && primary!=-1) //handle airblast, except for phlog
						{
							float meter = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0);
							if(primaryIndex == 1178) meter = g_meterPri[iClient];

							float nextAttack = GetEntPropFloat(primary, Prop_Send, "m_flLastFireTime");
							int weaponState = GetEntProp(primary, Prop_Send, "m_iWeaponState");
							if(weaponState!=2 && weaponState!=3 && nextAttack-0.15<GetGameTime()) //out of airblast
							{
								//update pressure meter
								float increment = 100.0/(66*PRESSURE_TIME);
								if(g_bIsMVM)
								{
									Address addr = TF2Attrib_GetByName(primary, "mult airblast refire time");
									if(primaryIndex == 1178) addr = TF2Attrib_GetByName(primary, "fire rate bonus");
									if(addr != Address_Null)
									{
										float value = TF2Attrib_GetValue(addr);
										increment /= value;
									}
								}
								if(primaryIndex==40 || primaryIndex==1146) increment *= 0.67; //backburner slower recharge
								else if(primaryIndex==215) increment *= 1.33; //degreaser faster recharge
								
								if(primaryIndex != 1178)
								{
									if(meter<100.0) SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", meter+increment, 0);
									else if(meter>100.0) SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 100.0, 0);
								}
								else
								{
									float rate = GetEntPropFloat(primary, Prop_Send, "m_flRechargeScale");
									increment *= rate; //increase rate based on re-pressurization
									if(meter<100.0) g_meterPri[iClient] = meter+increment;
									else if(meter>100.0) g_meterPri[iClient] = 100.0;
								}
								//update force of airblast in increments
								int force = RoundToNearest(meter);
								float newMeter = meter/100;
								if(g_bIsMVM) //mvm force
								{
									Address addr = TF2Attrib_GetByName(primary, "melee range multiplier");
									if(addr != Address_Null)
									{
										float value = TF2Attrib_GetValue(addr);
										newMeter *= value;
									}
								}
								if(force % 5 == 0) TF2Attrib_SetByDefIndex(primary,255,newMeter); //set next airblast force
							}
							SetHudTextParams(-0.1, -0.16, 0.5, 255, 255, 255, 255);
							ShowHudText(iClient,2,"%.0f%% PRESSURE",meter);
						}
						else if (primaryIndex == 594) //phlog effects
						{
							float value = 0.0;
							Address addr = TF2Attrib_GetByName(primary, "ragdolls plasma effect");
							if(addr != Address_Null)
							{
								value = TF2Attrib_GetValue(addr);
							}
							if(value > 0)
							{
								TF2Attrib_SetByDefIndex(primary,350,1.0); //ragdolls become ash
								TF2Attrib_SetByDefIndex(primary,436,0.0); //ragdolls plasma effect
							}
						}
						if(primaryIndex==1178) //dragon's fury mvm firing speed
						{
							if(g_bIsMVM)
							{
								float rate = GetEntPropFloat(primary, Prop_Send, "m_flRechargeScale");
								float newRate = rate;
								float value = 1.0;
								Address addr = TF2Attrib_GetByName(primary, "fire rate bonus");
								if(addr != Address_Null)
								{
									value = TF2Attrib_GetValue(addr);
									value = 1 + (1-value);
								}
								switch(rate)
								{
									case 1.0,0.5,1.5:
										newRate *= value;
								}
								if(rate!=newRate)
									SetEntPropFloat(primary, Prop_Send, "m_flRechargeScale", newRate);
							}
						}
						switch(secondaryIndex)
						{
							case 595: //manmelter animation update
							{
								if(current==secondary)
								{
									int view = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
									int sequence = GetEntProp(view, Prop_Send, "m_nSequence");
									float nextAttack = GetEntPropFloat(secondary, Prop_Send, "m_flNextPrimaryAttack");
									float diff = nextAttack-GetGameTime();
									int reload = 9;
									if(sequence != 23 && sequence != reload && diff > 0 && diff < 1.5)
									{
										SetEntProp(view, Prop_Send, "m_nSequence",reload);
										SetEntPropFloat(view, Prop_Send, "m_flPlaybackRate",1.25);
									}else if(sequence == reload && diff <= 0)
									{
										SetEntProp(view, Prop_Send, "m_nSequence",24);
										SetEntPropFloat(view, Prop_Send, "m_flPlaybackRate",1.0);
									}
								}
								if(RoundToCeil(g_meterSec[iClient]) >= 100)
								{
									int crits = GetEntProp(iClient, Prop_Send, "m_iRevengeCrits");
									SetEntProp(iClient, Prop_Send, "m_iRevengeCrits",crits+1);
									EmitSoundToClient(iClient,"player/recharged.wav");
									g_meterSec[iClient]=0.0;
								}
								SetHudTextParams(-0.1, -0.13, 0.5, 255, 255, 255, 255);
								ShowHudText(iClient,3,"MELT: %.0f%",g_meterSec[iClient]);
							}
							//thruster
							case 1179:
							{
								//track airtime and ground ticks
								if(!TF2_IsPlayerInCondition(iClient,TFCond_RocketPack))
								{
									float vel[3];
									GetEntPropVector(iClient, Prop_Data, "m_vecVelocity",vel);
									if(vel[2]!=0.0 || !(clientFlags & FL_ONGROUND))
									{
										if(g_meterSec[iClient]<0.0)
											g_meterSec[iClient] = 0.0;
										g_meterSec[iClient]+=0.015;
									}
									else
									{
										if(g_meterSec[iClient]>0.0)
											g_meterSec[iClient] = 0.0;
										g_meterSec[iClient]-=0.015;
									}
								}
								//generate particle
								if(g_meterSec[iClient]<-1.995 && GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 1) > 50)
								{
									float angles[3];
									GetClientEyeAngles(iClient,angles);
									float exAngle = 0.0;
									angles[0] *= 1.25; angles[1] *= 1.25; 
									if(angles[0]!=0)
									{
										if(angles[1]!=0) exAngle = angles[1] > 0 ? 45.0 : 135.0;
										else exAngle = 90.0;
										if(angles[0]<0) exAngle *= -1;
									}
									else exAngle = angles[1] < 0 ? 180.0 : 0.0;
									if(!(angles[0]!=0 || angles[1]!=0)) exAngle += angles[1];
									else exAngle += angles[1] - 90;
									CreateParticle(iClient,"rocketpack_exhaust",0.03,0.0,exAngle,_,_,42.0,_,_,_,_,_,_);
									g_meterSec[iClient]=0.0;
								}
							}
						}
						switch(meleeIndex)
						{
							case 813, 834: //check Neon Annihilator state
							{
								int broken = GetEntProp(melee, Prop_Send, "m_bBroken");
								SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
								ShowHudText(iClient,4,"CHARGE: %.0f%",g_meterMel[iClient]);
								if(broken == 1)
								{
									if(TF2_IsPlayerInCondition(iClient,TFCond_FocusBuff))
										TF2_RemoveCondition(iClient,TFCond_FocusBuff);
									if(TF2_IsPlayerInCondition(iClient,TFCond_Sapped))
										TF2_RemoveCondition(iClient,TFCond_Sapped);
									if(g_meterMel[iClient]>=100.0)
									{
										g_meterMel[iClient]=100.0;
										SetEntProp(melee, Prop_Send, "m_bBroken",0);
										EmitSoundToClient(iClient,"player/recharged.wav");
									}
								}
								else //glow state
								{
									if(current==melee) //exclude phlog
									{
										if(primaryIndex != 594 && !TF2_IsPlayerInCondition(iClient,TFCond_FocusBuff))
											TF2_AddCondition(iClient,TFCond_FocusBuff);
										else if(!TF2_IsPlayerInCondition(iClient,TFCond_Sapped) && primaryIndex == 594)
											TF2_AddCondition(iClient,TFCond_Sapped);
									}
									else
									{
										if(TF2_IsPlayerInCondition(iClient,TFCond_FocusBuff))
											TF2_RemoveCondition(iClient,TFCond_FocusBuff);
										if(TF2_IsPlayerInCondition(iClient,TFCond_Sapped))
											TF2_RemoveCondition(iClient,TFCond_Sapped);
									}
								}
							}
						}
					}
					case TFClass_DemoMan:
					{
						switch(primaryIndex)
						{
							case 308: //
							{
								//loch-n-load auto-reload
								if(current==primary)
								{
									if(g_meterPri[iClient]!=0) g_meterPri[iClient] = 0.0;
								}
								else
								{
									if(g_meterPri[iClient]>=1.0)
									{
										g_meterPri[iClient] = 0.0;
										int max = 2;
										int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
										int clip = GetEntData(primary, iAmmoTable, 4);
										int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
										int ammoCount = GetEntProp(iClient, Prop_Data, "m_iAmmo", _, primaryAmmo);
										if(clip<max && ammoCount>0)
										{
											SetEntData(primary, iAmmoTable, clip+1, _, true);
											SetEntProp(iClient, Prop_Data, "m_iAmmo", ammoCount-1, _,primaryAmmo);
											EmitSoundToClient(iClient,"weapons/grenade_launcher_worldreload.wav",_,_,SNDLEVEL_SCREAMING);
										}
									}
									else
										g_meterPri[iClient] += 0.015;
								}
							}
						}
						switch(meleeIndex)
						{
							case 307: //check caber state
							{
								float gameTime = GetGameTime();
								int broken = GetEntProp(melee, Prop_Send, "m_bBroken");
								int detonated = GetEntProp(melee, Prop_Send, "m_iDetonated");
								float lastTime = GetEntPropFloat(melee, Prop_Send, "m_flLastFireTime");
								float duration = 60.0;
								if(g_bIsMVM)
								{
									Address addr = TF2Attrib_GetByName(melee, "effect bar recharge rate increased");
									if(addr != Address_Null)
									{
										float value = TF2Attrib_GetValue(addr);
										duration *= value;
									}
								}
								int charge = RoundToFloor((gameTime-lastTime)/duration * 100);

								if(detonated==1)
								{
									SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
									ShowHudText(iClient,4,"Caber: %d %",charge);
									switch(g_meterMel[iClient])
									{
										case 0.0:
										{
											if(detonated==1&&broken==1)
											{
												g_meterMel[iClient] = 1.0;
												SetEntPropFloat(melee, Prop_Send, "m_flLastFireTime", gameTime);
											}
										}
										case 1.0:
										{
											if(gameTime>lastTime+60)
											{
												EmitSoundToClient(iClient,"player/recharged.wav");
												SetEntProp(melee, Prop_Send, "m_bBroken",0);
												SetEntProp(melee, Prop_Send, "m_iDetonated",0);
												g_meterMel[iClient] = 0.0;
											}
										}
									}
								}
							}
						}
						char classname[64];
						GetEntityClassname(secondary,classname,64);
						if(StrEqual(classname,"tf_wearable_demoshield"))
						{
							float meter = GetEntPropFloat(iClient, Prop_Send,"m_flChargeMeter");
							if(meter<50 && g_meterSec[iClient] == 0.0)
								g_meterSec[iClient] = 1.0;
							if(meter>50 && !(g_condFlags[iClient] & TF_CONDFLAG_HOVER))
							{
								SetHudTextParams(-0.1, -0.13, 0.5, 255, 255, 255, 255);
								ShowHudText(iClient,3,"Leap Ready");
								if(g_meterSec[iClient] == 1.0)
								{
									g_meterSec[iClient] = 0.0;
									EmitSoundToClient(iClient,"player/recharged.wav");
								}
							}
						}
					}
					case TFClass_Heavy:
					{
						//speed up minigun spindown
						if(primary != -1)
						{
							int weaponState = GetEntProp(primary, Prop_Send, "m_iWeaponState");
							int view = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
							int sequence = GetEntProp(view, Prop_Send, "m_nSequence");
							if(sequence == 23 && weaponState == 0)
							{
								float speed = 1.33;
								// if(primaryIndex == 298) speed = 2.0;
								if(g_bIsMVM) //mvm spindown upgrade
								{
									Address addr = TF2Attrib_GetByName(primary, "melee range multiplier");
									if(addr != Address_Null)
									{
										float value = TF2Attrib_GetValue(addr);
										if(value>0)
										{
											speed = 2.0;
										}
									}
								}
								SetEntPropFloat(view, Prop_Send, "m_flPlaybackRate",speed); //speed up animation
							}
						}
						switch(primaryIndex)
						{
							case 424: //tomislav no ramp up
							{
								int weaponState = GetEntProp(primary, Prop_Send, "m_iWeaponState");
								if(weaponState==1)
								{
									g_meterPri[iClient] = 1.005;
								}
								else if((weaponState==2||weaponState==3) && g_meterPri[iClient]!=0.0)
								{
									int time = RoundFloat(g_meterPri[iClient]*1000);
									if(time%90==0)
									{
										float factor = 1.0 + time/990.0;
										TF2Attrib_SetByDefIndex(primary,106,0.8/factor); //spread bonus
										TF2Attrib_SetByDefIndex(primary,2,1.0*factor); //damage bonus
									}
								}
							}
							case 811,832:
							{
								//heater new ring check
								int weaponState = GetEntProp(primary, Prop_Send, "m_iWeaponState");
								if((weaponState == 2 || weaponState == 3))
								{
									g_meterPri[iClient] += 0.015;
									if(g_meterPri[iClient]>0.5)
									{
										g_meterPri[iClient] = 0.0;
										float dist,distMod;
										float posClient[3],posTarget[3];
										GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", posClient);
										posClient[2]+=24;//raise origin for check
										for (int idx = 1 ; idx <= MaxClients ; idx++)
										{
											if(IsValidClient(idx,false) && idx!=iClient)
											{
												if(IsPlayerAlive(idx) && GetClientTeam(iClient)!=GetClientTeam(idx))
												{
													GetEntPropVector(idx, Prop_Send, "m_vecOrigin", posTarget);
													dist = getPlayerDistance(iClient,idx);
													distMod = GetVectorDistance(posClient,posTarget);
													if(distMod<130 && dist>distMod) //is target close enough but also not closer to the normal ring radius
													{
														bool hit = false;
														Handle hndl = TR_TraceRayFilterEx(posClient, posTarget, MASK_SOLID, RayType_EndPoint, TraceFilter, idx);
														if(TR_DidHit() == false)
															hit = true;
														else
														{
															int vic = TR_GetEntityIndex(hndl);
															char[] class = new char[64];
															if(IsValidEdict(vic)) GetEdictClassname(vic, class, 64);
															
															if(StrEqual(class,"func_respawnroomvisualizer") || !IsValidEdict(vic))
																hit = true;
														}
														if(hit)
															SDKHooks_TakeDamage(idx,iClient,iClient,12.0,DMG_IGNITE|DMG_BURN,primary,_,_,false);
													}
												}
											}
										}
									}
								}
							}
							default:
							{
								//eh?
							}
						}
						switch(secondaryIndex)
						{
							case 311: //update buffalo steak speed
							{
								if(TF2_IsPlayerInCondition(iClient,TFCond_CritCola))
								{
									float speed = 299.0; //322 +40%
									//half speed boosts before stacking them on the steak's bonus
									switch(meleeIndex)
									{
										case 426:
											speed *= 1 + 0.15/2;
										case 239,1084,1100:
											speed *= 1 + 0.3/2;
									}
									if(TF2_IsPlayerInCondition(iClient,TFCond_SpeedBuffAlly))
										speed *= 1 + 0.4/2;
										
									SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",speed);
									//display duration
									float time = TF2Util_GetPlayerConditionDuration(iClient,TFCond_CritCola);
									SetHudTextParams(-1.0, -0.4, 0.1, 255, 255, 255, 255);
									ShowHudText(iClient,3,"%.0f%% RAGE",(time*100)/16.0);
								}
							}
							case 159, 433: //dalokohs bar max health
							{
								if(TF2_IsPlayerInCondition(iClient,TFCond_Taunting)&&!TF2_IsPlayerInCondition(iClient,TFCond_Healing)&&current==secondary&&(g_condFlags[iClient] & TF_CONDFLAG_EATING))
								{
									int MaxHP = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, iClient);
									if(GetClientHealth(iClient)>MaxHP)
									{
										SetEntityHealth(iClient,MaxHP);
									}
								}
							}
						}
						if(meleeIndex==331)
						{
							//fists of steel overheal reduction
							Address addr = TF2Attrib_GetByDefIndex(melee,239);
							if(addr!=Address_Null)
							{
								float mode = TF2Attrib_GetValue(addr);
								int maxOverheal = 390;
								if(GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, iClient) > 300)
									maxOverheal=440;
								if(GetClientHealth(iClient)>=maxOverheal-10 && mode==1.0)
								{
									TF2Attrib_SetByDefIndex(melee,239,0.5); //ubercharge rate bonus for healer
								}
								else if(GetClientHealth(iClient)<maxOverheal-10 && mode<1.0)
								{
									TF2Attrib_SetByDefIndex(melee,239,1.0); //ubercharge rate bonus for healer
								}
							}
						}
					}
					case TFClass_Engineer:
					{
						if(IsValidEdict(g_engyDispenser[iClient]))
						{
							if(g_dispenserStatus[g_engyDispenser[iClient]]==1)
							{
								int building = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Building, true);
								if(current != building)
								{
									g_meterMel[iClient] += 0.015;
								}
							}
						}
						switch(primaryIndex)
						{
							case 588: //Eureka
							{
								//pomson auto-reload
								if(current != primary)
								{
									float meter = g_meterPri[iClient];
									float interval = 1.0;
									if(meter+interval>66)
									{
										g_meterPri[iClient] = 0.0;
										float clip = GetEntPropFloat(primary, Prop_Send, "m_flEnergy");
										float max = 20.0;
										if(g_bIsMVM) //mvm force
										{
											Address addr = TF2Attrib_GetByName(primary, "clip size bonus");
											if(addr != Address_Null)
											{
												float value = TF2Attrib_GetValue(addr);
												max *= value;
											}
										}
										if(clip<max)
										{
											SetEntPropFloat(primary, Prop_Send, "m_flEnergy", clip+5.0);
										}
									}
									else
									{
										g_meterPri[iClient] += interval;
									}
								}
							}
						}
						switch(secondaryIndex)
						{
							case 528: //Short Circuit charge
							{
								int view = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
                           		int seq = GetEntProp(view, Prop_Send, "m_nSequence");
								if(current==secondary && (seq != 27 || g_meterSec[iClient]<=0))
								{
									SetEntPropFloat(secondary, Prop_Send, "m_flNextSecondaryAttack",GetGameTime()+0.3);
								}
								if(g_meterSec[iClient]<0)
								{
									g_meterSec[iClient] = g_meterSec[iClient]+0.015 > 0 ? 0.0 : g_meterSec[iClient]+0.015;
								}
								else if(g_meterSec[iClient]>=2.0 && g_condFlags[iClient] & TF_CONDFLAG_INFIRE == TF_CONDFLAG_INFIRE)
								{
									g_meterSec[iClient] = -0.5;
									g_condFlags[iClient] &= ~TF_CONDFLAG_INFIRE;
								}
								else if(g_meterSec[iClient]>=2.1)
								{
									g_meterSec[iClient] = -0.5;
									g_condFlags[iClient] &= ~TF_CONDFLAG_INFIRE;
								}
							}
						}
					}
					case TFClass_Medic:
					{
						switch(primaryIndex)
						{
							case 17,204,36,412:
							{
								float meter = GetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",0);
								if (current == primary)
								{
									//syringe shooting
									SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",0.0,0);
									float lastAttack = GetEntPropFloat(primary, Prop_Send, "m_flLastFireTime");
									if(lastAttack > g_lastFire[iClient] && g_condFlags[iClient] & TF_CONDFLAG_INFIRE && !(g_condFlags[iClient] & TF_CONDFLAG_LOSER == TF_CONDFLAG_LOSER))
									{
										g_lastFire[iClient] = lastAttack;
										float angles[3];
										GetClientEyeAngles(iClient,angles);
										Syringe_PrimaryAttack(iClient,primary,angles,primaryIndex);
									}
								}
								else
								{
									//syringe auto-reload
									float interval = 15.0;
									if(meter+interval>100)
									{
										SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",0.00,0);
										int max = primaryIndex==36 ? 25 : 40;
										int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
										int clip = GetEntData(primary, iAmmoTable, 4);
										int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
										int ammoCount = GetEntProp(iClient, Prop_Data, "m_iAmmo", _, primaryAmmo);
										if(clip<max && ammoCount>0)
										{
											SetEntData(primary, iAmmoTable, clip+1, _, true);
											SetEntProp(iClient, Prop_Data, "m_iAmmo", ammoCount-1, _,primaryAmmo);
										}
									}
									else
									{
										SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",meter+interval,0);
									}
								}
							}
						}
						switch(secondaryIndex)
						{
							case 411: //modify quick-fix uber duration
							{
								if(g_condFlags[iClient] & TF_CONDFLAG_QUICK)
								{
									float time = g_meterSec[iClient];
									float duration = 6.0;
									if(g_bIsMVM)
									{
										Address addr = TF2Attrib_GetByName(secondary, "uber duration bonus");
										if(addr != Address_Null)
										{
											float value = TF2Attrib_GetValue(addr);
											duration += value;
										}
									}
									//increase duration for healing hurt patients
									int patient = GetEntPropEnt(secondary, Prop_Send, "m_hHealingTarget");
									if(IsValidClient(patient))
									{
										int MaxHP = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, patient);
										if(GetClientHealth(patient)<MaxHP)
										{
											g_meterSec[iClient]+=0.01;
										}
									}

									float meter = 1.0 - (GetGameTime()-time)/duration;
									if(meter<0)
									{
										meter=0.0;
										g_meterSec[iClient] = 0.0;
										g_condFlags[iClient] &= ~TF_CONDFLAG_QUICK;
									}
									SetEntPropFloat(secondary, Prop_Send, "m_flChargeLevel", meter);
								}
							}
						}
						switch(meleeIndex)
						{
							case 304:
							{
								if(TF2_IsPlayerInCondition(iClient,TFCond_Taunting))
								{
									char weapon[64];
									GetClientWeapon(iClient,weapon,64);
									//allow medic to cancel amputator taunt
									if((StrEqual(weapon,"tf_weapon_bonesaw")||StrEqual(weapon,"Bonesaw")) && GetEntProp(iClient, Prop_Send, "m_nActiveTauntSlot") == -1 && GetEntProp(iClient, Prop_Send, "m_bAllowMoveDuringTaunt") == 0)
									{
										if(g_meterMel[iClient]>2)
										{
											SetHudTextParams(-1.0, -0.16, 1.0, 255, 255, 255, 255, _, _, 0.0);
											ShowHudText(iClient,1,"Cancel?");
											g_meterMel[iClient] = 0.0;
											SetEntProp(iClient, Prop_Send, "m_bAllowMoveDuringTaunt",1);
											SetEntProp(iClient, Prop_Send, "m_iTauntIndex",3);
											SetEntProp(iClient, Prop_Send, "m_iTauntConcept",94);
										}
										else g_meterMel[iClient] += 1.0/66;
									}
								}
							}
							case 173:
							{
								//The Vita-Saw
								int healing = GetEntProp(iClient, Prop_Send, "m_iHealPoints");
								float meter = (healing-g_meterMel[iClient])/3.0;
								if(meter < 0) meter = 0.0;
								int organs = GetEntProp(iClient, Prop_Send, "m_iDecapitations");
								
								SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
								if(organs < 4)
								{
									if(meter >= 100)
									{
										ShowHudText(iClient,4,"Organ: DONE %.0f",meter);
										g_meterMel[iClient] = healing+0.0;
										SetEntProp(iClient, Prop_Send, "m_iDecapitations",organs+1);
										EmitSoundToClient(iClient,"player/recharged.wav");
									}
									else
									{
										ShowHudText(iClient,4,"Organ: %.0f %",meter);
									}
								}
								else
								{
									if(organs>4) SetEntProp(iClient, Prop_Send, "m_iDecapitations",4);
									ShowHudText(iClient,4,"Organ: %.0f %",meter);
									g_meterMel[iClient] = healing+0.0;
								}
							}
						}
					}
					case TFClass_Sniper:
					{
						//sniper rifle reload
						int view = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
						int reload = GetEntProp(primary, Prop_Send, "m_iReloadMode");
						int sequence = GetEntProp(view, Prop_Send, "m_nSequence");
						float cycle = GetEntPropFloat(view, Prop_Data, "m_flCycle");
						if(primaryIndex!=56 && primaryIndex!=1005 && primaryIndex!=1092)
						{
							if(sequence==29 || sequence==28) //in case of last shot in clip, allows for auto-reload
							{
								if (cycle>=1.0) SetEntProp(view, Prop_Send, "m_nSequence",30);
								// if(primaryIndex == 230 || g_bIsMVM) //sleeper
								// {
								// 	float value = 1.0;
								// 	Address addr = TF2Attrib_GetByName(primary, "fire rate bonus");
								// 	if(addr != Address_Null)
								// 	{
								// 		value = TF2Attrib_GetValue(addr);
								// 		value = 1/value;
								// 	}
								// 	SetEntPropFloat(view, Prop_Send, "m_flPlaybackRate",value);
								// 	if (cycle>=1/value)
								// 	{
								// 		SetEntPropFloat(view, Prop_Data, "m_flCycle", 1.0);
								// 		SetEntDataFloat(view, 1004, 1.0, true);
								// 	}
								// }
							}

							if(reload!=0)
							{
								float reloadSpeed = 2.0;
								if(primaryIndex == 230) reloadSpeed=1.5;
								float clientPos[3];
								GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", clientPos);

								int relSeq = 41;
								float altRel = 0.875;
								if(primaryIndex == 851 || primaryIndex == 1098)
								{
									relSeq = 5;
									altRel = 0.5625;
								}
								
								SetEntPropFloat(view, Prop_Send, "m_flPlaybackRate",(altRel*2.0)/reloadSpeed);
								
								//play reload sounds
								if(reload==1)
								{
									if(sequence!=relSeq) SetEntProp(view, Prop_Send, "m_nSequence",relSeq);
									SetEntPropFloat(view, Prop_Data, "m_flCycle", g_meterPri[iClient]); //1004
									SetEntDataFloat(view, 1004, g_meterPri[iClient], true); //1004
									if(g_meterPri[iClient]/reloadSpeed>0.1)
									{
										EmitAmbientSound("weapons/widow_maker_pump_action_forward.wav",clientPos,iClient,SNDLEVEL_TRAIN,_,0.4);
										reload = 2;
										SetEntProp(primary, Prop_Send, "m_iReloadMode",2);
									}
								}
								else if(reload==2)
								{
									if(sequence!=relSeq) SetEntProp(view, Prop_Send, "m_nSequence",relSeq);
									SetEntPropFloat(view, Prop_Data, "m_flCycle",g_meterPri[iClient]); //1004
									SetEntDataFloat(view, 1004,g_meterPri[iClient], true); //1004
									if(g_meterPri[iClient]/reloadSpeed>0.4)
									{
										EmitAmbientSound("weapons/revolver_reload_cylinder_arm.wav",clientPos,iClient,SNDLEVEL_TRAIN,_,0.4);
										reload = 3;
										SetEntProp(primary, Prop_Send, "m_iReloadMode",3);
									}
								}
								else if(reload==3)
								{
									if(sequence!=relSeq) SetEntProp(view, Prop_Send, "m_nSequence",relSeq);
									SetEntPropFloat(view, Prop_Data, "m_flCycle",g_meterPri[iClient]); //1004
									SetEntDataFloat(view, 1004,g_meterPri[iClient], true); //1004
									if(g_meterPri[iClient]/reloadSpeed>0.8)
									{
										EmitAmbientSound("weapons/widow_maker_pump_action_back.wav",clientPos,iClient,SNDLEVEL_TRAIN,_,0.4);
										reload = 4;
										SetEntProp(primary, Prop_Send, "m_iReloadMode",4);
									}
								}

								g_meterPri[iClient] += 1.0/66;
							}
						}
						switch(primaryIndex)
						{
							case 1098: //set classic headshots
							{
								if(reload==0)
								{
									float charge = GetEntPropFloat(primary, Prop_Send, "m_flChargedDamage");
									if(g_meterPri[iClient]!=1.0 && charge == 0.0)
									{
										TF2Attrib_SetByDefIndex(primary,306,1.0); //headshots only at full charge
										g_meterPri[iClient]=1.0;
									}
									if(g_meterPri[iClient]==1.0 && charge>134)
									{
										TF2Attrib_SetByDefIndex(primary,306,0.0); //headshots only at full charge
										g_meterPri[iClient]=2.0;
									}
								}
							}
							case 526,30665: //machina damage number
							{
								int victim = GetClientAimTarget(iClient);
								if(TF2_IsPlayerInCondition(iClient,TFCond_Slowed) && IsValidClient(victim))
								{
									if(GetClientTeam(iClient)!=GetClientTeam(victim))
									{
										float charge = GetEntPropFloat(primary, Prop_Send, "m_flChargedDamage");
										charge = charge > 50 ? charge : 50.0;
										SetHudTextParams(-1.0, -0.425, 0.1, 255, 255, 255, 255);
										ShowHudText(iClient,2,"%d HP",GetClientHealth(victim));
									}
								}
							}
						}
						//rifle firing speed
						// if(primaryIndex==230 || (g_bIsMVM && primaryIndex!=56 && primaryIndex!=1005 && primaryIndex!=1092)) //speed up sleeper rezoom
						// {
						// 	int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
						// 	float nextAtk = GetEntPropFloat(primary, Prop_Data, "m_flNextPrimaryAttack");
						// 	int clip = GetEntData(primary, iAmmoTable, 4);
						// 	float rezoom = GetEntPropFloat(primary, Prop_Data, "m_flRezoomTime");
						// 	if(reload==0 && clip>0)
						// 	{
						// 		if(rezoom != -1 && GetGameTime() < nextAtk)
						// 		{
						// 			SetEntPropFloat(primary, Prop_Data, "m_flRezoomTime", nextAtk);
						// 		}
						// 		else
						// 		{
						// 			if(!TF2_IsPlayerInCondition(iClient,TFCond_Slowed))
						// 			{
						// 				if(GetEntPropFloat(primary, Prop_Data, "m_flNextSecondaryAttack") > GetEntPropFloat(primary, Prop_Data, "m_flNextPrimaryAttack"))
						// 				{
						// 					SetEntPropFloat(primary, Prop_Data, "m_flNextSecondaryAttack",GetEntPropFloat(primary, Prop_Data, "m_flNextPrimaryAttack"));
						// 				}
						// 			}
						// 		}
						// 	}
						// 	//reload fix
						// 	if(clip==0 && GetEntPropFloat(primary, Prop_Data, "m_flNextSecondaryAttack")-GetGameTime() < 1)
						// 	{
						// 		SetEntPropFloat(primary, Prop_Data, "m_flRezoomTime", -1.0);
						// 	}
						// }
						switch(secondaryIndex)
						{
							case 57: //The Razorback protection
							{
								if(g_condFlags[iClient]&TF_CONDFLAG_RAZOR==TF_CONDFLAG_RAZOR)
								{
									g_meterSec[iClient] -= 0.015;
									if(g_meterSec[iClient]<0)
									{
										g_meterSec[iClient] = 0.0;
										g_condFlags[iClient] &= ~TF_CONDFLAG_RAZOR;
									}
								}
							}
							case 231: //Danger shield reducing afterburn time
							{
								if(TF2_IsPlayerInCondition(iClient,TFCond_OnFire))
								{
									float burntime = TF2Util_GetPlayerBurnDuration(iClient);
									burntime -= 0.03;
									TF2Util_SetPlayerBurnDuration(iClient,burntime);
								}
							}
							case 58,1083,1105:
							{
								g_meterSec[iClient] += 0.015; //marker for meter in case of switch
							}
						}
					}
					case TFClass_Spy:
					{
						//restart revolver spread faster, except for amby
						float lastFire = GetEntPropFloat(secondary, Prop_Send, "m_flLastFireTime");
						if(GetGameTime()-lastFire < 0.25 && secondaryIndex!=61 && secondaryIndex!=1006)
						{
							SetEntPropFloat(secondary, Prop_Send, "m_flLastFireTime", lastFire-0.25);
						}

						// spy radar
						if(sapperIndex != 810 && sapperIndex != 831) //exclude Red-Tape
						{
							float meter = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 1);
							float increment = 1.0/20;
							if(g_bIsMVM)
							{
								Address addr = TF2Attrib_GetByName(sapper, "effect bar recharge rate increased");
								if(addr != Address_Null)
								{
									float value = TF2Attrib_GetValue(addr);
									increment /= value;
								}
							}
							if(meter<100.0) { meter+=increment; SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", meter, 1); }
							if(meter>100.0) meter=100.0;
							SetHudTextParams(-0.1, -0.13, 0.5, 255, 255, 255, 255);
							ShowHudText(iClient,3,"RADAR %.0f%%",meter);
						}

						switch(meleeIndex)
						{
							case 649: //spy-cicle
							{
								//update hud and meter
								SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
								int melted = GetEntProp(melee, Prop_Send,"m_bKnifeExists");
								float dur = GetEntPropFloat(melee, Prop_Send,"m_flKnifeRegenerateDuration");
								float time = GetEntPropFloat(melee, Prop_Send,"m_flKnifeMeltTimestamp");
								
								if(g_meterMel[iClient]>time) //keep time the same regardless of ammo drops
									SetEntPropFloat(melee, Prop_Send,"m_flKnifeMeltTimestamp", g_meterMel[iClient]);
								if(melted==0 && dur+time > GetGameTime())
								{
									ShowHudText(iClient,4,"Spy-Cicle: MELTED");
								}
								else
								{
									float knife = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 2);
									if(knife==0)
									{
										SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 100.0, 2);
									}
									else
									{
										if(knife<100.0) { knife+=0.15; SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", knife, 2); }
										if(knife>100.0) knife=100.0;
									}
									ShowHudText(iClient,4,"Spy-Cicle: %.0f%",knife);
								}
								
								if(g_condFlags[iClient] & TF_CONDFLAG_INFIRE) //check for melted debuff
								{
									// g_meterMel[iClient] -= 0.015; //reduce resistance time
									if(GetGameTime() - g_meterMel[iClient] >= 5.0) //reset if time's up
									{
										g_condFlags[iClient] &= ~TF_CONDFLAG_INFIRE;
										SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
										ClientCommand(iClient, "r_screenoverlay \"\"");
										SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") | FCVAR_CHEAT);
									}

									// reducing afterburn time
									float burntime = TF2Util_GetPlayerBurnDuration(iClient);
									burntime -= 0.0225;
									TF2Util_SetPlayerBurnDuration(iClient,burntime);
								}
							}
							case 356: //Kunai max HP drain
							{
								if(g_meterMel[iClient]>0.0)
								{
									if(GetClientHealth(iClient) < GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, iClient))
									{
										g_meterMel[iClient] -= 0.03; //drain at 2/s
										Address addr = TF2Attrib_GetByDefIndex(melee,125);
										float maxHP = TF2Attrib_GetValue(addr);
										if(RoundToCeil(g_meterMel[iClient])<maxHP+40)
										{
											TF2Attrib_SetByDefIndex(melee,125,maxHP-1);
											// TF2Util_TakeHealth(iClient,1.0);
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}

	bool looking = true;
	int place = -1;
	int grenade = -1;
	while(looking)
	{
		grenade = FindEntityByClassname(place, "tf_projectile_pipe");
		if(grenade == -1)
			looking = false;
		else
		{
			place = grenade;
			//iron bomber detection
			int OGweapon = GetEntPropEnt(grenade, Prop_Send, "m_hOriginalLauncher");
			int weapon = GetEntPropEnt(grenade, Prop_Send, "m_hLauncher");
			int owner = GetEntPropEnt(OGweapon, Prop_Send, "m_hOwnerEntity");
			int wepIndex = -1;
			if (OGweapon != -1) wepIndex = GetEntProp(OGweapon, Prop_Send, "m_iItemDefinitionIndex");
			float pos[3],vicPos[3];
			GetEntPropVector(grenade, Prop_Send, "m_vecOrigin", pos);
			
			if(wepIndex == 1151 && IsValidEdict(weapon))
			{
				if(GetEntProp(grenade, Prop_Send, "m_bTouched")==1 && g_Grenades[grenade] <= 0)
				{
					if(g_Grenades[grenade] == 0.0)
					{
						for(int i=1;i<MaxClients;++i)
						{
							if(IsValidClient(i,false))
							{
								if(TF2_GetClientTeam(owner) != TF2_GetClientTeam(i) || owner == i)
								{
									if(getPlayerDistance(grenade,i)<IRON_DETECT)
									{
										GetEntPropVector(i, Prop_Send, "m_vecOrigin", vicPos);
										Handle hndl = TR_TraceRayFilterEx(pos, vicPos, MASK_SOLID, RayType_EndPoint, TraceFilter, grenade);
										bool hit = false;
										if(TR_DidHit() == false)
											hit = true;
										else
										{
											int vic = TR_GetEntityIndex(hndl);
											char[] class = new char[64];
											if(IsValidEdict(vic)) GetEdictClassname(vic, class, 64);
											
											if(StrEqual(class,"func_respawnroomvisualizer") || !IsValidEdict(vic))
												hit = true;
										}
										if(hit)
										{
											SetEntProp(grenade, Prop_Send, "m_bTouched",2);
											g_Grenades[grenade] = 1.0;
											GetEntPropVector(grenade, Prop_Send, "m_vecOrigin", pos);
											EmitSoundToClient(i,"weapons/stickybomblauncher_det.wav",i,SNDCHAN_VOICE_BASE);
											EmitAmbientSound("weapons/stickybomblauncher_det.wav",pos,grenade,SNDLEVEL_MINIBIKE);
											CreateTimer(0.5,KillNeighbor,grenade);
											break;
										}
									}
								}
							}
						}
					}
					else if(g_Grenades[grenade] < 0)
					{
						g_Grenades[grenade] += 0.03;
						if(g_Grenades[grenade]>0)
						{
							if(TF2_GetClientTeam(owner)==TFTeam_Blue)
								CreateParticle(grenade,"stickybomb_pulse_blue",1.0,_,_,_,_,_,_,false,false,true);
							else if(TF2_GetClientTeam(owner)==TFTeam_Red)
								CreateParticle(grenade,"stickybomb_pulse_red",1.0,_,_,_,_,_,_,false,false,true);
							EmitSoundToClient(owner,"weapons/det_pack_timer.wav",owner,SNDCHAN_VOICE_BASE);
							EmitAmbientSound("weapons/det_pack_timer.wav",pos,grenade,SNDLEVEL_MINIBIKE);
							g_Grenades[grenade] = 0.0;
						}
					}
				}
			}
		}
	}
	
	// bool looking = true;
	// int place = -1;
	// while(looking)
	// {
	// 	CART = FindEntityByClassname(place, "team_train_watcher");
	// 	if(CART == -1)
	// 		looking = false;
	// 	else if(GetEntProp(CART, Prop_Data, "m_bHandleTrainMovement"))
	// 		looking = false;
	// 	else
	// 		place = CART;

	// 	if(CART != -1)
	// 	{
	// 		int handle = GetEntProp(CART, Prop_Data,"m_bHandleTrainMovement");
	// 		int level = GetEntProp(CART, Prop_Send,"m_iTrainSpeedLevel");
	// 		int cappers = GetEntProp(CART, Prop_Send,"m_nNumCappers");
	// 		float recede = GetEntPropFloat(CART, Prop_Send,"m_flRecedeTime");
	// 		float speed1 = GetEntPropFloat(CART, Prop_Data,"m_flSpeedForwardModifier");
	// 		PrintToChatAll("%d: %d %d %.2f %d",CART,level,cappers,speed1,handle);
			
	// 		float time = GetGameTime();
	// 		if(recede-time > 15.0)
	// 		{
	// 			SetEntPropFloat(CART, Prop_Send,"m_flRecedeTime",time+14.985);
	// 		}
	// 	}
	// }

	looking = true;
	place = -1;
	int building = -1;
	while(looking)
	{
		building = FindEntityByClassname(place, "obj_*");
		if(building == -1)
			looking = false;
		else
			place = building;

		if(building != -1)
		{
			//update animation speeds for building construction
			char class[64];
			GetEntityClassname(building,class,64);
			int seq = GetEntProp(building, Prop_Send, "m_nSequence");
			float rate = RoundToFloor(GetEntPropFloat(building, Prop_Data, "m_flPlaybackRate")*100)/100.0;

			if(rate>0)
			{
				if((StrEqual(class,"obj_teleporter")||StrEqual(class,"obj_dispenser")) && seq == 1)
				{
					float cycle = GetEntPropFloat(building, Prop_Send, "m_flCycle");
					float cons = GetEntPropFloat(building, Prop_Send, "m_flPercentageConstructed");
					int maxHealth = GetEntProp(building, Prop_Send, "m_iMaxHealth");
					switch(rate)
					{
						case 0.50: { rate = 0.9; SetEntPropFloat(building, Prop_Send, "m_flPlaybackRate", 0.9);  } //not boosted
						case 1.25: { rate = 2.25; SetEntPropFloat(building, Prop_Send, "m_flPlaybackRate", 2.25);  } //wrench boost
						case 1.47: { rate = 2.65; SetEntPropFloat(building, Prop_Send, "m_flPlaybackRate", 2.65); } //jag boost
						case 0.87: { rate = 1.57; SetEntPropFloat(building, Prop_Send, "m_flPlaybackRate", 1.57); } //EE boost
						case 2.00: { rate = 3.60; SetEntPropFloat(building, Prop_Send, "m_flPlaybackRate", 3.60);  } //redeploy no boost
						case 2.75: { rate = 4.95; SetEntPropFloat(building, Prop_Send, "m_flPlaybackRate", 4.95);  } //redeploy boosted
					}
					if(rate!=3.60 || rate!=4.95) //if not redeployed
					{
						if(GetEntProp(building, Prop_Send, "m_iHealth")<RoundFloat(g_buildingHeal[building]))
						{
							SetVariantInt(1);
							AcceptEntityInput(building,"AddHealth");
						}
					}
					SetEntPropFloat(building, Prop_Send, "m_flPercentageConstructed",cycle*1.70 > 1.0 ? 1.0 : cycle*1.70);
					if(cons>=1.00)
					{
						if(rate!=3.60 || rate!=4.95) SetEntProp(building, Prop_Send, "m_iHealth", maxHealth);
						SDKCall(g_hSDKFinishBuilding, building);
						RequestFrame(healBuild,building);
					}
					g_buildingHeal[building]+=rate/4.75;
				}
			}
		}
	}
	// looking = true;
	// int cart = -1;
	// place = -1;
	// while(looking)
	// {
	// 	building = FindEntityByClassname(place, "team_train_*");
	// 	if(building == -1)
	// 		looking = false;
	// 	else
	// 		place = building;

	// 	if(building != -1)
	// 	{
	// 		if(StrEqual(classname, "team_train_watcher")) //payload
	// 		{
	// 			char[] trainName = new char[64];
	// 			GetEntPropString(iEnt, Prop_Data, "m_iszTrain", trainName, 64);
	// 			int i = MaxClients+1;
	// 			// while ((i = FindEntityByClassname(i, "*")) != -1)
	// 			// {
	// 			// 	char[] iName = new char[64];
	// 			// 	GetEntPropString(i, Prop_Data, "m_iName", iName, 64);
	// 			// 	if (!StrEqual(iName, trainName)) continue; // Next
	// 			// 	cart = i;

	// 			// 	SetEntProp(cart, Prop_Data,"m_bHandleTrainMovement",1);
	// 			// 	SetEntData(cart, 1257, 1, _, true);
	// 			// 	SetVariantFloat(2.0);
	// 			// 	SetEntPropFloat(cart, Prop_Data,"m_flSpeedLevels[0]",100.0);
	// 			// 	SetEntPropFloat(cart, Prop_Data,"m_flSpeedLevels[1]",140.0);
	// 			// 	SetEntPropFloat(cart, Prop_Data,"m_flSpeedLevels[2]",180.0);
	// 			// 	SetEntDataFloat(cart,1172,100.0,true);
	// 			// 	SetEntDataFloat(cart,1176,140.0,true);
	// 			// 	SetEntDataFloat(cart,1180,180.0,true);
	// 			// 	AcceptEntityInput(cart,"SetSpeedForwardModifier");
	// 			// 	break; //found it, bail
	// 			// }
	// 		}
	// 	}
	// }
	if(g_bIsMVM)
	{
		//track money for spy magnet
		looking = true;
		place = -1;
		int money = -1;
		while(looking)
		{
			money = FindEntityByClassname(place, "item_currencypack_*");
			if(money == -1)
				looking = false;
			else
				place = money;

			if(IsValidEdict(money))
			{
				g_moneyFrames[money]++;
				if(g_moneyFrames[money]>=22)
				{
					float dist = 0.0,closestDist = 99999.0;
					int range = 250,client = -1,closest = -1;
					for(int i=1;i<MaxClients;++i)
					{
						client = i;
						if(IsValidClient(client))
						{
							if(TF2_GetPlayerClass(client)==TFClass_Spy && !TF2_IsPlayerInCondition(client,TFCond_Cloaked))
							{
								dist = getPlayerDistance(client,money);
								if(dist <= range && closestDist > dist)
								{
									closest = client;
									closestDist = dist;
								}
							}
						}
					}
					if(IsValidClient(closest) && closestDist <= range) //spy money magnet
					{
						float posClient[3],posMoney[3],vec[3],vel[3];
						GetEntPropVector(closest, Prop_Send, "m_vecOrigin", posClient);
						posClient[2]+=10;
						GetEntPropVector(money, Prop_Send, "m_vecOrigin", posMoney);
						posMoney[2]+=10;
						vec[0] = posClient[0] - posMoney[0];
						vec[1] = posClient[1] - posMoney[1];
						vec[2] = posClient[2] - posMoney[2] + 10;
						NormalizeVector(vec,vel);
						float mag = 800.0;
						vel[0]*=mag; vel[1]*=mag; vel[2]*=mag;
						TeleportEntity(money,posMoney,_,vel);
						g_moneyFrames[money] = 0;
					}
				}
			}
		}
	}
}

public Action TF2_OnAddCond(int iClient,TFCond &condition,float &time, int &provider)
{
	TFClassType tfClientClass = TF2_GetPlayerClass(iClient);
	switch (tfClientClass)
	{
		case TFClass_Soldier:
		{
			if(condition==TFCond_BlastJumping)
			{
				int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
				int primaryIndex = -1;
				if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
				if(primaryIndex==1104) //don't reduce air strike blast radius
				{
					TF2Attrib_SetByDefIndex(primary,100,1.0);
				}
			}
			if(condition==TFCond_Slowed)
			{
				g_meterPri[iClient] = 0.0;
			}
		}
		case TFClass_Heavy:
		{
			if(condition == TFCond_CritCola) //steak resistances & duration
			{
				int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
				TF2Attrib_SetByDefIndex(secondary,252,0.25); //damage force reduction
				TF2Attrib_SetByDefIndex(secondary,329,0.25); //airblast vulnerability multiplier
				g_meterSec[iClient] = 0.0;
			}
			if(condition == TFCond_CritOnKill && time == 6.0)
			{
				time = TFCondDuration_Infinite;
			}
			if(condition == TFCond_Taunting)
			{
				int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
				int secondaryIndex = -1;
				if(secondary != -1) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
				if(311 == secondaryIndex || 159 == secondaryIndex || 433 == secondaryIndex)
				{
					if(g_condFlags[iClient] & TF_CONDFLAG_EATING)
					{
						if(433 == secondaryIndex)
						{
							int secondaryAmmo = GetEntProp(secondary, Prop_Send, "m_iPrimaryAmmoType");
							SetEntProp(iClient, Prop_Data, "m_iAmmo", 0, _, secondaryAmmo);
							SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",0.0,1);
						}
						buffSteak(iClient); //add steak and dalokohs healing
					}
				}
			}
		}
		case TFClass_Sniper,TFClass_Spy:
		{
			int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
			int secondaryIndex = -1;
			if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
			int melee = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Melee, true);
			int meleeIndex = -1;
			if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
			switch(condition) //decrease debuffs with danger shield or spy-cicle (except afterburn because it's weird)
			{
				case TFCond_Jarated,TFCond_Milked,TFCond_MarkedForDeath,TFCond_MarkedForDeathSilent,TFCond_Gas:
				{
					if(secondaryIndex==231)
						time *= 0.33;
					if(meleeIndex==649 && g_condFlags[iClient] & TF_CONDFLAG_INFIRE)
						time *= 0.25;
				}
			}
		}
		case TFClass_Pyro:
		{
			//check if pyro ignited self with flare to add blast jump
			if(condition == TFCond_OnFire && provider == iClient)
			{
				g_condFlags[iClient] |= TF_CONDFLAG_BLJUMP;
			}
		}
	}
	switch (condition)
	{
		case TFCond_OnFire,TFCond_BurningPyro: //healing debuff on ALL afterburn
		{
			if(provider != iClient)
			{
				DataPack pack = new DataPack();
				pack.Reset();
				pack.WriteCell(iClient);
				pack.WriteCell(provider);
				pack.WriteFloat(time);
				CreateTimer(0.03,FireDebuff,pack);
			}
		}
		case TFCond_FocusBuff: //reset Heatmaker tracer
		{
			int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
			TF2Attrib_SetByDefIndex(primary,144,1.0);
			TF2Attrib_SetByDefIndex(primary,51,1.0);
		}
		case TFCond_Jarated:
		{
			if(time<5.0) //set sleeper jarate time to 2 secs minimum
				time=3.015;
		}
		case TFCond_UberFireResist,TFCond_UberBulletResist,TFCond_UberBlastResist:
		{
			if(provider==iClient)
				g_lastVaccHeal[iClient] = -1.0;
			else
				g_lastVaccHeal[iClient] = GetGameTime()-0.03;
			float value = 0.0;
			if(g_bIsMVM)
			{
				int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
				Address addr = TF2Attrib_GetByName(secondary, "uber duration bonus");
				if(addr != Address_Null)
				{
					value = TF2Attrib_GetValue(addr);
					value /= 4.0;
				}
			}
			time = 4.24 + value; //update time
		}
		case TFCond_DeadRingered: //make sure DR starts at full
		{
			int watch = TF2Util_GetPlayerLoadoutEntity(iClient, 6, true);
			int watchIndex = -1;
			if(watch >= 0) watchIndex = GetEntProp(watch, Prop_Send, "m_iItemDefinitionIndex");
			if(watchIndex == 59)
			{
				RequestFrame(DeadRingCheck,iClient);
			}
		}
		case TFCond_Charging:
		{
			int melee = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Melee, true);
			int meleeIndex = -1;
			if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
			switch(meleeIndex)
			{
				case 172:
				{
					TF2Attrib_SetByDefIndex(melee,54,1.0); //negate skullcutter speed
				}
			}
		}
		case TFCond_BlastJumping:
		{
			g_condFlags[iClient] |= TF_CONDFLAG_BLJUMP;
		}
		case TFCond_CritMmmph:
		{
			float meter = GetEntPropFloat(iClient, Prop_Send, "m_flRageMeter");
			if(meter <= 0.0)
			{
				time = 0.0;
				return Plugin_Stop;
			}
		}
		case TFCond_MarkedForDeath:
		{
			if(IsValidClient(provider))
			{
				int melee = TF2Util_GetPlayerLoadoutEntity(provider, TFWeaponSlot_Melee, true);
				int meleeIndex = -1;
				if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
				//bushwacka mfd adjustment
				if(TF2_GetPlayerClass(provider)==TFClass_Sniper && meleeIndex==232)
				{
					time = 2.1;
				}
			}
		}
	}
	return Plugin_Changed;
}

public Action TF2_OnRemoveCond(int iClient,TFCond &condition,float &time, int &provider)
{
	TFClassType tfClientClass = TF2_GetPlayerClass(iClient);
	switch (tfClientClass)
	{
		case TFClass_Soldier:
		{
			if(condition==TFCond_BlastJumping)
			{
				int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
				int primaryIndex = -1;
				if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
				if(primaryIndex==1104) //reset air strike blast radius
				{
					TF2Attrib_SetByDefIndex(primary,100,0.8);
				}
				int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
				int secondaryIndex = -1;
				if(secondary != -1) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
				if(secondaryIndex==444) //mantreads resistance
				{
					CreateTimer(0.15,ResetBlast,iClient);
				}
			}
		}
		case TFClass_Heavy:
		{
			if(condition == TFCond_Taunting)
			{
				TF2Attrib_SetByDefIndex(iClient,201,1.0); //deactivate faster animations after eating steak ends
				g_condFlags[iClient] &= ~TF_CONDFLAG_EATING;
			}
			else if(condition == TFCond_CritCola) //steak resistances & duration
			{
				int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
				TF2Attrib_SetByDefIndex(secondary,252,1.0); //damage force reduction
				TF2Attrib_SetByDefIndex(secondary,329,1.0); //airblast vulnerability multiplier
			}
		}
		case TFClass_Medic:
		{
			switch(condition)
			{
				case TFCond_UberFireResist,TFCond_UberBulletResist,TFCond_UberBlastResist:
				{
					if(time>0.0)
						return Plugin_Handled;
				}
			}
		}
		case TFClass_Pyro:
		{
			if(condition == TFCond_Taunting && TF2_IsPlayerInCondition(iClient,TFCond_CritMmmph))
			{
				RequestFrame(MmmphCheck,iClient); //stop phlog cancelling, add speed boost when over
			}
		}
	}
	switch(condition)
	{
		case TFCond_OnFire,TFCond_BurningPyro:
		{
			//Volcano Fire Debuff
			if(g_condFlags[iClient] & TF_CONDFLAG_VOLCANO)
				g_condFlags[iClient] &= ~TF_CONDFLAG_VOLCANO;
			//healing debuff on ALL afterburn
			TF2Util_SetPlayerConditionDuration(iClient,TFCond_HealingDebuff,0.0);
		}
		case TFCond_FocusBuff: //reset Heatmaker tracer
		{
			int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
			TF2Attrib_SetByDefIndex(primary,144,3.0);
			TF2Attrib_SetByDefIndex(primary,51,0.0);
		}
		case TFCond_Cloaked: //dead ringer reset cloak
		{
			int watch = TF2Util_GetPlayerLoadoutEntity(iClient, 6, true);
			int watchIndex = -1;
			if(watch >= 0) watchIndex = GetEntProp(watch, Prop_Send, "m_iItemDefinitionIndex");
			if(watchIndex == 59)
			{
				float cloak = GetEntPropFloat(iClient, Prop_Send,"m_flCloakMeter");
				SetEntPropFloat(iClient, Prop_Send,"m_flCloakMeter",cloak>50 ? cloak-50 : 0.0);
			}
		}
		case TFCond_CritHype: //block Soda hype
		{
			float hype = GetEntPropFloat(iClient, Prop_Send,"m_flHypeMeter");
			if(hype>=(HYPE_COST*(Pow(2.0,g_jumpCount[iClient]+0.0))))
			{
				return Plugin_Handled;
			}
		}
		case TFCond_Charging:
		{
			int melee = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Melee, true);
			int meleeIndex = -1;
			if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
			switch(meleeIndex)
			{
				case 172:
				{
					TF2Attrib_SetByDefIndex(melee,54,0.85); //reset skullcutter speed
				}
			}
		}
		case TFCond_Disguised:
		{
			int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
			int secondaryIndex = -1;
			if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
			if(secondaryIndex==460) //enforcer set last disguise
			{
				float disguise = 0.0;
				int target = GetEntPropEnt(iClient, Prop_Send, "m_hDisguiseTarget");
				int class = GetEntProp(iClient, Prop_Send, "m_nDisguiseClass");
				int team = GetEntProp(iClient, Prop_Send, "m_nDisguiseTeam");
				disguise += target;
				disguise += class*100;
				disguise += team*1000;
				g_meterSec[iClient] = disguise;
			}
		}
		case TFCond_BlastJumping:
		{
			if(g_condFlags[iClient] & TF_CONDFLAG_BLJUMP)
				return Plugin_Handled;
		}
		case TFCond_AirCurrent:
		{
			if(g_condFlags[iClient] & TF_CONDFLAG_HOVER)
				return Plugin_Handled;
		}
	}
	return Plugin_Changed;
}

public Action OnPlayerRunCmd(int iClient, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if((IsValidClient(iClient) && IsPlayerAlive(iClient)))
	{	
		bool buttonsModified = false;
		TFClassType tfClientClass = TF2_GetPlayerClass(iClient);
		int clientFlags = GetEntityFlags(iClient);
		int curr = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
		float currVel[3];
		GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", currVel);
		float position[3];
		GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", position);
		int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
		int primaryIndex = -1;
		if(primary != -1) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
		int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
		int secondaryIndex = -1;
		if(secondary != -1) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
		int melee = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Melee, true);
		int meleeIndex = -1;
		if(melee != -1) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
		int sapper = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Building, true);
		int sapperIndex = -1;
		if(sapper >= 0) sapperIndex = GetEntProp(sapper, Prop_Send, "m_iItemDefinitionIndex");
	
		switch(tfClientClass)
		{
			case TFClass_Sniper:
			{
				//handle Sniper rifle reloads
				int reload = GetEntProp(primary, Prop_Send, "m_iReloadMode");
				int view = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
				int sequence = GetEntProp(view, Prop_Send, "m_nSequence");

				int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
				int clip = GetEntData(primary, iAmmoTable, 4);

				int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
				int ammoCount = GetEntProp(iClient, Prop_Data, "m_iAmmo", _, primaryAmmo);

				float reloadSpeed = 2.0;
				if(primaryIndex == 230) reloadSpeed=1.5;
				int maxClip = 4;
				if(primaryIndex==526 || primaryIndex==30665) maxClip=3; //machina clip
				if(g_bIsMVM) //mvm clip
				{
					Address addr = TF2Attrib_GetByName(primary, "clip size bonus");
					if(addr != Address_Null)
					{
						float value = TF2Attrib_GetValue(addr);
						maxClip = RoundFloat(maxClip * value);
					}
				}

				int relSeq = 41;
				float altRel = 0.875;
				if(primaryIndex == 851 || primaryIndex == 1098)
				{
					relSeq = 5;
					altRel = 0.5625;
				}

				if(curr==primary)
				{
					if(primaryIndex==56 || primaryIndex==1005 || primaryIndex==1092) //huntsman passive reload
					{
						maxClip = 1;
						if(clip==0 && ammoCount>0 && weapon != 0 && weapon != primary)
						{
							SetEntProp(iClient, Prop_Data, "m_iAmmo", ammoCount-1 , _, primaryAmmo);
							SetEntData(primary, iAmmoTable, 1, 4, true);
						}
					}
					else
					{
						//fire the classic in mid-air
						// float charge = GetEntPropFloat(primary, Prop_Send, "m_flChargedDamage");
						// if((currVel[2]!=0.0 || !(clientFlags & FL_ONGROUND)) && ((g_TrueLastButtons[iClient] & IN_ATTACK == IN_ATTACK) && !(buttons & IN_ATTACK == IN_ATTACK)))
						// {
						// 	g_TrueLastButtons[iClient] = buttons;
						// 	buttons |= IN_ATTACK;
						// 	buttonsModified = true;
						// 	TF2Attrib_SetByDefIndex(primary,636,0.0); //sniper crit no scope
						// 	TF2_RemoveCondition(iClient,TFCond_Slowed);
						// 	SetEntityFlags(iClient,clientFlags | FL_ONGROUND);
						// 	RequestFrame(ResetClassic,iClient);
						// }

						//fire sniper without ammo
						if(primaryIndex==1098)
						{
							if(((g_TrueLastButtons[iClient] & IN_ATTACK && !(buttons & IN_ATTACK)) || buttons & IN_ATTACK2) && clip > 0 && ammoCount == 0)
							{
								SetEntProp(iClient, Prop_Data, "m_iAmmo", 1, _, primaryAmmo);
								RequestFrame(DryFireSniper,iClient);
							}
						}
						else
						{
							if((buttons & IN_ATTACK || buttons & IN_ATTACK2) && clip > 0 && ammoCount == 0)
							{
								SetEntProp(iClient, Prop_Data, "m_iAmmo", 1, _, primaryAmmo);
								RequestFrame(DryFireSniper,iClient);
							}
						}
						// float timeSince = GetGameTime()-GetEntPropFloat(primary, Prop_Send, "m_flNextPrimaryAttack"); // || (!TF2_IsPlayerInCondition(iClient,TFCond_Slowed) && timeSince>0.1)
						if(((buttons & IN_RELOAD) || clip==0) && reload==0 && (sequence==30 || sequence==33) && clip<maxClip && ammoCount>0)
						{
							g_meterPri[iClient] = 0.0;
							SetEntProp(primary, Prop_Send, "m_iReloadMode",1);
							SetEntProp(view, Prop_Send, "m_nSequence",relSeq);
							SetEntPropFloat(view, Prop_Send, "m_flPlaybackRate",(2.0*altRel)/reloadSpeed);
							if ((TF2_IsPlayerInCondition(iClient,TFCond_Slowed) && primaryIndex!=1098) && !TF2_IsPlayerInCondition(iClient,TFCond_FocusBuff))
							{
								buttons |= IN_ATTACK2;
							}
						}
						if(reload!=0)
						{
							if(buttons & IN_ATTACK)
							{
								if(clip>0)
								{
									SetEntProp(primary, Prop_Send, "m_iReloadMode",0);
									g_meterPri[iClient] = 0.0;
								}
								else
									buttons &= ~IN_ATTACK;
							}
							if(buttons & IN_ATTACK2 && !TF2_IsPlayerInCondition(iClient,TFCond_FocusBuff) && primaryIndex!=1098)
								buttons &= ~IN_ATTACK2;
							if(g_meterPri[iClient]>=reloadSpeed)
							{

								int newClip = ammoCount-maxClip+clip < 0 ? ammoCount+clip : maxClip;
								int newAmmo  = ammoCount-maxClip+clip >= 0 ? ammoCount-maxClip+clip : 0;
								SetEntProp(iClient, Prop_Data, "m_iAmmo", newAmmo , _, primaryAmmo);
								SetEntData(primary, iAmmoTable, newClip, 4, true);
								SetEntProp(primary, Prop_Send, "m_iReloadMode",0);
								SetEntProp(view, Prop_Send, "m_nSequence",30);
								g_meterPri[iClient] = 0.0;
							}
						}
						else if(TF2_IsPlayerInCondition(iClient,TFCond_FocusBuff) && clip<maxClip)
						{
							int newClip = ammoCount-maxClip+clip < 0 ? ammoCount+clip : maxClip;
							int newAmmo  = ammoCount-maxClip+clip >= 0 ? ammoCount-maxClip+clip : 0;
							SetEntProp(iClient, Prop_Data, "m_iAmmo", newAmmo , _, primaryAmmo);
							SetEntData(primary, iAmmoTable, newClip, 4, true);
						}
						if(buttons & IN_RELOAD) buttons &= ~IN_RELOAD;
						if(buttons & IN_ATTACK3) buttons |= IN_RELOAD;
					}
				}
			}
			case TFClass_Pyro:
			{
				if(curr==primary)
				{
					if(primaryIndex == 594)
					{
						//handle phlog alt-fire
						if((buttons & IN_ATTACK2))
						{
							buttons &= ~IN_ATTACK2;
							int view = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
							if (!IsValidEdict(view)) return Plugin_Continue;
							int seqNum = GetEntProp(view, Prop_Send, "m_nSequence");
							int weaponState = GetEntProp(primary, Prop_Send, "m_iWeaponState");
							float nextAttack = GetEntPropFloat(primary, Prop_Send, "m_flNextSecondaryAttack");
							float time = GetGameTime();

							if(seqNum==13 && nextAttack-0.2 < time)
								SetEntProp(view, Prop_Send, "m_nSequence",10);
							if ((weaponState==0 || weaponState==2) && nextAttack < time && !(g_condFlags[iClient] & TF_CONDFLAG_LOSER == TF_CONDFLAG_LOSER))
							{
								SetEntPropFloat(primary, Prop_Send, "m_flNextPrimaryAttack", (time + 0.99));
								SetEntPropFloat(primary, Prop_Send, "m_flNextSecondaryAttack", (time + 0.75));
								Phlog_SecondaryAttack(primary,iClient,angles,vel[2],clientFlags,buttons);
							}
						}
						if((buttons & IN_ATTACK3))
						{
							buttons &= ~IN_ATTACK3;
							buttons |= IN_ATTACK2;
						}
					}
					else //handle airblast
					{
						float meter = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0);
						if(primaryIndex == 1178) meter = g_meterPri[iClient];
						float meter2 = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 10);
						int weaponState = GetEntProp(primary, Prop_Send, "m_iWeaponState");
						if(weaponState==3) //in-airblast
						{
							if((meter2<meter)) //done to make limit it to first frame in this state
							{
								if((vel[2]!=0.0 || !(clientFlags & FL_ONGROUND) || buttons & IN_JUMP))
								{
									AirblastPush(iClient,meter);
									meter = 0.0;
								}
								else
									meter -= PRESSURE_COST;
								if(meter<0.0) meter = 0.0;
								
								SetEntPropFloat(primary, Prop_Send, "m_flLastFireTime",GetGameTime()+0.75);
								//update pressure meter
								if(primaryIndex == 1178) g_meterPri[iClient] = meter;
								else SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", meter, 0);
								SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", meter, 10);

								float newMeter = meter/100;
								if(g_bIsMVM) //mvm force
								{
									Address addr = TF2Attrib_GetByName(primary, "melee range multiplier");
									if(addr != Address_Null)
									{
										float value = TF2Attrib_GetValue(addr);
										newMeter *= value;
									}
								}
								TF2Attrib_SetByDefIndex(primary,255,newMeter); //set next airblast force
								// RequestFrame(CheckReflect,iClient);
							}
						}
					}
				}
				// manmelter
				if(secondaryIndex == 595)
				{
					int crits = GetEntProp(iClient, Prop_Send, "m_iRevengeCrits");
					// make sure revenge crits are active
					if(curr==secondary)
					{
						if(crits>0 && !isKritzed(iClient))
							TF2_AddCondition(iClient,TFCond_Kritzkrieged,1.0);
					}
				}
				//thruster
				if(1179 == secondaryIndex)
				{
					float regen = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 1);
					bool rocketing = GetEntPropFloat(secondary, Prop_Send, "m_flLaunchTime") != 0.0 || TF2_IsPlayerInCondition(iClient,TFCond_RocketPack) || TF2_IsPlayerInCondition(iClient,TFCond_Parachute) || TF2_IsPlayerInCondition(iClient,TFCond_ParachuteDeployed);
					if((currVel[2]!=0.0 || !(clientFlags & FL_ONGROUND)) && !rocketing && regen > 50)
					{
						if ((buttons & IN_JUMP) && !(g_LastButtons[iClient] & IN_JUMP) && g_meterSec[iClient] >= 0.125)
						{
							//activate jetpack boost, consume 50% charge
							g_meterSec[iClient] = 0.0;
							TF2_AddCondition(iClient,TFCond_Dazed,1.0);
							TF2_AddCondition(iClient,TFCond_AirCurrent);
							TF2_AddCondition(iClient,TFCond_RocketPack);
							g_condFlags[iClient] |= TF_CONDFLAG_HOVER;

							SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",regen-50.0,1);
							float angle = angles[1]*0.01745329;
							if(vel[0] != 0 && vel[1] != 0)
							{
								vel[0] *= 0.71; vel[1] *= 0.71;
							}
							currVel[0] = ((vel[0] * Cosine(angle)) - (-vel[1] * Sine(angle)))*0.60; //scale horizontal force
							currVel[1] = ((-vel[1] * Cosine(angle)) + (vel[0] * Sine(angle)))*0.60; //scale horizontal force
							currVel[2] = 460.0; //fixed height
							TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, currVel);
							//boost fx
							float exAngle = 0.0;
							vel[0] *= 1.25; vel[1] *= 1.25; 
							if(vel[0]!=0)
							{
								if(vel[1]!=0) exAngle = vel[1] > 0 ? 45.0 : 135.0;
								else exAngle = 90.0;
								if(vel[0]<0) exAngle *= -1;
							}
							else exAngle = vel[1] < 0 ? 180.0 : 0.0;
							if(!(vel[0]!=0 || vel[1]!=0)) exAngle += angles[1];
							else exAngle += angles[1] - 90;
							CreateParticle(iClient,"rocketpack_exhaust",0.33,-90.0,exAngle,_,_,42.0);
							EmitAmbientSound("weapons/rocket_pack_boosters_charge.wav",position,iClient);
						}
					}
				}
			}
			case TFClass_Heavy:
			{
				//allow holster in minigun spindown
				if(primary != -1)
				{
					int weaponState = GetEntProp(primary, Prop_Send, "m_iWeaponState");
					int view = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
					int sequence = GetEntProp(view, Prop_Send, "m_nSequence");
					float cycle = GetEntPropFloat(view, Prop_Data, "m_flCycle");
					float time = GetGameTime();
					if(sequence == 23 && weaponState == 0)
					{
						int done = GetEntProp(view, Prop_Data, "m_bSequenceFinished");
						if (done == 0) SetEntProp(view, Prop_Data, "m_bSequenceFinished", true, .size = 1);

						float idle = 0.0;
						if(g_bIsMVM) //mvm spindown upgrade
						{
							Address addr = TF2Attrib_GetByName(primary, "melee range multiplier");
							if(addr != Address_Null)
							{
								float value = TF2Attrib_GetValue(addr);
								if(value>0)
								{
									idle = 1.0;
								}
							}
						}
						if(cycle < 0.2 && idle > 0) //set idle time faster
						{
							SetEntPropFloat(secondary, Prop_Send, "m_flNextPrimaryAttack",time+0.5);
							SetEntPropFloat(primary, Prop_Send, "m_flTimeWeaponIdle",time+idle);
						}
					}
				}
				if(311 == secondaryIndex || 159 == secondaryIndex || 433 == secondaryIndex)//steak and dalokohs stuff
				{

					float nextAtk = GetEntPropFloat(secondary, Prop_Send, "m_flNextPrimaryAttack");
					if(buttons & IN_ATTACK && curr == secondary && nextAtk<=(GetGameTime()+0.06)) //setup steak and chocolate heals
					{
						g_condFlags[iClient] |= TF_CONDFLAG_EATING;
						TF2Attrib_AddCustomPlayerAttribute(iClient, "gesture speed increase", 1.7, 2.0);
						// TF2Attrib_SetByDefIndex(iClient,201,1.7); //revert eating speed
					}
				}
				//KGB start timer
				if(TF2Util_GetPlayerConditionDuration(iClient,TFCond_CritOnKill)==TFCondDuration_Infinite)
				{
					float nextAtk = GetEntPropFloat(curr, Prop_Send, "m_flNextPrimaryAttack");
					float nextAtk2 = GetEntPropFloat(curr, Prop_Send, "m_flNextSecondaryAttack");
					char wep[64];
					GetEntityClassname(curr,wep,64);
					if((curr==primary && GetEntProp(primary, Prop_Send, "m_iWeaponState") == 1) ||
					   (curr==secondary && (buttons & IN_ATTACK || (buttons & IN_ATTACK2 && secondaryIndex == 1153)) && nextAtk2 <= GetGameTime() && StrContains(wep,"shotgun",false) != -1) ||
					   (curr==melee && (buttons & IN_ATTACK || buttons & IN_ATTACK2) && nextAtk <= GetGameTime()))
					{
						if(curr==primary) TF2Util_SetPlayerConditionDuration(iClient,TFCond_CritOnKill,4.0);
						else TF2Util_SetPlayerConditionDuration(iClient,TFCond_CritOnKill,3.1);
					}
				}
			}
			case TFClass_Engineer:
			{
				if(IsValidEdict(curr))
				{
					char classname[64];
					GetEntityClassname(curr,classname,64);
					if(StrEqual(classname,"tf_weapon_builder") && meleeIndex == 155)
					{
						float speed = GetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed");
						if(speed==270.0)
						{
							SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",243.0);
						}
					}
					if(secondaryIndex == 528 && curr==secondary) //short circuit charge
					{
						int view = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
						if(g_meterSec[iClient]>=0 && GetEntProp(iClient, Prop_Data, "m_iAmmo", 4, 3) >= 65)
						{
							if(buttons & IN_ATTACK2 == IN_ATTACK2 && (!(g_TrueLastButtons[iClient] & IN_ATTACK2 == IN_ATTACK2) || g_meterSec[iClient]>0))
							{
								if(g_meterSec[iClient]==0.0)
								{
									g_meterSec[iClient] = 0.015;
									TF2_AddCondition(iClient,TFCond_FocusBuff);
									EmitSoundToClient(iClient,"weapons/cow_mangler_over_charge.wav",iClient,SNDCHAN_VOICE_BASE);
								}
								if(g_meterSec[iClient]>0) g_meterSec[iClient] += 0.015;
								weapon = 0;
								g_TrueLastButtons[iClient] = buttons;
								buttons &= ~IN_ATTACK;
								buttonsModified = true;
							}
							if(g_TrueLastButtons[iClient] & IN_ATTACK2 == IN_ATTACK2 && (!(buttons & IN_ATTACK2 == IN_ATTACK2) || g_meterSec[iClient] >= 1.9) && g_meterSec[iClient] < 2.0 && g_meterSec[iClient]!=0.0)
							{
								g_condFlags[iClient] |= TF_CONDFLAG_INFIRE;
								TF2_RemoveCondition(iClient,TFCond_FocusBuff);
								SetEntProp(view, Prop_Send, "m_nSequence",27);
								EmitSoundToClient(iClient,"weapons/barret_arm_shot.wav",iClient,SNDCHAN_VOICE_BASE);
								SetEntPropFloat(secondary, Prop_Send, "m_flNextSecondaryAttack",GetGameTime());
								SetEntPropFloat(secondary, Prop_Send, "m_flNextPrimaryAttack",GetGameTime()+0.5);
								g_TrueLastButtons[iClient] = buttons;
								buttons |= IN_ATTACK2;
								buttonsModified = true;
							}
						}
						else if(GetEntProp(iClient, Prop_Data, "m_iAmmo", 4, 3) < 65 && buttons & IN_ATTACK2 == IN_ATTACK2 && !(g_TrueLastButtons[iClient] & IN_ATTACK2 == IN_ATTACK2))
						{
							EmitSoundToClient(iClient,"weapons/barret_arm_fizzle.wav",iClient,SNDCHAN_VOICE_BASE);
						}
					}
				}
			}
			case TFClass_DemoMan:
			{
				//mini-crit boost the caber during shield charge
				if (curr == melee && meleeIndex==307 && TF2_IsPlayerInCondition(iClient,TFCond_Charging))
				{
					//make sure it's not intact while attacking
					if((buttons & IN_ATTACK == IN_ATTACK) && !(g_LastButtons[iClient] & IN_ATTACK == IN_ATTACK) && GetEntProp(melee, Prop_Send, "m_bBroken") != 0)
					{
						float charge = GetEntPropFloat(iClient, Prop_Send, "m_flChargeMeter");
						if((charge<75 && charge>40) || (charge<75 && secondaryIndex==1099))
							TF2_AddCondition(iClient,TFCond_CritCola,0.6);
					}
				}
				//new shield leap
				char classname[64];
				GetEntityClassname(secondary,classname,64);
				if(StrEqual(classname,"tf_wearable_demoshield"))
				{
					float meter = GetEntPropFloat(iClient, Prop_Send,"m_flChargeMeter");
					if((currVel[2]==0.0 || (clientFlags & FL_ONGROUND)) && meter > 50)
					{
						if ((buttons & IN_ATTACK3) && !(g_LastButtons[iClient] & IN_ATTACK3))
						{
							//activate shield leap
							TF2_AddCondition(iClient,TFCond_Dazed,1.0);
							TF2_AddCondition(iClient,TFCond_AirCurrent);
							g_condFlags[iClient] |= TF_CONDFLAG_HOVER;
							DataPack pack = new DataPack();
							pack.Reset();
							pack.WriteCell(iClient);
							pack.WriteFloat(meter-49.5);
							RequestFrame(LeapCharge,pack);

							currVel[2] = 550.0;
							//only while not charging
							if(!TF2_IsPlayerInCondition(iClient,TFCond_Charging))
							{
								float angle = angles[1]*0.01745329;
								if(vel[0] != 0 && vel[1] != 0)
								{
									vel[0] *= 0.71; vel[1] *= 0.71;
								}
								currVel[0] = ((vel[0] * Cosine(angle)) - (-vel[1] * Sine(angle)))*0.7; //0.875
								currVel[1] = ((-vel[1] * Cosine(angle)) + (vel[0] * Sine(angle)))*0.7; //0.875
								//speed modifiers
								if(primaryIndex == 405 || primaryIndex == 608)
								{ currVel[0]*=1.1; currVel[1]*=1.1; }
								if(secondaryIndex == 132 || secondaryIndex == 266 || secondaryIndex == 482 || secondaryIndex == 1082)
								{
									int heads = GetEntProp(iClient, Prop_Send, "m_iDecapitations");
									heads = heads > 4 ? 4 : heads;
									float boost = 1.0 + 0.8*heads;
									currVel[0]*=boost; currVel[1]*=boost;
								}
								if(TF2_IsPlayerInCondition(iClient,TFCond_SpeedBuffAlly))
								{ currVel[0]*=1.35; currVel[1]*=1.35; }

								if(g_bIsMVM) //mvm jump height
								{
									Address addr = TF2Attrib_GetByName(iClient, "major move speed bonus");
									if(addr != Address_Null)
									{
										float value = TF2Attrib_GetValue(addr);
										currVel[0]*=value; currVel[1]*=value;
									}
								}
							}
							else
								TF2_RemoveCondition(iClient,TFCond_Charging);
							if(g_bIsMVM) //mvm jump height
							{
								Address addr = TF2Attrib_GetByName(iClient, "major increased jump height");
								if(addr != Address_Null)
								{
									float value = TF2Attrib_GetValue(addr);
									currVel[2]*=value;
								}
							}
							TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, currVel);

							//boost fx
							float exAngle = 0.0;
							vel[0] *= 1.25; vel[1] *= 1.25;
							if(vel[0]!=0)
							{
								if(vel[1]!=0) exAngle = vel[1] > 0 ? 45.0 : 135.0;
								else exAngle = 90.0;
								if(vel[0]<0) exAngle *= -1;
							}
							else exAngle = vel[1] < 0 ? 180.0 : 0.0;
							if(!(vel[0]!=0 || vel[1]!=0)) exAngle += angles[1];
							else exAngle += angles[1] + 90;
							CreateParticle(iClient,"mvm_loot_dustup",2.0,_,exAngle,_,_,100.0,1.5,false);
							int rndact = GetRandomUInt(0,3);
							switch(rndact)
							{
								case 0: EmitAmbientSound("vo/taunts/demo/taunt_demo_exert_04.mp3",position,iClient);
								case 1: EmitAmbientSound("vo/taunts/demo/taunt_demo_exert_06.mp3",position,iClient);
								case 2: EmitAmbientSound("vo/taunts/demo/taunt_demo_exert_08.mp3",position,iClient);
								case 3: EmitAmbientSound("vo/taunts/demo/taunt_demo_flip_exert_03.mp3",position,iClient);
							}
						}
					}
				}
			}
			case TFClass_Medic:
			{
				//create new syringes for medic
				if (curr == primary && (buttons & IN_ATTACK == IN_ATTACK))
				{
					g_condFlags[iClient] |= TF_CONDFLAG_INFIRE;
				}
				else if ((g_LastButtons[iClient] & IN_ATTACK))
				{
					g_condFlags[iClient] &= ~TF_CONDFLAG_INFIRE;
				}
				if (curr == secondary && secondaryIndex==411) //quick-fix
				{
					//pop uber
					float atk = GetEntPropFloat(secondary, Prop_Send, "m_flNextSecondaryAttack");
					if(buttons & IN_ATTACK2 == IN_ATTACK2 && !(g_condFlags[iClient] & TF_CONDFLAG_QUICK) && atk<GetGameTime())
					{
						TF2Attrib_SetByDefIndex(secondary,144,2.0);
						float meter = GetEntPropFloat(secondary, Prop_Send, "m_flChargeLevel");
						if(meter>=1.0)
						{
							g_condFlags[iClient] |= TF_CONDFLAG_QUICK;
							g_meterSec[iClient] = GetGameTime() - 6 + 6*meter;
							SetEntPropFloat(secondary, Prop_Send, "m_flChargeLevel", 1.0);
						}
					}
				}
			}
			case TFClass_Spy:
			{
				if(TF2_IsPlayerInCondition(iClient,TFCond_Disguised)&&g_condFlags[iClient]&TF_CONDFLAG_SPYTAUNT)
				{
					if(g_meterPri[iClient]>0.0)
					{
						SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",1.0);
						g_meterPri[iClient]-=0.015;
						buttons=0;
						impulse=0;
						weapon=0;

						int sequence = GetEntProp(iClient, Prop_Data, "m_nSequence");
						if(sequence!=g_spyTaunt[iClient])
						{
							SetEntProp(iClient, Prop_Data, "m_nSequence",g_spyTaunt[iClient]);
							SetEntData(iClient, 1008, g_spyTaunt[iClient], _, true);
							SetEntPropFloat(iClient, Prop_Data, "m_flCycle", (g_spyTauntTime[iClient]-g_meterPri[iClient])/g_spyTauntTime[iClient]);
							SetEntDataFloat(iClient, 1004, (g_spyTauntTime[iClient]-g_meterPri[iClient])/g_spyTauntTime[iClient], true);
						}
					}
					else
					{
						SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",320.0);
						g_condFlags[iClient]&= ~TF_CONDFLAG_SPYTAUNT;
						SetVariantInt(0);
						AcceptEntityInput(iClient, "SetForcedTauntCam");
					}
				}

				//reset ammo from fake reload
				if(g_condFlags[iClient] & TF_CONDFLAG_FAKE)
				{
					int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
					int clip = GetEntData(secondary, iAmmoTable, 4);
					int secondaryAmmo = GetEntProp(secondary, Prop_Send, "m_iPrimaryAmmoType");
					int ammoCount = GetEntProp(iClient, Prop_Data, "m_iAmmo", _, secondaryAmmo);
					SetEntData(secondary, iAmmoTable, clip+1, 4);
					SetEntProp(iClient, Prop_Data, "m_iAmmo", ammoCount-1, _, secondaryAmmo);
					g_condFlags[iClient] &= ~TF_CONDFLAG_FAKE;
				}
				// spy radar
				if(sapperIndex != 810 && sapperIndex != 831) //exclude Red-Tape
				{
					if((buttons & IN_RELOAD) && curr == sapper && !TF2_IsPlayerInCondition(iClient,TFCond_Cloaked) && !TF2_IsPlayerInCondition(iClient,TFCond_CloakFlicker))
					{
						float meter = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 1);
						if(meter>=100)
						{
							SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, 1);
							EmitAmbientSound("misc/rd_finale_beep01.wav",position,iClient,SNDLEVEL_MINIBIKE,_,3.0);
							SetEntProp(iClient, Prop_Send, "m_bGlowEnabled", 1);
							CreateTimer(5.0,updateGlow,iClient);
							int idx, currEnts = GetMaxEntities();
							for (idx = 1; idx < currEnts; idx++) {
								if(idx<=MaxClients) //find enemy players
								{
									if (IsValidClient(idx,false) && idx != iClient) {
										if (IsPlayerAlive(idx) && GetClientTeam(idx) != GetClientTeam(iClient) && !TF2_IsPlayerInCondition(idx,TFCond_Cloaked) && !TF2_IsPlayerInCondition(idx,TFCond_CloakFlicker)) {
											float distance = getPlayerDistance(iClient,idx);
											if (distance < 768) {
												SetEntProp(idx, Prop_Send, "m_bGlowEnabled", 1);
												EmitSoundToClient(idx, "misc/rd_finale_beep01.wav", idx, _, SNDLEVEL_GUNFIRE, _, SNDVOL_NORMAL, _, _);
												SetHudTextParams(0.1, -0.16, 3.0, 255, 255, 255, 255);
												ShowHudText(idx,1,"⊙ REVEALED!");
												CreateTimer(5.0,updateGlow,idx);
											}
										}
									}
								}
								else //find enemy buildings
								{
									if(IsValidEdict(idx))
									{
										char class[64];
										GetEntityClassname(idx,class,64);
										if(StrEqual(class,"obj_sentrygun") || StrEqual(class,"obj_teleporter") || StrEqual(class,"obj_dispenser"))
										{
											float distance = getPlayerDistance(iClient,idx);
											if(GetEntProp(iClient, Prop_Send,"m_iTeamNum") != GetEntProp(idx, Prop_Send,"m_iTeamNum") && distance < 768)
											{
												SetEntProp(idx, Prop_Send, "m_bGlowEnabled", 1);
												CreateTimer(5.0,updateGlow,idx);
											}
										}
									}
								}
							}
						}
					}
				}
				//Spy-cicle mechanics
				if(meleeIndex == 649)
				{
					if(curr == melee)
					{
						if(GetEntProp(melee, Prop_Send,"m_bKnifeExists") == 0) //switch off melted knife
						{
							weapon = secondary;
						}
						else
						{
							//melt to remove debuffs and gain resistance
							if(buttons & IN_RELOAD)
								MeltKnife(iClient,melee,15.0);
						}
					}
				}

				if(TF2_IsPlayerInCondition(iClient,TFCond_Disguised) && !TF2_IsPlayerInCondition(iClient,TFCond_Cloaked))
				{
					//spy sprint
					if(buttons & IN_ATTACK3 || g_bIsMVM)
					{
						float speed = 320.0;
						if(TF2_IsPlayerInCondition(iClient,TFCond_SpeedBuffAlly))
							speed += 112;
						SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",speed);
					}
					else if(g_LastButtons[iClient] & IN_ATTACK3)
					{
						int class = GetEntProp(iClient, Prop_Send, "m_nDisguiseClass");
						TFClassType disguiseClass = view_as<TFClassType>(class);
						float speed = 320.0;
						switch(disguiseClass)
						{
							case TFClass_Pyro,TFClass_Engineer,TFClass_Sniper:
								speed = 300.0;
							case TFClass_DemoMan:
								speed = 280.0;
							case TFClass_Soldier:
								speed = 240.0;
							case TFClass_Heavy:
								speed = 230.0;
						}
						if(TF2_IsPlayerInCondition(iClient,TFCond_SpeedBuffAlly))
							speed += 105;
						SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",speed);
					}
					//fake spy reload
					if((buttons & IN_RELOAD) && curr == secondary)
					{
						int view = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
						int sequence = GetEntProp(view, Prop_Send, "m_nSequence");
						int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
						int clip = GetEntData(secondary, iAmmoTable, 4);
						int maxClip = secondaryIndex==525 ? 4 : 6;
						int secondaryAmmo = GetEntProp(secondary, Prop_Send, "m_iPrimaryAmmoType");
						int ammoCount = GetEntProp(iClient, Prop_Data, "m_iAmmo", _, secondaryAmmo);
						if(sequence==3 && (clip == maxClip || ammoCount == 0))
						{
							SetEntData(secondary, iAmmoTable, clip-1, 4);
							SetEntProp(iClient, Prop_Data, "m_iAmmo", ammoCount+1, _, secondaryAmmo);
							SetEntProp(view, Prop_Send, "m_nSequence",5);
							SetEntPropFloat(view, Prop_Send, "m_flPlaybackRate",1.25);
							g_condFlags[iClient] |= TF_CONDFLAG_FAKE;
						}
					}
				}
			}
			case TFClass_Scout:
			{
				if(primaryIndex==220 && curr==primary) //shortstop
				{
					if(buttons & IN_ATTACK2)
					{
						float shove = GetEntPropFloat(primary, Prop_Send, "m_flNextSecondaryAttack");
						int reload = GetEntProp(primary, Prop_Data, "m_bInReload");
						//speed up shortstop shove
						if(shove > GetGameTime()+1.4)
							SetEntPropFloat(primary, Prop_Send, "m_flNextSecondaryAttack",shove-0.7);
						if(reload == 1)
						{
							float time = GetGameTime()+0.03;
							SetEntProp(primary, Prop_Data, "m_bInReload",0);
							SetEntPropFloat(primary, Prop_Send, "m_flTimeWeaponIdle",time);
							SetEntPropFloat(primary, Prop_Send, "m_flNextPrimaryAttack",time);
							SetEntPropFloat(primary, Prop_Send, "m_flNextSecondaryAttack",time);
							SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack",time);
						}
					}
				}
				if(primaryIndex==448 && curr==primary) //soda popper block hype
				{
					if(buttons & IN_ATTACK2)
					{
						buttons &= ~IN_ATTACK2;
					}
				}
				if(meleeIndex==349)
				{
					float meter = GetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",2);
					if (meter>=100.0 && (buttons & IN_ATTACK3) && !(g_LastButtons[iClient] & IN_ATTACK3 == IN_ATTACK3) && !(g_condFlags[iClient] & TF_CONDFLAG_HEAT == TF_CONDFLAG_HEAT))
					{
						//activate Sun-On-A-Stick HEAT effect
						g_condFlags[iClient] |= TF_CONDFLAG_HEAT;
						EmitAmbientSound("misc/flame_engulf.wav",position,iClient);
						CreateParticle(iClient,"heavy_ring_of_fire",2.0,_,_,_,_,5.0,_,false,false);
					}
				}
			}
			case TFClass_Soldier:
			{
				switch(meleeIndex)
				{
					//The Equalizer
					case 128:
					{
						int MaxHP = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, iClient);
						int Health = GetClientHealth(iClient);
						if(Health<MaxHP/2)
						{
							if((weapon == melee || curr == melee) && !(g_condFlags[iClient] & TF_CONDFLAG_QUICK == TF_CONDFLAG_QUICK))
							{
								TF2_AddCondition(iClient,TFCond_SpeedBuffAlly,2.0,iClient);
								g_condFlags[iClient] |= TF_CONDFLAG_QUICK;
							}
						}
						else if(Health>=MaxHP/2)
						{
							if((g_condFlags[iClient] & TF_CONDFLAG_QUICK == TF_CONDFLAG_QUICK))
							{
								g_condFlags[iClient] &= ~TF_CONDFLAG_QUICK;
							}
						}
					}
				}
			}
		}
		//funny panic attack
		if(secondaryIndex == 1153 || primaryIndex == 1153)
		{
			int wep = secondaryIndex == 1153 ? secondary : primary;
			if(curr==wep)
			{
				if(g_condFlags[iClient] & TF_CONDFLAG_INFIRE)
				{
					int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
					int clip = GetEntData(wep, iAmmoTable, 4);
					if (secondaryIndex == 1153 && g_meterSec[iClient]>clip)
					{
						g_meterSec[iClient] = clip+0.0;
						if(buttons & IN_ATTACK != IN_ATTACK) EmitSoundToClient(iClient,"weapons/tf2_backshot_shotty.wav");
					}
					else if (primaryIndex == 1153 && g_meterPri[iClient]>clip)
					{
						g_meterPri[iClient] = clip+0.0;
						if(buttons & IN_ATTACK != IN_ATTACK) EmitSoundToClient(iClient,"weapons/tf2_backshot_shotty.wav");
					}
					weapon = 0;
					buttons |= IN_ATTACK;
					if(clip==0 || !IsPlayerAlive(iClient))
					{
						TF2Attrib_SetByDefIndex(wep,348,1.0);
						TF2Attrib_SetByDefIndex(wep,808,0.0);
						TF2Attrib_SetByDefIndex(wep,36,1.0);
						g_condFlags[iClient] &= ~TF_CONDFLAG_INFIRE;
					}
				}
				else
				{
					if(buttons & IN_ATTACK2 && !(g_TrueLastButtons[iClient] & IN_ATTACK2))
					{
						g_condFlags[iClient] |= TF_CONDFLAG_INFIRE;
						EmitSoundToClient(iClient,"weapons/tf2_backshot_shotty.wav");
						int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
						int clip = GetEntData(wep, iAmmoTable, 4);
						if (secondaryIndex == 1153)
							g_meterSec[iClient] = clip+0.0;
						else if(primaryIndex == 1153)
							g_meterPri[iClient] = clip+0.0;
						TF2Attrib_SetByDefIndex(wep,348,0.67);
						TF2Attrib_SetByDefIndex(wep,808,1.0);
						TF2Attrib_SetByDefIndex(wep,36,1.15);
					}
				}
			}
			else
			{
				TF2Attrib_SetByDefIndex(wep,348,1.0);
				g_condFlags[iClient] &= ~TF_CONDFLAG_INFIRE;
			}
		}
		//nullify crit melee boost on other weapons
		if(TF2_IsPlayerInCondition(iClient,TFCond_CritDemoCharge) && !TF2_IsPlayerInCondition(iClient,TFCond_Charging) && curr != melee)
		{
			TF2_RemoveCondition(iClient,TFCond_CritDemoCharge);
		}

		//weapon holstering speeds
		if(weapon!=0 && g_holstering[iClient]<=0.0)
		{
			float speed = 1.0;
			if(primary==curr) speed = g_holsterPri[iClient];
			else if(secondary==curr) speed = g_holsterSec[iClient];
			else if(melee==curr) speed = g_holsterMel[iClient];
			g_holstering[iClient] = 1.0;
			TF2Attrib_SetByDefIndex(iClient,177,speed);
		}
		else if(g_holstering[iClient]>0.0)
		{
			if(weapon!=0)
				g_holstering[iClient] = 1.0;
			if(g_holstering[iClient]==1.0)
				g_holstering[iClient] = GetEntPropFloat(curr, Prop_Send, "m_flNextPrimaryAttack");
			if(GetGameTime() >= g_holstering[iClient])
			{
				TF2Attrib_SetByDefIndex(iClient,177,1.0);
				g_holstering[iClient] = 0.0;
			}
		}
		if(weapon==melee && g_consecHits[iClient]!=-1) //reset melee combo when pulled out
			g_consecHits[iClient]=0;

		//bots spot snipers
		if(IsFakeClient(iClient))
		{
			int enemy = GetClientAimTarget(iClient,true);
			if(IsValidClient(enemy))
			{
				TFClassType enemyClass = TF2_GetPlayerClass(enemy);
				switch(enemyClass)
				{
					case TFClass_Sniper:
					{
						if(GetClientTeam(iClient) != GetClientTeam(enemy) && GetGameTime() - g_lastVoice[iClient] > 2.5)
						{
							int rndact = GetRandomUInt(0,2); //33% change to call sniper
							if(rndact==1)
								FakeClientCommand(iClient,"voicemenu 1 8");
							else
								g_lastVoice[iClient] = GetGameTime();
						}
					}
				}
			}
		}
		g_LastButtons[iClient] = buttons;
		if(!buttonsModified) g_TrueLastButtons[iClient] = buttons;
	}
	return Plugin_Continue;
}

public Action PlayerListener(int iClient, const char[] command, int argc)
{
	char[] args = new char[64];
	GetCmdArg(1,args,64);
	TFClassType tfClientClass = TF2_GetPlayerClass(iClient);
	char[] current = new char[64];
	GetClientWeapon(iClient,current,64);

	switch(tfClientClass)
	{
		case TFClass_Heavy:
		{
			if(StrEqual(command,"taunt") && (StrEqual(args,"0") || StrEqual(args,"")) &&
			(StrEqual(current,"tf_weapon_lunchbox") || StrEqual(current,"Lunch Box")))
			{
				g_condFlags[iClient] |= TF_CONDFLAG_EATING;
				TF2Attrib_AddCustomPlayerAttribute(iClient, "gesture speed increase", 1.7, 2.0);
				// TF2Attrib_SetByDefIndex(iClient,201,1.7); //revert eating speed
			}
		}
		case TFClass_DemoMan:
		{
			if(StrEqual(command,"taunt") && (StrEqual(args,"0") || StrEqual(args,"")) &&
			(StrEqual(current,"tf_weapon_stickbomb") || StrEqual(current,"Stick Bomb")))
				CreateTimer(3.75,CaberTauntkill,iClient); //start timer for caber taunt kill
		}
		case TFClass_Sniper:
		{
			if(StrEqual(command,"taunt") && (StrEqual(args,"0") || StrEqual(args,"")) &&
			(StrEqual(current,"tf_weapon_charged_smg") || StrEqual(current,"tf_weapon_smg") || StrEqual(current,"SMG") || StrEqual(current,"Charged SMG")))
				CreateTimer(1.875,SMGTauntkill,iClient); //start timer for smg taunt kill
		}
		case TFClass_Engineer:
		{
			if(StrEqual(command,"eureka_teleport") && StrEqual(args,"0"))
			{
				CreateTimer(2.25,TeleportResup,iClient); //triggered on Eureka Effect teleport
			}
		}
		case TFClass_Spy:
		{
			if(!TF2_IsPlayerInCondition(iClient,TFCond_Disguised)&&!(g_condFlags[iClient]&TF_CONDFLAG_SPYTAUNT))
			{
				//taunt effects for saharan spy
				if(StrEqual(command,"taunt") && (StrEqual(args,"0") || StrEqual(args,"")))
				{
					int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
					int secondaryIndex = -1;
					if(secondary != -1) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
					int melee = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Melee, true);
					int meleeIndex = -1;
					if(melee != -1) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
					int cos = TF2Util_GetPlayerWearableCount(iClient);
					for(int i; i < cos; i++)
					{
						int item = TF2Util_GetPlayerWearable(iClient,i);
						int index = -1;
						if(item != -1) index = GetEntProp(item, Prop_Send, "m_iItemDefinitionIndex");
						if(index==223 && secondaryIndex==224 && meleeIndex==225 && !StrEqual(current,"tf_weapon_builder") && !StrEqual(current,"tf_weapon_sapper"))
						{
							CreateParticle(iClient,"set_taunt_saharan_spy",5.0,_,_,_,_,_,_,false);
							break;
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action VoiceListener(int iClient, const char[] command, int argc)
{
	char[] args = new char[64];
	GetCmdArgString(args,64);
	
	if(GetGameTime() - g_lastVoice[iClient] > 3.0 && IsPlayerAlive(iClient))
	{
		if(StrEqual(args, "1 8") || StrEqual(args, "0 8") || StrEqual(command,"sm_sniper")) //replaces "Pass To Me!" with "Sniper Ahead!"
		{
			g_lastVoice[iClient] = GetGameTime();
			char classSound[64];
			
			TFClassType tfClientClass = TF2_GetPlayerClass(iClient);
			if(TF2_IsPlayerInCondition(iClient,TFCond_Disguised))
				tfClientClass = view_as<TFClassType>(GetEntProp(iClient, Prop_Send, "m_nDisguiseClass"));

			switch(tfClientClass)
			{
				case TFClass_Scout:
					strcopy(classSound, 64, "vo/scout_mvm_sniper01.wav");
				case TFClass_Soldier:
					strcopy(classSound, 64, "vo/soldier_mvm_sniper01.mp3");
				case TFClass_Pyro:
					strcopy(classSound, 64, "vo/pyro_mvm_sniper01.wav");
				case TFClass_DemoMan:
					strcopy(classSound, 64, "vo/demoman_mvm_sniper01.wav");
				case TFClass_Heavy:
					strcopy(classSound, 64, "vo/heavy_mvm_sniper01.mp3");
				case TFClass_Engineer:
					strcopy(classSound, 64, "vo/engineer_mvm_sniper01.mp3");
				case TFClass_Medic:
					strcopy(classSound, 64, "vo/medic_mvm_sniper01.mp3");
				case TFClass_Sniper:
					strcopy(classSound, 64, "vo/sniper_mvm_sniper01.wav");
				case TFClass_Spy:
					strcopy(classSound, 64, "vo/spy_mvm_sniper01.wav");
				default:
					strcopy(classSound, 64, "");
			}
			if(StrEqual(classSound,""))
				return Plugin_Continue;

			EmitSoundToClient(iClient,classSound,iClient, _, SNDLEVEL_GUNFIRE, _, SNDVOL_NORMAL, _, _);
			SetAnimation(iClient,"gesture_melee_help",2,1);

			char clientName[64],message[256];
			GetClientName(iClient, clientName, sizeof(clientName));
			TFTeam team = TF2_GetClientTeam(iClient);
			switch(team)
			{
				case TFTeam_Red:
					Format(message, sizeof(message), "\x07FF3D3D(Voice) %s\x01: Sniper Ahead!", clientName);
				case TFTeam_Blue:
					Format(message, sizeof(message), "\x079ACDFF(Voice) %s\x01: Sniper Ahead!", clientName);
				default:
					Format(message, sizeof(message), "\x03(Voice) %s\x01: Sniper Ahead!", clientName);
			}
			PrintToChat(iClient,message);
			int visibilityBitField = (1 << iClient);

			for(int idx = 1; idx < MaxClients; idx++)
			{
				if(IsValidClient(idx) && idx!=iClient)
				{
					//play sound
					float dist = getPlayerDistance(idx,iClient);
					dist = dist > 2500 ? 3000.0 : (dist < 512 ? 512.0 : dist);
					EmitSoundToClient(idx, classSound, iClient, _, SNDLEVEL_GUNFIRE, _, 1.2-(dist/2500), _, _);
					if(dist<=1900 && GetClientTeam(idx) == GetClientTeam(iClient))
					{
						PrintToChat(idx,message);
						visibilityBitField = visibilityBitField & idx;
					}
					//mark if sniper
					if(GetClientTeam(iClient)!=GetClientTeam(idx) && TF2_GetPlayerClass(idx) == TFClass_Sniper)
					{
						float clientpos[3],targetpos[3],anglevector[3];
						float targetvector[3];
						float angle = 10.0, distance = 2048.0, resultdistance = 0.0;
						bool result = false;

						GetClientEyePosition(iClient, clientpos);
						GetClientEyePosition(idx, targetpos);
						targetpos[2]-=40;
						GetClientEyeAngles(iClient, anglevector);
						GetAngleVectors(anglevector, anglevector, NULL_VECTOR, NULL_VECTOR);
						NormalizeVector(anglevector, anglevector);

						if(distance > 0)
							resultdistance = GetVectorDistance(clientpos, targetpos);
						MakeVectorFromPoints(clientpos, targetpos, targetvector);
						NormalizeVector(targetvector, targetvector);
						
						float resultangle = RadToDeg(ArcCosine(GetVectorDotProduct(targetvector, anglevector)));

						if(resultangle <= angle/2)	
						{
							if(distance > 0)
							{
								if(distance >= resultdistance)
									result = true;
							}
							else
								result = true;
						}

						if(result)
						{
							// TR_TraceRayFilter(player_pos, target_pos, MASK_SOLID, RayType_Infinite, TraceFilter, idx);
							Handle hndl = TR_TraceRayFilterEx(clientpos, targetpos, MASK_OPAQUE, RayType_EndPoint, PlayerTraceFilter, idx);
							if (TR_GetFraction(hndl) == 1.0)
							{
								EmitSoundToClient(idx, "misc/rd_finale_beep01.wav", idx, _, SNDLEVEL_GUNFIRE, _, SNDVOL_NORMAL, _, _);
								SetHudTextParams(0.1, -0.16, 2.0, 255, 255, 255, 255);
								ShowHudText(idx,1,"⊙ SPOTTED!");
								//show annotation to teammates
								for(int i = 1; i < MaxClients; i++)
								{
									if(IsValidClient(i))
									{
										if(getPlayerDistance(i,iClient)<640 && GetClientTeam(i) == GetClientTeam(iClient))
										{
											Handle event = CreateEvent("show_annotation");
											if (event == INVALID_HANDLE) return Plugin_Handled;
											SetEventFloat(event, "worldPosX", targetpos[0]);
											SetEventFloat(event, "worldPosY", targetpos[1]);
											SetEventFloat(event, "worldPosZ", targetpos[2]+40);
											SetEventFloat(event, "lifetime", 3.0);
											SetEventInt(event, "id", i*MAXPLAYERS + idx + ANNOTATION_OFFSET);
											SetEventString(event, "text", "Sniper!");
											SetEventString(event, "play_sound", "vo/null.wav");
											SetEventInt(event, "visibilityBitfield", (1 << i));
											FireEvent(event);
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action StartUpgrade(int iClient, const char[] command, int argc)
{
	if(IsValidClient(iClient) && g_bIsMVM)
	{
		if(IsPlayerAlive(iClient))
		{
			g_condFlags[iClient] |= TF_CONDFLAG_UPGRADE;
		}
	}
	return Plugin_Continue;
}
public Action ExitUpgrade(int iClient, const char[] command, int argc)
{
	if(IsValidClient(iClient))
	{
		if(IsPlayerAlive(iClient))
		{
			g_condFlags[iClient] &= ~TF_CONDFLAG_UPGRADE;
			if(g_condFlags[iClient] & TF_CONDFLAG_INSPAWN)
			{
				g_condFlags[iClient] |= TF_CONDFLAG_NOGRADE;
				TF2_RespawnPlayer(iClient);
			}
			// g_condFlags[iClient] |= TF_CONDFLAG_INSPAWN;
		}
	}
	return Plugin_Continue;
}
public Action PlayerUpgrade(int iClient, const char[] command, int argc)
{
	if(g_bIsMVM) //mvm stats
	{
		float reg,spe,jum,bul,bla,fir,cri,met;
		Address addr = Address_Null;
		addr = TF2Attrib_GetByName(iClient, "health regen");
		if(addr != Address_Null) reg = TF2Attrib_GetValue(addr);
		addr = TF2Attrib_GetByName(iClient, "major move speed bonus");
		if(addr != Address_Null) spe = TF2Attrib_GetValue(addr);
		addr = TF2Attrib_GetByName(iClient, "major increased jump height");
		if(addr != Address_Null) jum = TF2Attrib_GetValue(addr);
		addr = TF2Attrib_GetByName(iClient, "dmg taken from bullets reduced");
		if(addr != Address_Null) bul = TF2Attrib_GetValue(addr);
		addr = TF2Attrib_GetByName(iClient, "dmg taken from blast reduced");
		if(addr != Address_Null) bla = TF2Attrib_GetValue(addr);
		addr = TF2Attrib_GetByName(iClient, "dmg taken from fire reduced");
		if(addr != Address_Null) fir = TF2Attrib_GetValue(addr);
		addr = TF2Attrib_GetByName(iClient, "dmg taken from crit reduced");
		if(addr != Address_Null) cri = TF2Attrib_GetValue(addr);
		addr = TF2Attrib_GetByName(iClient, "metal regen");
		if(addr != Address_Null) met = TF2Attrib_GetValue(addr);
		g_playerUpgrades[iClient][0] = reg;
		g_playerUpgrades[iClient][1] = spe;
		g_playerUpgrades[iClient][2] = jum;
		g_playerUpgrades[iClient][3] = bul;
		g_playerUpgrades[iClient][4] = bla;
		g_playerUpgrades[iClient][5] = fir;
		g_playerUpgrades[iClient][6] = cri;
		g_playerUpgrades[iClient][7] = met;
	}
	return Plugin_Continue;
}
public Action PlayerReset(int iClient, const char[] command, int argc)
{
	if(g_bIsMVM && !IsFakeClient(iClient)) //mvm stats
	{
		float reg,spe,jum,bul,bla,fir,cri,met;
		reg = 0.0;
		spe = 1.0;
		jum = 1.0;
		bul = 1.0;
		bla = 1.0;
		fir = 1.0;
		cri = 1.0;
		met = 0.0;
		TF2Attrib_SetByName(iClient, "health regen", reg);
		TF2Attrib_SetByName(iClient, "major move speed bonus", spe);
		TF2Attrib_SetByName(iClient, "major increased jump height", jum);
		TF2Attrib_SetByName(iClient, "dmg taken from bullets reduced", bul);
		TF2Attrib_SetByName(iClient, "dmg taken from blast reduced", bla);
		TF2Attrib_SetByName(iClient, "dmg taken from fire reduced", fir);
		TF2Attrib_SetByName(iClient, "dmg taken from crit reduced", cri);
		TF2Attrib_SetByName(iClient, "metal regen", met);
		g_playerUpgrades[iClient][0] = reg;
		g_playerUpgrades[iClient][1] = spe;
		g_playerUpgrades[iClient][2] = jum;
		g_playerUpgrades[iClient][3] = bul;
		g_playerUpgrades[iClient][4] = bla;
		g_playerUpgrades[iClient][5] = fir;
		g_playerUpgrades[iClient][6] = cri;
		g_playerUpgrades[iClient][7] = met;
	}
	return Plugin_Continue;
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	bool tank = false;
	if(!IsValidClient(victim,false))
	{
		char class[64];
		GetEntityClassname(victim,class,64);
		if(StrEqual(class, "tank_boss"))
			tank = true;
	}
	if(IsValidClient(attacker) && !tank)
	{
		int primary = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Primary, true);
		int primaryIndex = -1;
		if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
		int secondary = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Secondary, true);
		int secondaryIndex = -1;
		if(secondary != -1) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
		TFClassType tfAttackerClass = TF2_GetPlayerClass(attacker);

		switch(tfAttackerClass)
		{
			case TFClass_Spy:
			{
				if(damagetype & DMG_BULLET)
				{
					if(secondary != -1) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
					if(secondaryIndex==61 || secondaryIndex==1006) //extend ambassador range
					{
						float time = GetEntPropFloat(secondary, Prop_Send, "m_flLastFireTime");
						float dist = getPlayerDistance(attacker,victim);
						if(hitgroup == 1 && GetGameTime() - time >= 1.0 && dist > 1200 && dist < 1536)
						{
							damage = 12 + 24*((1536-dist)/336);
							damagetype |= DMG_CRIT;
							damagetype |= DMG_SHOCK;
							damagetype |= DMG_USE_HITLOCATIONS;
						}
					}
				}
			}
			case TFClass_Sniper:
			{
				if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
				if(TF2_IsPlayerInCondition(attacker,TFCond_Slowed))
				{
					switch(primaryIndex)
					{
						case 230:  //increase jarate duration on headshot
						{
							if(hitgroup == 1)
								TF2_AddCondition(victim,TFCond_Jarated,5.1,attacker);
						}
						case 1098: //the classic headshot check
						{
							if(hitgroup == 1)
							{
								float charge = GetEntPropFloat(primary, Prop_Send, "m_flChargedDamage");
								if(charge<135 && !isKritzed(attacker))
								{
									TF2_AddCondition(victim,TFCond_MarkedForDeathSilent,0.015,attacker);
								}
							}
						}
					}
				}
			}
			case TFClass_Heavy:
			{
				int melee = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Melee, true);
				int meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
				//holiday punch
				if(GetClientTeam(victim) != GetClientTeam(attacker))
				{
					if(damage==0.0 && damagetype&DMG_CRIT==DMG_CRIT && damagetype&DMG_CLUB==DMG_CLUB && meleeIndex==656)
					{
						//check if target is airborne, if so then stun
						int clientFlags = GetEntityFlags(victim);
						float vel[3];
						GetEntPropVector(victim, Prop_Data, "m_vecVelocity",vel);
						if(!((clientFlags & FL_ONGROUND) && vel[2]==0.0))
						{
							TF2_StunPlayer(victim,3.0,0.0,TF_STUNFLAG_BONKSTUCK,attacker);
						}
					}
				}
			}
		}

		//check for blast jump counters
		if((g_condFlags[victim] & TF_CONDFLAG_BLJUMP || TF2_IsPlayerInCondition(victim,TFCond_BlastJumping)) && (victim != attacker) && (victim != inflictor))
		{
			if((damagetype & DMG_BLAST && (primaryIndex == 127)) || (damagetype & DMG_BUCKSHOT && (secondaryIndex == 415)))
			{
				if(!(damagetype & DMG_CRIT))
				{
					TF2_AddCondition(victim,TFCond_MarkedForDeathSilent,0.015);
				}
			}
		}

		//sandman check for minicrits
		if(g_condFlags[victim] & TF_CONDFLAG_BONK)
		{
			if(RoundFloat(g_bonkedDebuff[victim][0]) == attacker)
			{
				TF2_AddCondition(victim,TFCond_MarkedForDeathSilent,0.015);
			}
		}

		if(damagetype & DMG_CLUB && GetClientTeam(victim) == GetClientTeam(attacker) && victim != attacker)
		{
			int melee = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Melee, true);
			int meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
			if(meleeIndex == 173)
			{
				int organs = GetEntProp(attacker, Prop_Send, "m_iDecapitations");
				if(organs>0)
				{
					//vita-saw heal-on-hit
					int vicPri = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Primary, true);
					int vicPriIndex = -1;
					if(vicPri != -1) vicPriIndex = GetEntProp(vicPri, Prop_Send, "m_iItemDefinitionIndex");
					int vicSec = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Secondary, true);
					int vicSecIndex = -1;
					if(vicSec != -1) vicSecIndex = GetEntProp(vicSec, Prop_Send, "m_iItemDefinitionIndex");
					int vicMel = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Melee, true);
					int vicMelIndex = -1;
					if(vicMel != -1) vicMelIndex = GetEntProp(vicMel, Prop_Send, "m_iItemDefinitionIndex");

					float health = 0.0;
					float overheal = 1.5;

					health += GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, victim);
					//get health mods
					switch(vicPriIndex)
					{
						// case 405,608: health+=25;
					}
					switch(vicSecIndex)
					{
						case 57: overheal = 1.0;
					}
					switch(vicMelIndex)
					{
						case 331: overheal = 1.3;
						case 317: overheal = 1.25;
					}
					if(g_bIsMVM) //apply overheal expert
					{
						Address addr = TF2Attrib_GetByName(secondary, "overheal expert");
						if(addr != Address_Null)
						{
							float value = TF2Attrib_GetValue(addr);
							overheal *= 1 + value/4.0;
						}
					}
					
					float maxHP = health * overheal;
					float amountToHeal = maxHP - GetClientHealth(victim);
					float amount = 0.0;
					float perOrgan = 100.0; //flat HP amount
					if(vicPriIndex==41) perOrgan*=0.33;
					organs = GetEntProp(attacker, Prop_Send, "m_iDecapitations");
					while(organs>0 && amount<amountToHeal)
					{
						organs -= 1;
						float amountPrior = amount;
						amount = amount+perOrgan > amountToHeal ? amountToHeal : amount+perOrgan;
						if(amountToHeal==amount)
						{
							//refund some healing for next organ progress
							float remainder = (amountPrior+perOrgan)-amountToHeal;
							g_meterMel[attacker] -= 300*((remainder)/(perOrgan));
						}
					}

					TF2Util_TakeHealth(victim,amount,TAKEHEALTH_IGNORE_MAXHEALTH);
					SetEntProp(attacker, Prop_Send, "m_iDecapitations", organs);

					float victimPos[3];
					GetClientEyePosition(victim,victimPos);
					if(TF2_GetClientTeam(victim) == TFTeam_Red) CreateParticle(victim,"medic_megaheal_red",1.0,_,_,_,_,_,_,false,false);
					else CreateParticle(victim,"medic_megaheal_blue",1.0,_,_,_,_,_,_,false,false);
					EmitAmbientSound("weapons/fx/rics/arrow_impact_crossbow_heal.wav",victimPos,victim);
				}
			}
			else if(meleeIndex != 447)
			{
				//hit melee through teammates
				int idx, closest = -1;
				float player_pos[3], target_pos[3], angles1[3], angles2[3], vector[3];
				float rangeMult=1.0,distance,closestDistance = 0.0;

				GetClientEyePosition(attacker, player_pos);
				GetClientEyeAngles(attacker, angles1);

				for(idx = 1; idx < MaxClients; idx++)
				{
					if(IsValidClient(idx,false))
					{
						if(IsPlayerAlive(idx) && GetClientTeam(idx) != GetClientTeam(attacker))
						{
							GetEntPropVector(idx, Prop_Send, "m_vecOrigin", target_pos);
							distance = GetVectorDistance(player_pos, target_pos);
							if(distance < 102*rangeMult)
							{
								MakeVectorFromPoints(player_pos, target_pos, vector);
								GetVectorAngles(vector, angles2);
								angles2[1] = angles2[1] > 180.0 ? (angles2[1] - 360.0) : angles2[1];
								angles1[0] = 0.0;
								angles2[0] = 0.0;
								
								float limit = ValveRemapVal(distance, 0.0, 200.0, 80.0, 40.0);
								
								if(CalcViewsOffset(angles1, angles2) < limit)
								{
									TR_TraceRayFilter(player_pos, target_pos, MASK_SOLID, RayType_EndPoint, TraceFilter, idx);
									
									if(TR_DidHit() == false)
									{
										if(closestDistance > distance || closestDistance == 0.0)
										{
											closest = idx; closestDistance = distance;
										}
									}
								}
							}
						}
					}
				}
				if(closest != -1)
				{
					if(attacker != inflictor) SDKHooks_TakeDamage(closest, attacker, attacker, damage, damagetype, inflictor, NULL_VECTOR, target_pos, false); //shield bash
					else SDKHooks_TakeDamage(closest, attacker, inflictor, damage, damagetype, melee, NULL_VECTOR, target_pos, false); //otherwise
				}
			}
			return Plugin_Stop;
		}
	}
	// PrintToChatAll("trace %d %d %d | %.2f %d | %d %d",attacker,victim,inflictor,damage,damagetype,hitbox,hitgroup);
	return Plugin_Continue;
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	TFClassType tfVictimClass;
	if(IsValidClient(victim,false)) tfVictimClass = TF2_GetPlayerClass(victim);
	int weaponIndex = -1;
	if(weapon > 0) weaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

	//explode on ignite for single target
	if(IsValidClient(victim,false))
	{
		if(TF2_IsPlayerInCondition(victim,TFCond_Gas) && (damagetype & DMG_BURN || damagetype & DMG_CLUB || damagetype & DMG_IGNITE || damagetype & DMG_BLAST || damagetype & DMG_BUCKSHOT || damagetype & DMG_BULLET))
		{
			int gasser = TF2Util_GetPlayerConditionProvider(victim,TFCond_Gas);
			float meter = GetEntPropFloat(gasser, Prop_Send, "m_flItemChargeMeter", 1);
			DataPack pack = new DataPack();
			pack.Reset();
			pack.WriteCell(victim);
			pack.WriteCell(gasser);
			pack.WriteFloat(meter);
			CreateTimer(0.02,gasExplode,pack);
		}
	}

	switch(tfVictimClass)
	{
		case TFClass_Sniper,TFClass_Spy:
		{
			int secondary = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Secondary, true);
			int secondaryIndex = -1;
			if(secondary >= 0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
			int melee = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Melee, true);
			int meleeIndex = -1;
			if(melee != -1) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
			
			if(IsValidClient(attacker))
			{
				if(secondaryIndex == 57 && TF2_GetPlayerClass(attacker)==TFClass_Spy)
				{
					int meleeAtk = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Melee, true);
					if(weapon==meleeAtk && GetEntProp(weapon, Prop_Send, "m_bReadyToBackstab"))
					{
						//unblock knife
					}
				}
			}
			if(secondaryIndex == 231 || (meleeIndex==649 && g_condFlags[victim] & TF_CONDFLAG_INFIRE))
			{
				bool isBleed=false;
				//does weapon bleed?
				switch(weaponIndex)
				{
					case 812,833,325,452,155,171:
						isBleed=true;
					case 648:
					{
						if(damagetype==128)
							isBleed=true;
					}
				}
				if(damagetype & DMG_CLUB != DMG_CLUB) isBleed=false;
				if(isBleed)
				{
					//get bleed duration
					float duration=0.0;
					switch(weaponIndex)
					{
						case 812,833,325,452,155,648:
							duration=5.0;
						case 171:
							duration=8.0;
					}
					//calculate bleed reduction
					if(secondaryIndex == 231) duration *= 0.66;
					if(meleeIndex==649) duration *= 0.25;
					//remove existing bleed
					int dmg = 4;
					TF2_RemoveCondition(victim,TFCond_Bleeding);
					//setup bleed to take next frame
					DataPack pack = new DataPack();
					pack.Reset();
					pack.WriteCell(victim);
					pack.WriteCell(attacker);
					pack.WriteCell(weapon);
					pack.WriteCell(dmg);
					pack.WriteFloat(duration);
					RequestFrame(BleedBuff,pack);
				}
			}
		}
	}

	if(IsValidClient(attacker))
	{
		int primary = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Primary, true);
		int primaryIndex = -1;
		if(primary != -1) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
		int melee = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Melee, true);
		int meleeIndex = -1;
		if(melee != -1) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");

		TFClassType tfAttackerClass = TF2_GetPlayerClass(attacker);
		bool valid = false, tank = false;
		if(IsValidClient(victim,false))
		{
			if(!TF2_IsPlayerInCondition(victim,TFCond_Ubercharged)&&!TF2_IsPlayerInCondition(victim,TFCond_UberchargeFading)&&!TF2_IsPlayerInCondition(victim,TFCond_UberchargedCanteen))
				valid = true;
		}
		else
		{
			char class[64];
			GetEntityClassname(victim,class,64);
			if(StrEqual(class, "tank_boss"))
				tank = true;
		}
		switch(tfAttackerClass)
		{
			case TFClass_Scout:
			{
				// if(weaponIndex==325 && damagetype&DMG_CLUB==DMG_CLUB)
				// {
				// 	int vicSec = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Secondary, true);
				// 	int vicSecIndex = -1;
				// 	if(vicSec >= 0) vicSecIndex = GetEntProp(vicSec, Prop_Send, "m_iItemDefinitionIndex");
				// 	// int vicMel = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Melee, true);
				// 	// int vicMelIndex = -1;
				// 	// if(vicMel != -1) vicMelIndex = GetEntProp(vicMel, Prop_Send, "m_iItemDefinitionIndex");

				// 	if((tfVictimClass != TFClass_Sniper || vicSecIndex != 231) && (tfVictimClass != TFClass_Spy || g_condFlags[victim] & TF_CONDFLAG_INFIRE != TF_CONDFLAG_INFIRE) )
				// 	{
				// 		int dmg = 4;
				// 		if(TF2_IsPlayerInCondition(victim,TFCond_Bleeding))
				// 		{
				// 			dmg = TF2Util_GetPlayerBleedDamage(victim,0) + 2;
				// 			dmg = dmg > 8 ? 8 : dmg;
				// 		}
				// 		TF2_RemoveCondition(victim,TFCond_Bleeding);
				// 		//stack basher bleed
				// 		DataPack pack = new DataPack();
				// 		pack.Reset();
				// 		pack.WriteCell(victim);
				// 		pack.WriteCell(attacker);
				// 		pack.WriteCell(weapon);
				// 		pack.WriteCell(dmg);
				// 		pack.WriteFloat(5.0);
				// 		RequestFrame(BleedBuff,pack);
				// 	}
				// }
				// else 
				if(meleeIndex==349)
				{
					if(g_condFlags[attacker] & TF_CONDFLAG_HEAT && (damagetype & DMG_IGNITE))
					{
						if(tfVictimClass!=TFClass_Pyro && !TF2_IsPlayerInCondition(victim,TFCond_DeadRingered))
						{
							float duration = TF2Util_GetPlayerBurnDuration(victim);
							float ignition = 4.0; //4 second afterburn
							if(duration < ignition && tfVictimClass != TFClass_Pyro)
							{
								TF2Util_SetPlayerBurnDuration(victim,ignition);
								g_condFlags[attacker] &= ~TF_CONDFLAG_HEAT;
								g_meterMel[attacker] = 0.0;
								SetEntPropFloat(attacker, Prop_Send,"m_flItemChargeMeter",0.0,2);
							}
						}
					}
				}
				if(valid | tank)
				{
					if(primaryIndex==772)
					{
						//baby face boost on hit
						float hype = GetEntPropFloat(attacker,Prop_Send,"m_flHypeMeter");
						if(RoundFloat(g_meterPri[attacker])<RoundFloat(hype))
						{
							g_meterPri[attacker]+=damage/1.5;
							if(g_meterPri[attacker]>100) g_meterPri[attacker]=99.9;
							SetEntPropFloat(attacker,Prop_Send,"m_flHypeMeter",g_meterPri[attacker]);
						}
					}
					if(primaryIndex==448)
					{
						if(victim != inflictor && attacker != victim)
						{
							//soda popper hype on hit
							float hype = GetEntPropFloat(attacker,Prop_Send,"m_flHypeMeter");
							if(hype>HYPE_COST&&TF2_IsPlayerInCondition(attacker,TFCond_CritHype))
							{
								hype+=damage/3.0;
								if(hype>100) hype=99.9;
								SetEntPropFloat(attacker,Prop_Send,"m_flHypeMeter",hype);
							}
							else
							{
								hype+=damage/25.0;
								if(hype>100) hype=99.9;
								SetEntPropFloat(attacker,Prop_Send,"m_flHypeMeter",hype);
							}
						}
					}

					if((weaponIndex == 812 || weaponIndex == 833) && damage > 10)
					{
						//make sure cleaver is 0 on long range hit
						RequestFrame(FlushCleaver,attacker);
					}
				}
			}
			case TFClass_Pyro:
			{
				if(valid | tank)
				{
					//Neon Annihilator damage charge
					if(melee != -1) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
					if((meleeIndex == 813 || meleeIndex == 834) && attacker != victim)
					{
						if(g_meterMel[attacker]<100)
						{
							int current = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
							if(current == melee && damagetype & DMG_CLUB)
								g_meterMel[attacker] += damage; //melee damage builds 4x faster
							else
								g_meterMel[attacker] += damage/4.0; //otherwise is slower
						}
					}
				}
			}
		}
		switch(weaponIndex)
		{
			case 41: //natascha heal on hit
			{
				float dist = getPlayerDistance(attacker,victim);
				if(dist < 1024 && damage > 0.0 && valid)
				{
					float healing = dist < 256.0 ? 10.0 : 9.0*((1024-dist)/768.0) + 1.0;
					TF2Util_TakeHealth(attacker,healing);
					SetHudTextParams(0.1, -0.16, 1.0, 255, 255, 255, 255);
					ShowHudText(attacker,2,"+%.0f HP",healing);
				}
			}
			case 996: //custom loose cannon knockback
			{
				if(!tank)
					valid = !TF2_IsPlayerInCondition(victim,TFCond_MegaHeal);
				if(victim != attacker && damageForce[0]==0.0 && damageForce[1]==0.0 && damageForce[2]==0 && valid && !tank)
				{
					RequestFrame(CannonKnockback,victim);
				}
			}
			case 526, 30665: //machina building penetration kill sound
			{
				if(GetClientHealth(victim)<=0 && damagetype & DMG_SHOCK)
				{
					EmitAmbientSound("misc/sniper_railgun_double_kill.wav",damagePosition,victim,SNDLEVEL_TRAIN);
				}
			}
			case 351,740:
			{
				if(!(damagetype & DMG_HALF_FALLOFF) && !(damagetype & DMG_BURN))
				{
					float duration = TF2Util_GetPlayerBurnDuration(victim);
					if(duration < 7.5 && tfVictimClass != TFClass_Pyro)
						TF2Util_SetPlayerBurnDuration(victim,7.5);
				}
			}
			case 1181: //hot hand stacking speed boost
			{
				if(TF2_IsPlayerInCondition(attacker,TFCond_SpeedBuffAlly))
				{
					if(TF2Util_GetPlayerConditionProvider(attacker,TFCond_SpeedBuffAlly)!=weapon)
					{
						TF2Util_SetPlayerConditionProvider(attacker,TFCond_SpeedBuffAlly,weapon);
					}
					float time = TF2Util_GetPlayerConditionDuration(attacker,TFCond_SpeedBuffAlly);
					time = time > 0 ? time : 0.0; //min 0
					time = time+2 > HAND_MAX ? HAND_MAX : time+2; //+2 up to max time
					TF2Util_SetPlayerConditionDuration(attacker,TFCond_SpeedBuffAlly,time);
				}
				else
				{
					TF2_AddCondition(attacker,TFCond_SpeedBuffAlly,2.0,weapon);
				}
			}
		}
		if(GetClientHealth(victim)<=0 && victim != attacker && !tank)
		{
			if(IS_HALLOWEEN)
			{
				int resource = GetPlayerResourceEntity();
				if (resource != -1)
				{
					int atkScore = GetEntProp(resource, Prop_Send, "m_iScore", _, attacker);
					int vicScore = GetEntProp(resource, Prop_Send, "m_iScore", _, victim);

					if(atkScore<vicScore)
					{
						g_spawnPumpkin[victim] = attacker;
					}
				}
			}
			if(meleeIndex==317) //candy cane, no ammo spawn
			{
				g_spawnHealth[victim] = attacker;
			}
		}
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	TFClassType victimClass;
	bool tank = false;
	if(IsValidClient(victim,false)) victimClass = TF2_GetPlayerClass(victim);
	else
	{
		char class[64];
		GetEntityClassname(victim,class,64);
		if(StrEqual(class, "tank_boss"))
			tank = true;
	}

	if(attacker == 0)
	{
		if(victimClass == TFClass_Scout)
		{
			int primary = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Primary, true);
			int primaryIndex = -1;
			if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
			if(primaryIndex == 772 && (damagetype & DMG_FALL == DMG_FALL))
			{
				//undo hype lost on fall damage
				float hype = GetEntPropFloat(victim, Prop_Send, "m_flHypeMeter");
				SetEntPropFloat(victim, Prop_Send, "m_flHypeMeter",hype+damage*2);
			}
		}
	}
	else if(attacker == victim)
	{
		if(TF2_IsPlayerInCondition(victim,TFCond_BlastJumping) && damagetype & DMG_BLAST)
		{
			TF2_RemoveCondition(victim,TFCond_BlastJumping);
			RequestFrame(BlastJump,victim);
		}
		if(victimClass == TFClass_Pyro && damagetype&DMG_BULLET==DMG_BULLET && damagetype&DMG_IGNITE==DMG_IGNITE)
		{
			TF2_AddCondition(victim,TFCond_BlastJumping,_,victim);
		}
		if (victimClass == TFClass_Soldier)
		{
			int secondary = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Secondary, true);
			int secondaryIndex = -1;
			if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
			if(secondaryIndex == 444)
			{
				if(g_condFlags[victim] & TF_CONDFLAG_DIVE == TF_CONDFLAG_DIVE)
				{
					damage *= 0.35; //reduce self-damage with mantreads
				}
				else
				{
					g_condFlags[victim] |= TF_CONDFLAG_DIVE;
				}
			}
		}
		if (victimClass == TFClass_Engineer)
		{
			int secondary = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Secondary, true);
			int secondaryIndex = -1;
			if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
			if(secondaryIndex == 140 || secondaryIndex == 1086 || secondaryIndex == 30668)
			{
				if(damagetype & DMG_BLAST) TF2_AddCondition(victim,TFCond_BlastJumping,_,victim); // blast jump
				damage *= 0.2; //reduce sentry self-damage with wrangler equipped
			}
		}
		if(IsValidEdict(weapon) && weapon)
		{
			int weaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			switch(weaponIndex)
			{
				case 528: //negate short circuit damage from hits against enemies (no double damage)
				{
					if(damagetype & DMG_BLAST)
					{
						damagetype = DMG_SHOCK;
						damage = 20.0;
					}
					else
						damage *= 0.0; 
				}
			}
		}
	}
	else if(inflictor == victim && !tank)
	{
		if(IsValidEdict(weapon) && weapon)
		{
			int weaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			switch(weaponIndex)
			{
				case 220: //shortstop shove
				{
					float scale = GetEntPropFloat(victim, Prop_Send, "m_flModelScale");
					if(!TF2_IsPlayerInCondition(victim,TFCond_MegaHeal) && scale <= 1.0)
					{
						damageForce[0]*=0.025; damageForce[1]*=0.025; damageForce[2]=damageForce[2]*0.00625+300.0;
						TeleportEntity(victim,NULL_VECTOR,NULL_VECTOR,damageForce);
						TF2_AddCondition(victim,TFCond_AirCurrent);
						g_condFlags[victim] |= TF_CONDFLAG_HOVER;
					}
				}
			}
		}
	}
	if(IsValidEdict(weapon) && IsValidClient(attacker))
	{
		TFClassType tfAttackerClass = TF2_GetPlayerClass(attacker);
		int weaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		char[] weaponName = new char[64];
		GetEntityClassname(weapon,weaponName,64);

		if(weapon == TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Melee, true) && (damagetype & DMG_CLUB)==DMG_CLUB)
		{
			if(g_consecHits[attacker]!=-1 && !(damagetype & DMG_SHOCK))
			{
				g_lastHit[attacker] = GetGameTime();
				g_nextHit[attacker] = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
				g_consecHits[attacker]++;
				if((tfAttackerClass == TFClass_Scout && g_consecHits[attacker]%4==3) || (tfAttackerClass != TFClass_Scout && g_consecHits[attacker]%3==2))
					CreateTimer((g_nextHit[attacker]-g_lastHit[attacker])*0.5,critGlow,attacker);
			}
		}

		if(StrEqual("tf_weapon_flamethrower",weaponName) && (damagetype & DMG_IGNITE) && !(damagetype & DMG_BLAST) && damagecustom != TF_CUSTOM_TAUNT_ARMAGEDDON && damagecustom != TF_CUSTOM_DRAGONS_FURY_BONUS_BURNING && damagecustom != TF_CUSTOM_DRAGONS_FURY_IGNITE && !tank)
		{
			//recreate flamethrower damage scaling, code inpsired by NotnHeavy
			//base damage plus any bonus/penalty
			Address penal = TF2Attrib_GetByName(weapon, "damage penalty"); //will get bonus for mvm
			float value = penal == Address_Null ? 1.0 : TF2Attrib_GetValue(penal);
			Address bonus = TF2Attrib_GetByName(weapon, "damage bonus");
			value *= bonus == Address_Null ? 1.0 : TF2Attrib_GetValue(bonus);
			float temperature = GetMin(GetMax(g_temperature[victim],0.125),0.625) + 0.375; //bind temperature to be 0.5 to 1.0 plus the base
			damage = 13.0 * temperature * value;

			//crit damage multipliers
			if(damagetype & DMG_CRIT)
			{
				if(isMiniKritzed(attacker,victim) && !isKritzed(attacker))
					damage *= 1.35;
				else
				{
					if(weaponIndex==594)  //scale Phlog
					{
						float temp = temperature - 0.5;
						damage *= 1.35 + 1.65*(temp/0.5);
					}
					else
						damage *= 3.0;
				}
			}
			//fall-off based on range replacing age multiplier
			float dist = getPlayerDistance(attacker,victim);
			damage *= 1.0 - 0.5*(dist < 170 ? 0.0 : (dist>340 ? 1.0 : ((dist-170)/170)));
			//increment temperature based on range
			g_lastFlamed[victim] = GetGameTime();
			if(g_temperature[victim] < 1.0)
			{
				float increment = temperature/25.0 + Pow(0.355*((dist>340 ? 0.0 : 340-dist)/340),2.0);
				g_temperature[victim] += increment;
			}
			if(g_temperature[victim] > 1.0) g_temperature[victim] = 1.0;
			damagetype &= ~DMG_USEDISTANCEMOD;

			//reset the flame damage interval
			if(g_flameDamage[victim]>0)
			{
				g_flameDamage[victim] = -0.09;
			}
			if(damagetype & DMG_SONIC)
			{
				damagetype &= ~DMG_SONIC;
				damage = 0.01;
			}
		}

		if(weaponIndex==1180)
		{
			//gas passer ignite damage
			if(!(damagetype & DMG_BURN == DMG_BURN))
			{
				damage = 15.0;
				float value = 0.0;
				if(g_bIsMVM)
				{
					Address addr = TF2Attrib_GetByName(weapon, "melee range multiplier");
					if(addr != Address_Null)
					{
						value = TF2Attrib_GetValue(addr);
						switch(value)
						{
							case 0.0: damage = 15.0;
							case 1.0: damage = 150.0; //mvm tick 1
							case 2.0: damage = 285.0; //mvm tick 2
						}
					}
				}
			}
		}
		
		switch(tfAttackerClass)
		{
			case TFClass_Heavy:
			{
				switch(weaponIndex)
				{
					case 811,832://huo-long heater ignition on death
					{
						if(damage>GetClientHealth(victim) && damagetype&DMG_BULLET==DMG_BULLET)
							damagetype |= DMG_IGNITE;// | DMG_BLAST;
					}
				}
			}
			case TFClass_Spy:
			{
				if(!tank)
				{
					if(weaponIndex==61 || weaponIndex==1006) //amby headshot
					{
						if(damagetype & DMG_SHOCK)
						{
							damagecustom = TF_CUSTOM_HEADSHOT;
							damagetype &= ~DMG_SHOCK;
						}
					}
				}
			}
			case TFClass_Soldier:
			{
				switch(weaponIndex)
				{
					case 444: //add mantreads damage
					{
						damage += 20.0;
					}
					case 128:
					{
						//redo equalizer damage
						if(!(damagetype & DMG_BLAST))
						{
							damage = 65.0;
							int MaxHP = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, attacker);
							if(GetClientHealth(attacker)>MaxHP/2.0)
								damage *= 0.6;
							else
								damage *= 1.4;
							//calculate crits
							if(isKritzed(attacker))
								damage *= 3.0;
							else if (tank)
							{
								if(isMiniKritzed(attacker))
									damage *= 1.35;
							}
							else if (!tank)
							{
								if(isMiniKritzed(attacker,victim))
									damage *= 1.35;
							}
						}
					}
				}
			}
			case TFClass_DemoMan:
			{
				if(weaponIndex == 307 && damagetype & DMG_BLAST == DMG_BLAST)
				{
					damage *= 1.15;  //caber damage bonus just on explosion
					SetEntPropFloat(weapon, Prop_Send, "m_flLastFireTime", GetGameTime()); //make sure meter is reset
				}
			}
			case TFClass_Scout:
			{
				int melee = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Melee, true);
				int meleeIndex = -1;
				if(melee != -1) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");

				if(meleeIndex==349)
				{
					//add ignite if HEAT is active
					if((g_condFlags[attacker] & TF_CONDFLAG_HEAT && !(damagetype & DMG_BURN)))
					{
						float dist = getPlayerDistance(attacker,victim);
						if(dist<768)
							damagetype |= DMG_IGNITE; //cap ignition up to 768 hu
					}
					if((damagetype & DMG_BURN) && !tank)
					{
						if(!isMiniKritzed(attacker,victim))
						{
							damage = 4.0;
							damagetype &= ~DMG_CRIT;
						}
						else
							damage = 4.0*1.35;
					}
				}
				if(weaponIndex == 44 && inflictor != attacker && !tank) //sandman ball
				{
					float distance = getPlayerDistance(attacker,victim); //get distance from attacker to victim; couldn't actually find travel time of ball
					if(g_condFlags[attacker] & TF_CONDFLAG_BASED)
					{
						distance = 1440.0; //distance for moonshot
						if(!(damagetype & DMG_CRIT))
						{
							damagetype |= DMG_CRIT;
						}
					}
					if(damagetype & DMG_CRIT)
					{
						if(isMiniKritzed(attacker,victim) && distance<1440.0)
							damage = 20.0;
						else
							damage = 45.0;
					}
					float duration = 1.6 + RoundToNearest(distance/100.0)/4.0; //round to nearest quarter second. range of 0-7
					if(distance>150)
					{
						// TF2_AddCondition(victim,TFCond_MarkedForDeath,duration); //minimum 1 second, ~175 distance
						g_condFlags[victim] |= TF_CONDFLAG_BONK;
						g_bonkedDebuff[victim][0] = attacker+0.0;
						g_bonkedDebuff[victim][1] = duration;
						CreateParticle(victim,"conc_stars",duration,_,_,_,_,80.0,_,false,false);
					}
					TF2_RemoveCondition(victim,TFCond_Dazed); //no slow (removes of other slow effects but most too situational to worry)
				}
				if(weaponIndex == 220 && damagetype&DMG_BULLET) //shortstop
				{
					//increase ramp up
					float dist = getPlayerDistance(attacker,victim);
					if(dist < 512 && (!(damagetype&DMG_CRIT==DMG_CRIT) || isMiniKritzed(attacker,victim)))
					{
						float modifier = (6.0+((512.0-dist)/512.0))/6.0;
						damage *= modifier;
					}
				}
			}
			case TFClass_Sniper:
			{
				switch(weaponIndex)
				{
					case 526, 30665:
					{
						//machina fix shot from building
						if(damagetype & DMG_SHOCK && !tank)
						{
							// damagetype &= ~DMG_SHOCK;
							if(damagetype & DMG_CRIT && !isKritzed(attacker) && !isMiniKritzed(attacker,victim))
							{
								damagecustom = TF_CUSTOM_HEADSHOT;
							}
						}
					}
					case 402:
					{
						//bazaar bargain charge damage, only when not in full charge
						if(g_condFlags[attacker] & TF_CONDFLAG_INFIRE != TF_CONDFLAG_INFIRE)
						{
							float charge = GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage");
							if(charge>50)
							{
								charge -= 50;
								damage *= 1-((charge/100)*0.2);
							}
							//check resistances
							int vicPrimary = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Primary, true);
							int vicPriIndex = -1;
							if(vicPrimary != -1) vicPriIndex = GetEntProp(vicPrimary, Prop_Send, "m_iItemDefinitionIndex");
							int MaxHP = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, victim);

							if(TF2_IsPlayerInCondition(victim,TFCond_Slowed) && vicPriIndex==312 && (GetClientHealth(victim)-damage)<MaxHP/2)
								damage *= 0.7;
							if(TF2_IsPlayerInCondition(victim,TFCond_UberBulletResist))
								damage *= 0.4;
							else if(TF2_IsPlayerInCondition(victim,TFCond_SmallBulletResist))
								damage *= 0.9;
						}
					}
					// case 232: //Bushwacka knockback and MFD
					// {
					// 	if(!tank)
					// 	{
					// 		// if(!TF2_IsPlayerInCondition(victim,TFCond_Ubercharged)&&!TF2_IsPlayerInCondition(victim,TFCond_UberchargeFading)&&!TF2_IsPlayerInCondition(victim,TFCond_UberchargedCanteen))
					// 		// 	TF2_AddCondition(victim,TFCond_MarkedForDeath,2.1);
					// 		if(!TF2_IsPlayerInCondition(victim,TFCond_MegaHeal))
					// 		{
					// 			damageForce[0]*=0.009; damageForce[1]*=0.009; damageForce[2]=damageForce[2]*0.007+250.0;
					// 			TeleportEntity(victim,NULL_VECTOR,NULL_VECTOR,damageForce);
					// 			TF2_AddCondition(victim,TFCond_AirCurrent);
					// 			g_condFlags[victim] |= TF_CONDFLAG_HOVER;
					// 		}
					// 	}
					// }
				}
			}
			case TFClass_Pyro:
			{
				switch(weaponIndex)
				{
					case 813, 834:
					{
						//neon explosion if intact
						if(g_meterMel[attacker]>=100.0)
						{
							SetEntProp(weapon, Prop_Send, "m_bBroken",1);
							float bonus = 80.0;
							//calculate crits
							if(damagetype&DMG_CRIT == DMG_CRIT)
							{
								if(isMiniKritzed(attacker,victim))
									bonus *= 1.35;
								else
									bonus *= 3.0;
							}
							damage += bonus;
							damagetype |= DMG_BLAST;
							g_meterMel[attacker] = 0.0 - damage;
							TF2_RemoveCondition(attacker,TFCond_FocusBuff);
							TF2_RemoveCondition(attacker,TFCond_Sapped);
							int team = GetEntProp(attacker, Prop_Data, "m_iTeamNum");
							if(team == 3)
								CreateParticle(victim,"drg_cow_explosioncore_charged_blue",3.0,_,_,_,_,_,3.0,false);
							else if(team == 2)
								CreateParticle(victim,"drg_cow_explosioncore_charged",3.0,_,_,_,_,_,3.0,false);
							EmitAmbientSound("mvm/giant_soldier/giant_soldier_explode.wav",damagePosition,victim);
							DataPack pack = new DataPack();
							pack.Reset();
							pack.WriteCell(attacker);
							pack.WriteCell(victim);
							RequestFrame(NeonExplosion,pack);
						}
					}
					case 740:
					{
						if(!(damagetype&DMG_HALF_FALLOFF) && !(damagetype&DMG_BURN) && victim != attacker && !tank)
						{
							TF2_RemoveCondition(victim,TFCond_Dazed); //negate stun on scorch shot
							TF2_AddCondition(victim,TFCond_ImmuneToPushback,0.015,attacker); //negate knockback of scorch shot
						}
					}
					case 595: //manmelter
					{
						if(!tank)
						{
							if(damagetype & DMG_BULLET && victim != attacker && victim != inflictor)
							{
								//reward crit progress
								g_meterSec[attacker]+=33.3;
							}
						}
					}
					case 593:  //third degree
					{
						if(!tank)
						{
							// if(TF2Util_GetPlayerBurnDuration(victim) > 0)
							// 	damage *= 1.35;
							if(!(damagetype & DMG_SHOCK))
							{
								for (int i = 1 ; i <= MaxClients ; i++)
								{
									if(IsValidClient(i,false) && i!=victim)
									{
										float dist = getPlayerDistance(i,victim);
										if(GetClientTeam(i)==GetClientTeam(victim) && dist < 256)
										{
											float target_pos[3];
											GetEntPropVector(i, Prop_Send, "m_vecOrigin", target_pos);
											target_pos[2] += 41;
											Handle hndl = TR_TraceRayFilterEx(damagePosition, target_pos, MASK_SOLID, RayType_EndPoint, PlayerTraceFilter, i);
											if(TR_DidHit(hndl) == false || IsValidClient(TR_GetEntityIndex(hndl),false))
											{
												if(!TF2_IsPlayerInCondition(i,TFCond_Cloaked) && !TF2_IsPlayerInCondition(i,TFCond_Disguised))
												{
													int newdamagetype = damagetype | DMG_SHOCK;
													float newdamage = damage;
													//add SHOCK damage flag to prevent recursive calls on this hook
													//check for minicrit
													if(damagetype & DMG_CRIT)
													{
														if(!isKritzed(attacker) && (isMiniKritzed(attacker,victim) || g_consecHits[attacker] == 1))
														{
															newdamage /= 1.35;
															newdamagetype = newdamagetype & ~DMG_CRIT;
															TF2_AddCondition(i,TFCond_MarkedForDeathSilent,0.015);
														}
														else
															newdamage /= 3.0;
													}
													SDKHooks_TakeDamage(i, inflictor, attacker, newdamage, newdamagetype, weapon, damageForce, damagePosition, false);
												}
											}
											delete hndl;
										}
									}
								}
							}
							else
							{
								damagetype &= ~DMG_SHOCK;
							}
						}
					}
					case 348: //sharpened volcano, player hit turns into living mine
					{
						if(damagetype & DMG_CLUB && !tank && (!TF2_IsPlayerInCondition(victim,TFCond_Ubercharged)&&!TF2_IsPlayerInCondition(victim,TFCond_UberchargeFading)&&!TF2_IsPlayerInCondition(victim,TFCond_UberchargedCanteen)))
						{
							g_condFlags[victim] |= TF_CONDFLAG_VOLCANO;
							if(TF2Util_GetPlayerBurnDuration(victim)<8)
							{
								if(TF2_GetPlayerClass(victim) == TFClass_Pyro)
									TF2_AddCondition(victim,TFCond_BurningPyro,8.0,attacker);
								else 
									TF2_AddCondition(victim,TFCond_OnFire,8.0,attacker);
								TF2Util_SetPlayerBurnDuration(victim,8.0);
							}
						}
					}
				}
			}
			case TFClass_Medic:
			{
				switch(weaponIndex)
				{
					case 17,204,36,412: //syringe damage
					{
						if(damage == 10.0 && damagetype == DMG_BULLET)
						{
							damage = 0.01; //ghost hits for flinching
						}
						else if(damagetype == (DMG_CRIT | DMG_BULLET))
						{
							damage = 30.0; //base for crits
							//subtract incoming damage from base hit
							float baseDMG = 10.0;
							Address address = TF2Attrib_GetByDefIndex(weapon,1);
							if(address != Address_Null)
							{
								damage *= TF2Attrib_GetValue(address);
								baseDMG *= TF2Attrib_GetValue(address);
							}
							float dist = getPlayerDistance(attacker,victim);
							if(dist<512) baseDMG *= 1.0 + 0.2*(512-dist)/512;
							else if(dist>512) baseDMG *= 1.0 - 0.50*((dist-512) > 512.0 ? 512.0 : (dist-512))/512.0;
							damage -= baseDMG;
						}
						else
						{
							int isCrit = 0;
							Address address = TF2Attrib_GetByDefIndex(weapon,1);
							damage = 10.0;
							if(address != Address_Null) damage *= TF2Attrib_GetValue(address);
							//check for crit projectile
							if(g_syringeHit[victim]>10.0)
							{
								isCrit = 1;
								damage = 30.0;
								if(address != Address_Null) damage *= TF2Attrib_GetValue(address);
							}
							else
							{
								float dist = getPlayerDistance(attacker,victim);
								if(dist<512) damage *= 1.0 + 0.2*(512-dist)/512;
								if(tank)
								{
									if(isMiniKritzed(attacker)) isCrit = 1;
								}
								else
								{
									if(isMiniKritzed(attacker,victim)) isCrit = 1;
								}
								if(isCrit == 1)
								{
									damage *= 1.35;
								}
								else
								{
									if(dist>512) damage *= 1.0 - 0.50*((dist-512) > 512.0 ? 512.0 : (dist-512))/512.0;
								}
							}
							g_syringeHit[victim] = 0.0;
							damagetype = DMG_BULLET | DMG_NOCLOSEDISTANCEMOD | DMG_PREVENT_PHYSICS_FORCE | DMG_USEDISTANCEMOD;
							if (isCrit!=0) damagetype |= DMG_CRIT;
						}
					}
					case 413: //solemn vow knockback
					{
						if(!tank)
						{
							float vicForce[3],atkForce[3];
							float unitForce[3];
							unitForce[0] = damageForce[0]/SquareRoot(Pow(damageForce[0],2.0)+Pow(damageForce[1],2.0));
							unitForce[1] = damageForce[1]/SquareRoot(Pow(damageForce[0],2.0)+Pow(damageForce[1],2.0));
							
							if(!TF2_IsPlayerInCondition(victim,TFCond_MegaHeal)&&!TF2_IsPlayerInCondition(victim,TFCond_ImmuneToPushback))
							{
								vicForce[0] = unitForce[0]*200; vicForce[1] = unitForce[1]*200; vicForce[2]= 350.0;
								TeleportEntity(victim,NULL_VECTOR,NULL_VECTOR,vicForce);
								TF2_AddCondition(victim,TFCond_AirCurrent);
								g_condFlags[victim] |= TF_CONDFLAG_HOVER;
							}
							if(!TF2_IsPlayerInCondition(attacker,TFCond_MegaHeal)&&!TF2_IsPlayerInCondition(attacker,TFCond_ImmuneToPushback))
							{
								atkForce[0] = unitForce[0]*-400; atkForce[1] = unitForce[1]*-400; atkForce[2]= 350.0;
								TeleportEntity(attacker,NULL_VECTOR,NULL_VECTOR,atkForce);
								TF2_AddCondition(attacker,TFCond_AirCurrent);
								g_condFlags[attacker] |= TF_CONDFLAG_HOVER;
							}
						}
					}
				}
			}
		}

		switch(victimClass)
		{
			case TFClass_Scout:
			{
				int melee = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Melee, true);
				int meleeIndex = -1;
				if(melee != -1) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");

				if(meleeIndex==349)
				{
					//extra damage vuln for Scout in HEAT mode
					if(g_condFlags[victim] & TF_CONDFLAG_HEAT)
					{
						damage *= 1.25;
					}
				}
			}
			case TFClass_Sniper:
			{
				int secondary = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Secondary, true);
				int secondaryIndex = -1;
				if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
				int melee = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Melee, true);
				int meleeIndex = -1;
				if(melee>0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");

				if(weaponIndex != 460 && weaponIndex != 171 && secondaryIndex == 57)
				{
					//razorback blocks lethal damage
					int flags = GetEntProp(secondary, Prop_Data, "m_fEffects"); //129 = intact, 161 = broken
					int currHP = GetClientHealth(victim);
					//Trigger protection if above 63 HP
					if(currHP>63 && flags==129)
					{
						g_condFlags[victim] |= TF_CONDFLAG_RAZOR;
						g_meterSec[victim] = 0.15;
					}
					//only if protection is active
					if(g_condFlags[victim]&TF_CONDFLAG_RAZOR==TF_CONDFLAG_RAZOR || ((damage==0 && damagecustom==TF_CUSTOM_BACKSTAB) && currHP>63))
					{
						if(!((damagecustom==TF_CUSTOM_HEADSHOT && (tfAttackerClass==TFClass_Sniper||weaponIndex==61||weaponIndex==1006)) || damagecustom==TF_CUSTOM_HEADSHOT_DECAPITATION || (TF2Util_GetPlayerConditionProvider(victim,TFCond_MarkedForDeathSilent)==attacker && weaponIndex==1098)))
						{
							
							float dmgMod = damagecustom==TF_CUSTOM_BACKSTAB ? currHP+0.0 : damage;
							if(meleeIndex==232 && GetEntPropEnt(victim, Prop_Send, "m_hActiveWeapon")==melee)
							{
								dmgMod *= 1.2;
							}
							dmgMod = (currHP-dmgMod)>0 ? dmgMod : currHP-1.0;
							if(currHP-dmgMod == 1 && currHP != 1 && (flags==129 || (damage==0 && damagecustom==TF_CUSTOM_BACKSTAB))) //break shield
							{
								TF2_AddCondition(victim,TFCond_SpeedBuffAlly,3.0);
								SetEntPropFloat(victim, Prop_Send, "m_flItemChargeMeter", 0.0, 1);
								SetEntProp(secondary, Prop_Data, "m_fEffects",161); //break shield?
								damagetype &= ~DMG_IGNITE;
								
								DataPack pack = new DataPack();
								pack.Reset();
								pack.WriteCell(attacker);
								pack.WriteCell(0);
								RequestFrame(CleanDOT,pack);
							}
							if(meleeIndex==232 && GetEntPropEnt(victim, Prop_Send, "m_hActiveWeapon")==melee)
								damage = currHP-dmgMod == 1 ? dmgMod/1.2 : damage/1.2;
							else
								damage = dmgMod;
						}
					}
					else if((damage==0 && damagecustom==TF_CUSTOM_BACKSTAB) && currHP<=63)
					{
						damage = currHP*6.0;
					}
				}
			}
			case TFClass_Soldier,TFClass_DemoMan:
			{
				if(victim!=attacker && victim!=inflictor)
				{
					//BASE Jumper retraction on damage
					int primary = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Primary, true);
					int primaryIndex = -1;
					if(primary>0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
					int secondary = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Secondary, true);
					int secondaryIndex = -1;
					if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
					if(TF2_IsPlayerInCondition(victim,TFCond_Parachute) && (secondaryIndex == 1101 || primaryIndex == 1101))
					{
						g_meterSec[victim] += damage*(PARACHUTE_TIME/80.0);
					}
				}
			}
			case TFClass_Spy:
			{
				int melee = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Melee, true);
				int meleeIndex = -1;
				if(melee>0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
				//spy-cicle melted resistance
				if(meleeIndex == 649 && weaponIndex != 460 && weaponIndex != 171)
				{
					if(g_condFlags[victim] & TF_CONDFLAG_INFIRE)
						damage *= 0.75;
				}
			}
		}

		if(!tank)
		{
			if(g_condFlags[victim] & TF_CONDFLAG_VOLCANO)
			{
				if(damagetype & DMG_BURN) //afterburn effect for volcano
					CreateParticle(victim,"dragons_fury_effect",2.0);
				// if(damagetype & DMG_IGNITE) //increase fire damage for volcano marked targets
				// 	damage *= 1.3;
			}

			if((damagetype & DMG_CRIT == DMG_CRIT) &&
			   (TF2_IsPlayerInCondition(victim,TFCond_UberBlastResist) && damagetype & DMG_BLAST == DMG_BLAST) ||
			   (TF2_IsPlayerInCondition(victim,TFCond_UberBulletResist) && (damagetype & DMG_BULLET == DMG_BULLET || damagetype & DMG_BUCKSHOT == DMG_BUCKSHOT)) ||
			   (TF2_IsPlayerInCondition(victim,TFCond_UberFireResist) && damagetype & DMG_IGNITE == DMG_IGNITE))
			{
				//Vaccinator crit damage modifier
				float multiplier = 1.0;
				if((isKritzed(attacker) && weaponIndex!=441) || weaponIndex==355 || weaponIndex==232)
				{
					multiplier = 1.275;
				}
				else if(isMiniKritzed(attacker,victim) || weaponIndex==441)
				{
					multiplier = 1.125;
				}
				damage *= multiplier; //add to damage
			}
		}
	}

	if(!(damagetype & DMG_BURN) && IsValidClient(attacker))
	{
		// PrintToChatAll("%d->%d %.2f",attacker,victim,GetGameTime());
		// PrintToChatAll("%.2f %d %d %d %d %d",damage,victim,attacker,weapon,inflictor,damagetype);
		// PrintToChatAll("%.2f %.2f %.2f | %.2f %.2f %.2f",damageForce[0],damageForce[1],damageForce[2],damagePosition[0],damagePosition[1],damagePosition[2]);
		// if(IsValidClient(attacker)) PrintToChat(attacker,"%d->%d %.2f",attacker,victim,getPlayerDistance(attacker,victim));
	}
	return Plugin_Changed;
}

Action BuildingThink(int building,int client)
{
	//update animation speeds for building construction
	char class[64];
	GetEntityClassname(building,class,64);
	int seq = GetEntProp(building, Prop_Send, "m_nSequence");
	float rate = RoundToFloor(GetEntPropFloat(building, Prop_Data, "m_flPlaybackRate")*100)/100.0;

	if(!(StrContains(class,"sapper") != -1 || StrContains(class,"builder") != -1))
	{
		int builder = GetEntPropEnt(building, Prop_Send, "m_hBuilder");
		if(IsValidClient(builder))
		{
			int melee = TF2Util_GetPlayerLoadoutEntity(builder, TFWeaponSlot_Melee, true);
			int meleeIndex = -1;
			if(melee != -1) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
			if(TF2_GetPlayerClass(builder)==TFClass_Engineer)
			{
				if(rate>0)
				{
					if(StrEqual(class,"obj_sentrygun") && seq == 2)
					{
						// SetEntPropFloat(building, Prop_Send, "m_flCycle",cons);
						if(IS_MEDIEVAL)
						{
							SetVariantInt(999);
							AcceptEntityInput(building,"RemoveHealth");
						}
					}
					if(StrEqual(class, "obj_dispenser"))
					{
						//setup southern hospitality extra range
						if(seq == 1 || (seq == 0 && g_bIsMVM))
						{
							bool valid = false;
							if(!IsValidEdict(g_engyDispenser[builder]))
								valid = true;
							else
							{
								char class2[64];
								GetEntityClassname(g_engyDispenser[builder],class2,64);
								if(!StrEqual(class2,"obj_dispenser") && building != g_engyDispenser[builder])
									valid = true;
							}
							if(valid) //no existing dispenser
							{
								g_engyDispenser[builder] = building;
								float range = 1.0;
								if(g_bIsMVM) //mvm radius
								{
									Address addr = TF2Attrib_GetByName(melee, "clip size bonus");
									if(addr != Address_Null)
									{
										float value = TF2Attrib_GetValue(addr);
										range += value;
									}
								}
								if(meleeIndex == 155) //is southern hospitality
								{
									g_dispenserStatus[building] = 1;
									TF2Attrib_SetByDefIndex(melee,345,range+3.0); //engy dispenser radius increased
								}
								else //is not
								{
									g_dispenserStatus[building] = 0;
									TF2Attrib_SetByDefIndex(melee,345,range); //engy dispenser radius increased
								}
							}
						}
						//emit ring every 2 seconds
						if(seq == 0 && IsValidEdict(g_engyDispenser[builder]))
						{
							if(g_dispenserStatus[g_engyDispenser[builder]]==1)
							{
								int team = GetClientTeam(builder);
								if(g_meterMel[builder]>0.98 && g_meterMel[builder]<1.0)
								{
									if(team==2)
										CreateParticle(building,"medic_radiusheal_red_volume",0.5,_,_,_,_,_,_,false);
									if(team==3)
										CreateParticle(building,"medic_radiusheal_blue_volume",0.5,_,_,_,_,_,_,false);
									g_meterMel[builder] = 1.0;
								}
								if(g_meterMel[builder]>2.0)
								{
									if(team==2)
										CreateParticle(building,"medic_radiusheal_red_volume",0.5,_,_,_,_,_,_,false);
									if(team==3)
										CreateParticle(building,"medic_radiusheal_blue_volume",0.5,_,_,_,_,_,_,false);
									CreateParticle(building,"bomibomicon_ring",1.0,_,_,_,_,_,_,false);
									g_meterMel[builder] = 0.0;
								}
							}
						}
					}
				}
			}
		}
	}
	else if (StrContains(class,"sapper") != -1)
	{
		if(HasEntProp(building, Prop_Send, "m_hBuilder"))
		{
			int builder = GetEntPropEnt(building, Prop_Send, "m_hBuilder");
			if(HasEntProp(building, Prop_Send, "m_hBuiltOnEntity") && client == builder && IsValidClient(builder))
			{
				int sapperIndex = -1;
				int onbuilding = GetEntPropEnt(building, Prop_Send, "m_hBuiltOnEntity");
				if(IsValidEdict(onbuilding))
				{
					int sapper = TF2Util_GetPlayerLoadoutEntity(builder, TFWeaponSlot_Building, true);
					sapperIndex = GetEntProp(sapper, Prop_Send, "m_iItemDefinitionIndex");
					if(sapperIndex == 810 || sapperIndex == 831) //Red-Tape Ping
					{
						g_sapperTime[building] += 0.015;
						if(g_sapperTime[building]>=3.0)
						{
							g_sapperTime[building] = 0.0;
							float position[3];
							GetEntPropVector(onbuilding, Prop_Send, "m_vecOrigin", position);
							EmitAmbientSound("misc/rd_finale_beep01.wav",position,building,SNDLEVEL_MINIBIKE,_,3.0);
							int team = GetClientTeam(builder);
							int idx, currEnts = GetMaxEntities();
							for (idx = 1; idx < currEnts; idx++)
							{
								if(idx<=MaxClients) //find enemy players
								{
									if (IsValidClient(idx,false))
									{
										if (IsPlayerAlive(idx) && (GetClientTeam(idx) != team || idx==builder) && !TF2_IsPlayerInCondition(idx,TFCond_Cloaked) && !TF2_IsPlayerInCondition(idx,TFCond_CloakFlicker))
										{
											float distance = getPlayerDistance(onbuilding,idx);
											if (distance < 512)
											{
												SetEntProp(idx, Prop_Send, "m_bGlowEnabled", 1);
												EmitSoundToClient(idx, "misc/rd_finale_beep01.wav", idx, _, SNDLEVEL_GUNFIRE, _, SNDVOL_NORMAL, _, _);
												SetHudTextParams(0.1, -0.16, 3.0, 255, 255, 255, 255);
												ShowHudText(idx,1,"⊙ REVEALED!");
												CreateTimer(2.0,updateGlow,idx);
											}
										}
									}
								}
								else //find enemy buildings
								{
									if(IsValidEdict(idx))
									{
										char class2[64];
										GetEntityClassname(idx,class2,64);
										if(StrEqual(class2,"obj_sentrygun") || StrEqual(class2,"obj_teleporter") || StrEqual(class2,"obj_dispenser"))
										{
											float distance = getPlayerDistance(onbuilding,idx);
											if(GetEntProp(builder, Prop_Send,"m_iTeamNum") != GetEntProp(idx, Prop_Send,"m_iTeamNum") && distance < 512)
											{
												SetEntProp(idx, Prop_Send, "m_bGlowEnabled", 1);
												CreateTimer(2.0,updateGlow,idx);
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

void healBuild(int building)
{
	SetVariantInt(10);
	AcceptEntityInput(building,"AddHealth");
}

Action BuildingDamage (int building, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if(weapon != -1)
	{
		char class[64];
		GetEntityClassname(building, class, sizeof(class));
		int weaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		switch(weaponIndex)
		{
			case 17,204,36,412:
			{ //syringe damage
				if(damage>1 && !(damagetype & DMG_BULLET))
				{
					Address address = TF2Attrib_GetByDefIndex(weapon,1);
					damage = 10.0;
					if(address != Address_Null) damage *= TF2Attrib_GetValue(address);
					damagetype = DMG_BULLET;
				}
			}
			case 460:
			{ //enforcer piercing sapper armor
				int sapped = GetEntProp(building, Prop_Send, "m_bHasSapper");
				if(sapped == 1 && StrEqual("obj_sentrygun",class)) damage /= 0.67;
			}
			case 153,466:
			{ //reduce homewrecker sapper damage
				if(StrContains(class,"sapper") != -1 || StrContains(class,"builder") != -1)
					damage *= 0.5;
			}
			case 526, 30665:
			{
				//Machina penetrate building
				int idx, closest = -1;
				int victim, hit;
				float distance, closestDistance;
				float client_pos[3],target_pos[3], angles1[3];
				GetClientEyePosition(attacker,client_pos);
				for(idx = 1; idx < 2048; idx++)
				{
					if(IsValidEdict(idx) && idx != building && idx != attacker)
					{
						GetEntityClassname(idx, class, sizeof(class));
						if(idx <= MaxClients || StrEqual(class, "obj_sentrygun") || StrEqual(class, "obj_dispenser") || StrEqual(class, "obj_teleporter"))
						{
							GetEntPropVector(idx, Prop_Send, "m_vecOrigin", target_pos);
							target_pos[2]+=40;
							distance = GetVectorDistance(damagePosition, target_pos);
							if(distance < 512.0 && GetEntProp(idx, Prop_Send, "m_iTeamNum") != GetEntProp(attacker, Prop_Send, "m_iTeamNum"))
							{
								GetClientEyeAngles(attacker, angles1);								
								Handle hndl = TR_TraceRayFilterEx(client_pos, angles1, MASK_SOLID_BRUSHONLY|CONTENTS_HITBOX, RayType_Infinite, SimpleTraceFilter, idx);
								if (TR_DidHit(hndl))
								{
									victim = TR_GetEntityIndex(hndl);
									if(victim == idx)
									{
										if(closestDistance > distance || closestDistance == 0.0)
										{
											hit = TR_GetHitGroup(hndl);
											closest = idx; closestDistance = distance;
										}
									}
								}
								delete hndl;
							}
						}
					}
				}
				if(closest != -1)
				{
					if(IsValidClient(closest,false))
					{
						if(hit == 1) damagetype |= DMG_CRIT;
						SDKHooks_TakeDamage(closest, inflictor, attacker, damage, damagetype|DMG_SHOCK, weapon, damageForce, target_pos, false);
					}
					else
					{
						SetVariantInt(RoundFloat(damage));
						AcceptEntityInput(closest,"RemoveHealth");
						if(damage >= GetEntProp(closest, Prop_Send, "m_iHealth"))
							EmitAmbientSound("misc/sniper_railgun_double_kill.wav",target_pos,closest,SNDLEVEL_TRAIN);
					}
				}
			}
			case 402:
			{
				//bazaar charge damage
				if(g_condFlags[attacker] & TF_CONDFLAG_INFIRE != TF_CONDFLAG_INFIRE)
				{
					float charge = GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage");
					if(charge>50)
					{
						charge -= 51;
						damage *= 1-((charge/100)*(0.2));
					}
				}
			}
			case 588,442,441: //fix damage for laser weapons: pomson,bison,mangler
			{
				damage /= 0.2;
				damage *= 0.75;
			}
		}
		if(StrEqual("obj_sentrygun",class))
		{
			int owner = GetEntPropEnt(building, Prop_Send, "m_hBuilder");
			if(owner != -1)
			{
				//damage resistance of wrangler
				int secondary = TF2Util_GetPlayerLoadoutEntity(owner, TFWeaponSlot_Secondary, true);
				int secondaryIndex = -1;
				if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
				if(secondaryIndex == 140 || secondaryIndex == 1086 || secondaryIndex == 30668)
				{
					int shield = GetEntProp(building, Prop_Send, "m_nShieldLevel");
					
					if(shield > 0 && weaponIndex != 460 && weaponIndex != 171)
						damage *= (5.0/3.3); //change to 50% res
				}
			}
		}
		else
		{
			int seq = GetEntProp(building, Prop_Send, "m_nSequence");
			//reduce building health while constructing
			if(seq == 1)
			{
				g_buildingHeal[building] -= damage;
			}
		}
	}
	return Plugin_Changed;
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	// int weaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	TFClassType tfAttackerClass = TF2_GetPlayerClass(client);
	int weaponIndex = -1;
	if(weapon>0) weaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	//triple hit crit check
	if(weapon == TF2Util_GetPlayerLoadoutEntity(client, TFWeaponSlot_Melee, true))
	{
		if (GetGameTime()-g_lastHit[client] > (g_nextHit[client]-g_lastHit[client])*1.5 && g_consecHits[client]!=-1)
		{
			g_consecHits[client]=0;
			return Plugin_Continue;
		}
		if((tfAttackerClass == TFClass_Scout && g_consecHits[client]%4==3) || (tfAttackerClass != TFClass_Scout && g_consecHits[client]%3==2))
		{
			result = true;
			return Plugin_Changed;
		}
	}
	if(weaponIndex == 1098) //reset classic headshots
	{
		g_meterPri[client] = 0.0;
	}
	return Plugin_Continue;
}

Action critGlow(Handle timer, int attacker)
{
	TF2_AddCondition(attacker,TFCond_CritDemoCharge,(g_nextHit[attacker]-g_lastHit[attacker])*2.0);
	return Plugin_Continue;
}

public void Event_SpawnAmmo(int entity)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	char name[64];
	GetEntPropString(entity, Prop_Data, "m_iName",name,64);
	if(StrContains(class,"ammo_pack") != -1)
	{
		int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if(IsValidClient(owner))
		{
			if(IS_MEDIEVAL)
			{
				int healthpack = CreateEntityByName("item_healthkit_small");
				if(IsValidEdict(healthpack))
				{
					// int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
					g_FilteredEntity = owner;
					DispatchKeyValue(healthpack, "StartDisabled", "false");
					DispatchKeyValue(healthpack, "AutoMaterialize", "false");
					AcceptEntityInput(healthpack,"Enable");
					SetEntData(healthpack,336,1,_,true); //m_spawnflags
					SetEntData(healthpack,344,1,_,true); //m_fFlags
					float position[3];
					GetEntPropVector(owner, Prop_Send, "m_vecOrigin", position);

					TeleportEntity(healthpack, position, NULL_VECTOR, NULL_VECTOR);
					
					DispatchSpawn(healthpack);
					AcceptEntityInput(entity,"Kill");
					CreateTimer(30.0, PackDelete, healthpack);
				}
			}
			else if(IS_HALLOWEEN)
			{
				if(g_spawnPumpkin[owner] != 0)
				{
					int team = GetClientTeam(g_spawnPumpkin[owner]);
					SetEntProp(entity, Prop_Send, "m_iTeamNum", team);
					SetEntityModel(entity,"models/props_halloween/pumpkin_loot.mdl");
					if(team==2)
						CreateParticle(entity,"burningplayer_redglow",30.0,_,_,_,_,25.0,_,true,false,false);
					if(team==3)
						CreateParticle(entity,"burningplayer_blueglow",30.0,_,_,_,_,25.0,_,true,false,false);
					float vel[3]; vel[2]=100.0;
					TeleportEntity(entity,NULL_VECTOR,NULL_VECTOR,vel);
					SDKHook(entity, SDKHook_Touch, ammoOnTouch);
					g_spawnPumpkin[owner] = 0;
				}
				else
				{
					int Ammopack = CreateEntityByName("item_ammopack_medium");
					if(IsValidEdict(Ammopack))
					{
						DispatchKeyValue(Ammopack, "OnPlayerTouch", "!self,Kill,,0,-1");
						DispatchKeyValue(Ammopack, "targetname", "customAmmo");
						float AmmoPos[3];
						GetEntPropVector(owner, Prop_Send, "m_vecOrigin", AmmoPos);
						AmmoPos[2]+=5;
						TeleportEntity(Ammopack, AmmoPos, NULL_VECTOR, NULL_VECTOR);

						DispatchSpawn(Ammopack);
						AcceptEntityInput(entity,"Kill");
						CreateTimer(30.0, PackDelete, Ammopack);
					}
				}
			}
			else if(g_spawnHealth[owner] != 0)
			{
				AcceptEntityInput(entity,"Kill");
				g_spawnHealth[owner] = 0;
			}
		}
	}
}

public bool MedipackTraceFilter(int ent, int contentMask, any data)
{
    return (ent != g_FilteredEntity);
}

public Action PackHamDelete(Handle timer, int pack)
{
	if(IsValidEdict(pack))
	{
		char class[64];
		GetEntityClassname(pack, class, sizeof(class));
		if(StrEqual(class,"item_healthkit_medium")||StrContains(class,"_ammo")!=-1)
		{
			AcceptEntityInput(pack,"Kill");
		}
	}
	return Plugin_Continue;
}

public Action PackDelete(Handle timer, int pack)
{
	if(IsValidEdict(pack))
	{
		char class[64];
		GetEntityClassname(pack, class, sizeof(class));
		if(StrEqual(class,"item_healthkit_small")||StrContains(class,"_ammo")!=-1)
		{
			AcceptEntityInput(pack,"Kill");
		}
	}
	return Plugin_Continue;
}

Action ammoOnTouch(int entity, int other)
{
	if(IsValidEdict(entity) && IsValidClient(other))
	{
		if(GetClientTeam(other) == GetEntProp(entity, Prop_Send, "m_iTeamNum"))
		{
			TF2_AddCondition(other,TFCond_HalloweenCritCandy,3.2);
			CreateTimer(0.15, PackDelete, entity);
			SDKUnhook(entity,SDKHook_Touch,ammoOnTouch);
		}
	}
	return Plugin_Handled;
}

public Action Event_PickUpAmmo(int entity, int other)
{
	if(IsValidClient(other))
	{
		char class[64],model[64];
		GetEntityClassname(entity, class, sizeof(class));
		int factor=0;
		int regen=1;
		GetEntPropString(entity, Prop_Data, "m_ModelName", model, 64);
		if(StrContains(class,"ammo_pack") != -1) { factor=2; regen=0; }
		else if(StrContains(class,"small") != -1) factor=5;
		else if(StrContains(class,"medium") != -1) factor=2;
		else if(StrContains(class,"large") != -1 || StrContains(class,"full") != -1) factor=1;

		int melee = TF2Util_GetPlayerLoadoutEntity(other, TFWeaponSlot_Melee, true);
		int meleeIndex = -1;
		if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
		if(meleeIndex==307)
			RefillCaber(other,factor,entity,regen);
		else if(meleeIndex==404)
			RefillPers(other,factor,entity,regen);
	}
	return Plugin_Continue;
}

public Action Event_PickUpHealth(int entity, int other)
{
	if(IsValidClient(other))
	{
		char class[64];
		GetEntityClassname(entity, class, sizeof(class));
		int melee = TF2Util_GetPlayerLoadoutEntity(other, TFWeaponSlot_Melee, true);
		int meleeIndex = -1;
		if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
		if(meleeIndex==317 && StrContains(class,"small") != -1) //cap overheal on candy cane
		{
			int health = GetClientHealth(other);
			int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity"); //-1 or 0 for world, should be valid client for dropped
			if(owner > 0 && IsValidClient(owner))
			{
				if(health<185 && health>100)
				{
					float heal = health+25.0 < 185 ? 25.0 : 185.0-health;
					TF2Util_TakeHealth(other,heal,TAKEHEALTH_IGNORE_MAXHEALTH);
					SetHudTextParams(0.1, -0.16, 0.1, 255, 255, 255, 255);
					ShowHudText(other,4,"+%.0f HP",heal);
					EmitSoundToClient(other,"items/smallmedkit1.wav");
					AcceptEntityInput(entity,"Kill");
				}
				// else
				// {
				// 	TF2Util_TakeHealth(other,10.0);
				// }
			}
		}
	}
	return Plugin_Continue;
}

public void RefillCaber(int iClient, int size, int pack, int refill)
{
	int melee = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Melee, true);
	float lastFire = GetEntPropFloat(melee, Prop_Send, "m_flLastFireTime");

	if(GetEntProp(melee, Prop_Send, "m_iDetonated")==1)
	{
		if(refill==1)
		{
			if(GetEntProp(pack,Prop_Send,"m_iTeamNum")==1)
				return;
			AcceptEntityInput(pack,"Disable");
			SetEntProp(pack,Prop_Send,"m_iTeamNum",1);
			CreateTimer(10.0, PackTimer, pack);
		}
		else
		{
			AcceptEntityInput(pack,"Kill");
		}
		EmitSoundToClient(iClient,"items/gunpickup2.wav");
		
		int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, false);
		int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, false);
		int primaryAmmo = -1;
		int secondaryAmmo = -1;
		int sndAmmo = -1;
		if(primary != -1)
			primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
		if(secondary != -1)
		{
			secondaryAmmo = GetEntProp(secondary, Prop_Send, "m_iPrimaryAmmoType");
			int currAmmo = GetEntProp(iClient, Prop_Data, "m_iAmmo", _, secondaryAmmo);
			switch(GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex"))
			{
				case 130:
				{
					sndAmmo = 36/size + currAmmo;
					sndAmmo = sndAmmo>36 ? 36 : sndAmmo;
				}
				case 265:
				{
					sndAmmo = 72/size + currAmmo;
					sndAmmo = sndAmmo>72 ? 72 : sndAmmo;
				}
				default:
				{
					sndAmmo = 24/size + currAmmo;
					sndAmmo = sndAmmo>24 ? 24 : sndAmmo;
				}
			}
		}
		if(primaryAmmo != -1)
		{
			int currAmmo = GetEntProp(iClient, Prop_Data, "m_iAmmo", _, primaryAmmo) + 16/size;
			SetEntProp(iClient, Prop_Data, "m_iAmmo", currAmmo > 16 ? 16 : currAmmo , _, primaryAmmo);
		}
		if(secondaryAmmo != -1)
			SetEntProp(iClient, Prop_Data, "m_iAmmo", sndAmmo , _, secondaryAmmo);

		switch(size)
		{
			case 5:
				SetEntPropFloat(melee, Prop_Send, "m_flLastFireTime", lastFire-6.0);
			case 2:
				SetEntPropFloat(melee, Prop_Send, "m_flLastFireTime", lastFire-15.0);
			case 1:
				SetEntPropFloat(melee, Prop_Send, "m_flLastFireTime", lastFire-30.0);
		}
	}
}

public void RefillPers(int iClient, int size, int pack, int refill)
{
	float newSize = size / 2.0;
	int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, false);
	int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, false);
	int primaryAmmo = -1;
	int secondaryAmmo = -1;
	int maxSndAmmo = -1;
	if(primary != -1)
		primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
	if(secondary != -1)
	{
		switch(GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex"))
		{
			case 130:
				maxSndAmmo = 16;
			case 265:
				maxSndAmmo = 36;
			default:
				maxSndAmmo = 12;
		}
		secondaryAmmo = GetEntProp(secondary, Prop_Send, "m_iPrimaryAmmoType");
	}
	float meter = GetEntPropFloat(iClient, Prop_Send,"m_flChargeMeter");
	int priCount = -1;
	if(primaryAmmo!=-1) priCount = GetEntProp(iClient, Prop_Data, "m_iAmmo", _, primaryAmmo);
	int secCount = -1;
	if(secondaryAmmo!=-1) secCount = GetEntProp(iClient, Prop_Data, "m_iAmmo", _, secondaryAmmo);
	if(!IS_MEDIEVAL && (priCount < 8 && primaryAmmo != -1) || (secCount < 8 && secondaryAmmo != -1) || (meter < 100.0))
	{
		if(refill==1)
		{
			if(GetEntProp(pack,Prop_Send,"m_iTeamNum")==1)
				return;
			AcceptEntityInput(pack,"Disable");
			SetEntProp(pack,Prop_Send,"m_iTeamNum",1);
			CreateTimer(10.0, PackTimer, pack);

			if(meter < 100.0)
			{
				meter += 100.0/size;
				if(meter>100) meter = 100.0;
				SetEntPropFloat(iClient, Prop_Send,"m_flChargeMeter",meter);
			}
		}
		else
		{
			AcceptEntityInput(pack,"Kill");
		}
		EmitSoundToClient(iClient,"items/gunpickup2.wav");
		
		int sndAmmo = -1;
		if(primaryAmmo != -1)
		{
			SetEntProp(iClient, Prop_Data, "m_iAmmo", RoundToFloor(priCount+8/newSize) > 8 ? 8 : RoundToFloor(priCount+8/newSize) , _, primaryAmmo);
		}
		if(secondaryAmmo != -1)
		{
			sndAmmo = RoundToFloor(maxSndAmmo/newSize + secCount);
			sndAmmo = sndAmmo>maxSndAmmo ? maxSndAmmo : sndAmmo;
			SetEntProp(iClient, Prop_Data, "m_iAmmo", sndAmmo , _, secondaryAmmo);
		}
	}
}

void MeltKnife(int iClient, int melee, float time)
{
	//Spy-cicle melting
	float position[3];
	GetClientEyePosition(iClient,position);

	TF2_RemoveCondition(iClient,TFCond_OnFire);
	TF2_RemoveCondition(iClient,TFCond_Jarated);
	TF2_RemoveCondition(iClient,TFCond_Milked);
	TF2_RemoveCondition(iClient,TFCond_Gas);
	TF2_RemoveCondition(iClient,TFCond_Bleeding);
	// TF2_RemoveCondition(iClient,TFCond_MarkedForDeath);
	// TF2_RemoveCondition(iClient,TFCond_MarkedForDeathSilent);
	EmitAmbientSound("player/flame_out.wav",position,iClient);
	SetEntProp(melee, Prop_Send,"m_bKnifeExists",0);
	SetEntPropFloat(melee, Prop_Send,"m_flKnifeRegenerateDuration",time);
	SetEntPropFloat(melee, Prop_Send,"m_flKnifeMeltTimestamp",GetGameTime());
	SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",100.0,2);
	g_meterMel[iClient] = GetGameTime();
	
	g_condFlags[iClient] |= TF_CONDFLAG_INFIRE;
	SetHudTextParams(0.1, -0.16, 0.1, 255, 255, 255, 255);
	ShowHudText(iClient,4,"+20 HP");
	TF2Util_TakeHealth(iClient,20.0);

	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
	ClientCommand(iClient, "r_screenoverlay \"effects/stealth_overlay\"");
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") | FCVAR_CHEAT);
}

public Action PackTimer(Handle timer, int pack)
{
    if(IsValidEdict(pack))
    {
        AcceptEntityInput(pack,"Enable");
        SetEntProp(pack,Prop_Send,"m_iTeamNum",0);
        return Plugin_Continue;
    }
    return Plugin_Continue;
}

public void buffSteak(int iClient) //steak and chocolate healing
{
	if(IsValidClient(iClient))
	{
		int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
		int secondaryIndex = -1;
		if(secondary >= 0)
			secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
		if((311 == secondaryIndex || 159 == secondaryIndex || 433 == secondaryIndex))
		{
			CreateTimer(1.125,chocolateHeal,iClient);
			CreateTimer(2.25,chocolateHeal,iClient);
		}
	}
}

public Action WeaponSwitch(int iClient, int weapon)
{
	TFClassType tfClientClass = TF2_GetPlayerClass(iClient);
	int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
	int secondaryIndex = -1;
	if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
	int melee = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Melee, true);
	int meleeIndex = -1;
	if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
	int current = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	switch(tfClientClass)
	{
		case TFClass_Heavy:
		{
			if(current==melee && meleeIndex==310)
			{
				int view = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
				int sequence = GetEntProp(view, Prop_Send, "m_nSequence");
				if(sequence != 8 && GetEntProp(iClient, Prop_Send, "m_iKillCountSinceLastDeploy") == 0.0)
					TF2_AddCondition(iClient,TFCond_MarkedForDeath,3.1); //add mark for death when switching warrior's spirit without kill
			}
			if(weapon==secondary)
			{
				if((secondaryIndex == 159 || secondaryIndex == 433 || secondaryIndex == 311)) //check dalokohs + steak speed
				{
					int view = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
					float rate = GetEntPropFloat(view, Prop_Send, "m_flPlaybackRate");
					float swaptime = 0.5 * (1/rate);
					SetEntPropFloat(secondary, Prop_Send, "m_flNextPrimaryAttack", GetGameTime()+swaptime-0.015);
				}
			}
		}
		case TFClass_Pyro: //make sure gravity resets on swapping weapons
		{
			if(secondaryIndex==1179)
			{
				if(weapon==secondary) //speed up thruster deploy
				{
					int view = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
					float rate = GetEntPropFloat(view, Prop_Send, "m_flPlaybackRate");
					float swaptime = 0.5 * (1/rate);
					CreateTimer(swaptime,SpeedThruster,iClient);
				}
			}
			else
			{
				g_condFlags[iClient] &= ~TF_CONDFLAG_HOVER;
				TF2_RemoveCondition(iClient,TFCond_RocketPack);
			}
		}
	}
	return Plugin_Continue;
}

public Action updateGlow(Handle timer, int client)
{ //radar glow
	if(IsValidEdict(client))
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
	return Plugin_Continue;
}

public void updateHeads(int client)
{
	int heads = GetEntProp(client, Prop_Send, "m_iDecapitations");
	if(TF2_IsPlayerInCondition(client,TFCond_SpawnOutline)) heads = 0;
	int melee = TF2Util_GetPlayerLoadoutEntity(client, TFWeaponSlot_Melee, true);
	if(heads>4)
		heads = 4; //cap heads 
	float healthPenalty = heads*-15.0;
	TF2Attrib_SetByDefIndex(melee,125,healthPenalty-15.0);
	if(TF2_IsPlayerInCondition(client,TFCond_SpawnOutline)) TF2Util_TakeHealth(client,200.0);
}

public void updateShield(DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	float meter = pack.ReadFloat();
	
	SetEntPropFloat(client, Prop_Send,"m_flChargeMeter",meter);
}

public Action updateRing(Handle timer, DataPack pack)
{
	pack.Reset();
	int attacker = pack.ReadCell();
	int victim = pack.ReadCell();
	int primary = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Primary, true);

	g_condFlags[victim] |= TF_CONDFLAG_HEATER;
	float targetPos[3], victimPos[3];
	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
	for (int i = 1 ; i <= MaxClients ; i++)
	{
		bool hit = false;
		if(IsValidClient(i,false) && i!=victim && !(g_condFlags[i] & TF_CONDFLAG_HEATER))
		{
			if(IsPlayerAlive(i) && GetClientTeam(attacker)!=GetClientTeam(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", targetPos);
				float dist = GetVectorDistance(victimPos,targetPos);
				if(victim != i && dist<=190 && TF2_GetClientTeam(i) != TF2_GetClientTeam(attacker))
				{
					Handle hndl = TR_TraceRayFilterEx(targetPos, victimPos, MASK_SOLID, RayType_EndPoint, TraceFilter, i);
					if(TR_DidHit() == false)
						hit = true;
					else
					{
						int vic = TR_GetEntityIndex(hndl);
						char[] class = new char[64];
						if(IsValidEdict(vic)) GetEdictClassname(vic, class, 64);
						
						if(StrEqual(class,"func_respawnroomvisualizer") || !IsValidEdict(vic))
							hit = true;
					}
					if(hit)
					{
						SDKHooks_TakeDamage(i, attacker, attacker, 5.0, DMG_IGNITE | DMG_BURN, primary, NULL_VECTOR, targetPos, false);
						if(TF2_GetPlayerClass(i) != TFClass_Pyro)
						{
							TF2Util_SetPlayerBurnDuration(i,4.0);
							TF2_AddCondition(i,TFCond_HealingDebuff,4.0);
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public void chocolateTick(int iClient)
{
	TF2Util_TakeHealth(iClient,1.0);
}

public Action chocolateHeal(Handle timer, int iClient)
{
	if(IsValidClient(iClient))
	{
		if(IsPlayerAlive(iClient) && g_condFlags[iClient] & TF_CONDFLAG_EATING)
		{
			int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
			int secondaryIndex = -1;
			if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
			if((secondaryIndex == 159 || secondaryIndex == 433)) //add dalokohs healing
				TF2Util_TakeHealth(iClient,25.0);
			if(secondaryIndex == 311)
				TF2Util_TakeHealth(iClient,50.0); //add steak healing
		}
	}
	return Plugin_Continue;
}

public void ExtinguishEnemy(int client)
{
	TF2_RemoveCondition(client,TFCond_OnFire);
	TF2_RemoveCondition(client,TFCond_BurningPyro);
}

stock int CreateParticle(int ent, char[] particleType, float time,float angleX=0.0,float angleY=0.0,float Xoffset=0.0,float Yoffset=0.0,float Zoffset=0.0,float size=1.0,bool update=true,bool parent=true,bool attach=false,float angleZ=0.0,int owner=-1)
{
	int particle = CreateEntityByName("info_particle_system");

	char[] name = new char[64];

	if (IsValidEdict(particle))
	{
		g_particles[particle] = 1;

		float position[3];
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", position);
		position[0] += Xoffset;
		position[1] += Yoffset;
		position[2] += Zoffset;
		float angles[3];
		angles[0] = angleX;
		angles[1] = angleY;
		angles[2] = angleZ;
		TeleportEntity(particle, position, angles, NULL_VECTOR);
		GetEntPropString(ent, Prop_Data, "m_iName", name, 64);
		DispatchKeyValue(ent, "targetname", name);
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(ent, "start_active", "0");
		DispatchKeyValue(particle, "parentname", name);
		DispatchKeyValue(particle, "effect_name", particleType);
		if(size!=-1.0) SetEntPropFloat(ent, Prop_Data, "m_flRadius",size);

		if(ent!=0)
		{
			if(parent)
			{
				SetVariantString(name);
				AcceptEntityInput(particle, "SetParent", particle, particle, 0);

			}
			else
			{
				SetVariantString("!activator");
				AcceptEntityInput(particle, "SetParent", ent, particle, 0);
			}
			if(attach)
			{
				SetVariantString("head");
				AcceptEntityInput(particle, "SetParentAttachment", particle, particle, 0);
			}
		}

		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "Start");

		if(owner!=-1)
			SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", owner);
		
		if(update)
		{
			DataPack pack = new DataPack();
			pack.Reset();
			pack.WriteCell(particle);
			pack.WriteCell(ent);
			pack.WriteFloat(time);
			pack.WriteFloat(Xoffset);
			pack.WriteFloat(Yoffset);
			pack.WriteFloat(Zoffset);
			CreateTimer(0.015, UpdateParticle, pack, TIMER_REPEAT);
		}
		else
			CreateTimer(time, DeleteParticle, particle);
	}
	return particle;
}

public Action DeleteParticle(Handle timer, int particle)
{
	char[] classN = new char[64];
	if (IsValidEdict(particle))
	{
		GetEdictClassname(particle, classN, 64);
		if (StrEqual(classN, "info_particle_system", false))
		{
			g_particles[particle] = 0;
			AcceptEntityInput(particle, "Stop");
			AcceptEntityInput(particle, "Kill");
			RemoveEdict(particle);
		}
	}
	return Plugin_Continue;
}

public Action UpdateParticle(Handle timer, DataPack pack)
{
	pack.Reset();
	int particle = pack.ReadCell();
	int parent = pack.ReadCell();
	float time = pack.ReadFloat();
	float Xoffset = pack.ReadFloat();
	float Yoffset = pack.ReadFloat();
	float Zoffset = pack.ReadFloat();
	static float timePassed[MAXPLAYERS+1];

	if(IsValidEdict(particle))
	{
		char[] classN = new char[64];
		GetEdictClassname(particle, classN, 64);
		if (StrEqual(classN, "info_particle_system", false))
		{
			if(IsValidClient(parent))
			{
				if(timePassed[parent] >= time)
				{
					timePassed[parent] = 0.0;
					RemoveEdict(particle);
					return Plugin_Stop;
				}
				else
				{
					float position[3];
					GetEntPropVector(parent, Prop_Send, "m_vecOrigin", position);
					position[0] += Xoffset;
					position[1] += Yoffset;
					position[2] += Zoffset;
					TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);
				}
				timePassed[parent] += 0.015;
			}
			else if(parent==0) //lingering flamethrower flames
			{
				if(g_flameHit[particle] >= time)
				{
					g_flameHit[particle] = 0.0;
					RemoveEdict(particle);
					return Plugin_Stop;
				}
				else
				{
					float position[3];
					GetEntPropVector(particle, Prop_Send, "m_vecOrigin", position);
					int owner = GetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity");
					if(IsValidClient(owner,false))
					{
						int interval = RoundFloat(g_flameHit[particle]*1000);
						if(interval%75 == 0)
						{
							for(int idx = 1; idx <= MaxClients; idx++)
							{
								if(IsValidClient(idx,false))
								{
									float targetpos[3],flamepos[3];
									GetEntPropVector(idx, Prop_Send, "m_vecOrigin", targetpos);
									if(GetClientTeam(owner) != GetClientTeam(idx) && IsPlayerAlive(idx))
									{
										GetEntPropVector(particle, Prop_Send, "m_vecOrigin", flamepos);
										float distance = GetVectorDistance(flamepos,targetpos);
										float damage = 3.5*((time-g_flameHit[particle])/time) + 3.5;
										bool hit = false;

										if(distance<35.0)
										{
											Handle hndl = TR_TraceRayFilterEx(flamepos, targetpos, MASK_SOLID, RayType_EndPoint, TraceFilter, idx);
											if(TR_DidHit() == false)
												hit = true;
											else
											{
												int victim = TR_GetEntityIndex(hndl);
												char[] class = new char[64];
												if(IsValidEdict(victim)) GetEdictClassname(victim, class, 64);
												
												if(StrEqual(class,"func_respawnroomvisualizer") || !IsValidEdict(victim))
													hit = true;
											}
											if(hit && g_flameDamage[idx]>=0)
											{
												if(damage > g_flameDamage[idx])
												{
													g_flameAttacker[idx] = owner;
													g_flameDamage[idx] = damage;
												}
											}
										}
									}
								}
							}
						}
					}
					else
						g_flameHit[particle] = time;
				}
				g_flameHit[particle] += 0.075;
			}
			else if(!IsValidEdict(parent))
			{
				CreateTimer(0.015, DeleteParticle, particle);
			}
		}
		else
			return Plugin_Stop;
	}
	else
		return Plugin_Stop;
	
	return Plugin_Continue;
}

public Action FireDebuff(Handle timer, DataPack pack)
{
	pack.Reset();
	int victim = pack.ReadCell();
	int provider = pack.ReadCell();
	float time = pack.ReadFloat();

	TF2_AddCondition(victim,TFCond_HealingDebuff,time,provider);
	return Plugin_Continue;
}

public void DeadRingCheck(int iClient)
{
	SetEntPropFloat(iClient, Prop_Send,"m_flCloakMeter",100.0);
}

public void MmmphCheck(int iClient)
{
	if(TF2_IsPlayerInCondition(iClient,TFCond_CritMmmph))
	{
		TF2_RemoveCondition(iClient,TFCond_UberchargedCanteen);
		if(TF2Util_GetPlayerConditionProvider(iClient,TFCond_MegaHeal) == -1)
			TF2_RemoveCondition(iClient,TFCond_MegaHeal);
	}
}

public Action MelterView(Handle timer, int view)
{
	if(GetEntProp(view, Prop_Send, "m_nSequence") == 24 || GetEntProp(view, Prop_Send, "m_nSequence") == 25)
	{
		SetEntProp(view, Prop_Send, "m_nSequence",18);
		SetEntPropFloat(view, Prop_Send, "m_flPlaybackRate",1.125);
	}
	return Plugin_Continue;
}

public Action ResetBlast(Handle timer, int iClient)
{
	if(IsValidClient(iClient))
	{
		int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
		int secondaryIndex = -1;
		if(secondary != -1) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
		if(secondaryIndex==444) //mantreads resistance
		{
			int clientFlags = GetEntityFlags(iClient);
			float vel[3];
			GetEntPropVector(iClient, Prop_Data, "m_vecVelocity",vel);
			if((clientFlags & FL_ONGROUND) && vel[2]==0.0)
			{
				g_condFlags[iClient] &= ~TF_CONDFLAG_DIVE;
			}
		}
	}
	return Plugin_Continue;
}

public Action OnWeaponEquip(int iClient, int weapon)
{
	// int weaponIndex = -1;
	// if(weapon > 0) weaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	if(IsValidClient(iClient))
	{
		char class[64];
		GetEntityClassname(weapon,class,64);

		if(TF2_GetPlayerClass(iClient) == TFClass_Sniper)
		{
			if(StrContains(class,"sniperrifle") > -1)
			{
				TF2Attrib_SetFromStringValue(weapon,"set viewmodel arms","models/weapons/custommodels/c_sniper_arms.mdl");
			}
		}
	}
	return Plugin_Continue;
}

public void Phlog_SecondaryAttack(int entity,int client,float angles[3],float vel,int clientFlags,int buttons)
{
	int idx, itemindex;
	char class[64];
	float player_pos[3], target_pos[3], angles1[3], angles2[3], vector[3];
	float distance, limit, charge;
	
	GetEntityClassname(entity, class, sizeof(class));
	itemindex = GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
	
	if (client > 0)
	{
		if (StrEqual(class, "tf_weapon_flamethrower") && itemindex == 594)
		{
			TF2Attrib_SetByDefIndex(entity,350,0.0); //ragdolls become ash
			TF2Attrib_SetByDefIndex(entity,436,1.0); //ragdolls plasma effect
			charge = GetEntPropFloat(client, Prop_Send, "m_flRageMeter");
			int primaryAmmo = GetEntProp(entity, Prop_Send, "m_iPrimaryAmmoType");
			int ammo = GetEntProp(client, Prop_Data, "m_iAmmo", _, primaryAmmo);
			int cost = 20;
			int maxDelete = RoundToFloor((ammo-cost)/5.0); //limit deletes based on ammo
			
			if (ammo >= cost)
			{
				int view = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
				if(!IsValidEdict(view))
					return;
				SetEntProp(view, Prop_Send, "m_nSequence",13);
				SetEntPropFloat(view, Prop_Send, "m_flPlaybackRate",1.0);
				GetClientEyePosition(client, player_pos);
				GetClientEyeAngles(client, angles1);
				float angle = angles[1]*0.01745329;
				float factor = 2.5;
				float Xoffset = factor*((80-FloatAbs(angles[0])) * Cosine(angle));
				float Yoffset = factor*((80-FloatAbs(angles[0])) * Sine(angle));
				float Zoffset = 50.0 - angles[0];
				EmitAmbientSound("weapons/barret_arm_shot.wav",player_pos,client);
				CreateParticle(client,"arm_muzzleflash_flare",1.0,_,_,Xoffset,Yoffset,Zoffset,20.0);
				TFTeam clientTeam = TF2_GetClientTeam(client);
				if(clientTeam == TFTeam_Red)
				{
					CreateParticle(client,"drg_cow_explosion_sparkles",1.0,_,_,Xoffset,Yoffset,Zoffset,20.0);
					CreateParticle(client,"drg_cow_explosion_flyingembers",1.0,_,_,Xoffset,Yoffset,Zoffset,20.0);
					CreateParticle(client,"drg_cow_explosion_flashup",1.0,_,_,Xoffset,Yoffset,Zoffset,20.0);
				}
				else if(clientTeam == TFTeam_Blue)
				{
					CreateParticle(client,"drg_cow_explosion_sparkles_blue",1.0,_,_,Xoffset,Yoffset,Zoffset,20.0);
					CreateParticle(client,"drg_cow_explosion_flyingembers_blue",1.0,_,_,Xoffset,Yoffset,Zoffset,20.0);
					CreateParticle(client,"drg_cow_explosion_flashup_blue",1.0,_,_,Xoffset,Yoffset,Zoffset,20.0);
				}
				int extraCharge = 0, lossCharge = 0, healing = 0;
				
				for(idx = 1; idx < 2048; idx++)
				{
					if(IsValidEdict(idx))
					{
						GetEntityClassname(idx, class, sizeof(class));
						if((idx <= MaxClients) || (StrContains(class, "tf_projectile_") != -1  &&
						!StrEqual(class, "tf_projectile_energy_ring") && !StrEqual(class, "tf_projectile_mechanicalarmorb")))
						{
							GetEntPropVector(idx, Prop_Send, "m_vecOrigin", target_pos);
								
							if (idx <= MaxClients)
								target_pos[2] += 41.0;

							distance = GetVectorDistance(player_pos, target_pos);
							
							if (distance <= 300.0)
							{
								MakeVectorFromPoints(player_pos, target_pos, vector);
								
								GetVectorAngles(vector, angles2);
								
								angles2[1] = angles2[1] > 180.0 ? (angles2[1] - 360.0) : angles2[1];
								
								angles1[0] = 0.0;
								angles2[0] = 0.0;
								
								if (idx <= MaxClients)
									limit = ValveRemapVal(distance, 0.0, 150.0, 70.0, 25.0);
								else
									limit = ValveRemapVal(distance, 0.0, 200.0, 80.0, 40.0);
								
								if(CalcViewsOffset(angles1, angles2) < limit)
								{
									TR_TraceRayFilter(player_pos, target_pos, MASK_SOLID, RayType_EndPoint, TraceFilter, idx);
									
									if(TR_DidHit() == false)
									{
										if(idx <= MaxClients)
										{
											if(IsValidClient(idx))
											{
												if(IsPlayerAlive(idx))
												{
													if(GetClientTeam(idx)!=GetClientTeam(client) && !TF2_IsPlayerInCondition(idx,TFCond_Ubercharged) && !TF2_IsPlayerInCondition(idx,TFCond_UberchargeFading))
													{
														float damage = 20 + 20 * g_temperature[idx];
														int damagetype = DMG_SHOCK;
														if(isKritzed(client)) damagetype |= DMG_CRIT;
														SDKHooks_TakeDamage(idx, entity, client, damage, damagetype, entity, NULL_VECTOR, target_pos, false);
														charge += damage/300;
														extraCharge++;
													}
													else{
														if(TF2_IsPlayerInCondition(idx,TFCond_OnFire)||TF2_IsPlayerInCondition(idx,TFCond_BurningPyro))
														{
															TF2_RemoveCondition(idx,TFCond_OnFire);
															TF2_IsPlayerInCondition(idx,TFCond_BurningPyro);
															healing++;
														}
													}
												}
											}
										}
										else
										{
											int team = GetEntProp(idx, Prop_Send, "m_iTeamNum");
											if(team != GetClientTeam(client) && lossCharge<maxDelete)
											{
												CreateParticle(idx,"arm_muzzleflash_electro",1.0);
												RemoveEntity(idx);
												lossCharge++;
											}
										}
									}
								}
							}
						}
					}
				}
				if(extraCharge!=0)
				{
					SetEntPropFloat(client, Prop_Send, "m_flRageMeter", charge);
				}
				if(healing>0) TF2Util_TakeHealth(client,20.0*healing);
				SetEntProp(client, Prop_Data, "m_iAmmo", ammo-cost-(5*lossCharge), _, primaryAmmo);
			}
			else
			{
				float angle = angles[1]*0.01745329;
				float Xoffset = (80-FloatAbs(angles[0])) * Cosine(angle);
				float Yoffset = (80-FloatAbs(angles[0])) * Sine(angle);
				float Zoffset = 50.0 - angles[0];
				EmitSoundToClient(client,"weapons/barret_arm_fizzle.wav");
				CreateParticle(client,"dxhr_sniper_fizzle",1.0,_,_,Xoffset,Yoffset,Zoffset);
			}
			
		}
	}
}

public Action CaberTauntkill(Handle timer, int client)
{
	int idx, itemindex = -1, closest = -1;
	char class[64];
	float player_pos[3], target_pos[3], impact_pos[3], angles1[3], angles2[3], vector[3];
	float distance,closestDistance = 0.0;

	GetClientEyePosition(client, player_pos);
	GetClientEyeAngles(client, angles1);
	int melee = TF2Util_GetPlayerLoadoutEntity(client, TFWeaponSlot_Melee, true);
	if(melee >= 0) itemindex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
	GetClientWeapon(client,class,64);
	if(itemindex == 307 && (StrEqual("tf_weapon_stickbomb",class) || StrEqual("Stick Bomb",class)) && TF2_IsPlayerInCondition(client,TFCond_Taunting))
	{
		for(idx = 1; idx < MaxClients; idx++)
		{
			if(IsValidClient(idx,false))
			{
				if(IsPlayerAlive(idx) && GetClientTeam(idx) != GetClientTeam(client))
				{
					GetEntPropVector(idx, Prop_Send, "m_vecOrigin", target_pos);
					distance = GetVectorDistance(player_pos, target_pos);
					if(distance < 130.0)
					{
						MakeVectorFromPoints(player_pos, target_pos, vector);
						GetVectorAngles(vector, angles2);
						angles2[1] = angles2[1] > 180.0 ? (angles2[1] - 360.0) : angles2[1];
						angles1[0] = 0.0;
						angles2[0] = 0.0;
						
						float limit = ValveRemapVal(distance, 0.0, 200.0, 80.0, 40.0);
						
						if(CalcViewsOffset(angles1, angles2) < limit)
						{
							TR_TraceRayFilter(player_pos, target_pos, MASK_SOLID, RayType_EndPoint, TraceFilter, idx);
							
							if (TR_DidHit() == false)
							{
								if(closestDistance > distance || closestDistance == 0.0)
								{
									closest = idx; closestDistance = distance;
									impact_pos[0] = (player_pos[0]+target_pos[0])/2;
									impact_pos[1] = (player_pos[1]+target_pos[1])/2;
									impact_pos[2] = (player_pos[2]+target_pos[2])/2;
								}
							}
						}
					}
				}
			}
		}
		if(closest != -1)
		{
			int det = GetEntProp(melee, Prop_Send, "m_iDetonated");
			if(det == 0)
			{
				float blastVec[3]; blastVec[2]=100.0;
				SetEntProp(melee, Prop_Send, "m_iDetonated",1);
				SetEntProp(melee, Prop_Send, "m_bBroken",1);
				CreateParticle(client,"ExplosionCore_MidAir",5.0,_,_,_,_,_,_,false);
				EmitAmbientSound("weapons/explode2.wav",player_pos,client);
				SDKHooks_TakeDamage(client, melee, client, 100.0, DMG_BLAST, melee, blastVec, impact_pos, false);
				SDKHooks_TakeDamage(closest, melee, client, 500.0, DMG_BLAST, melee, blastVec, impact_pos, false);
				for(idx = 1; idx < MaxClients; idx++)
				{
					if(IsValidClient(idx,false) && idx != closest)
					{
						if(IsPlayerAlive(idx) && GetClientTeam(idx) != GetClientTeam(client))
						{
							GetEntPropVector(idx, Prop_Send, "m_vecOrigin", target_pos);
							distance = GetVectorDistance(impact_pos, target_pos);
							if(distance < 126.0)
								SDKHooks_TakeDamage(idx, melee, client, 100.0+50.0*((125-distance)/125.0), DMG_BLAST, melee, blastVec, impact_pos, false);
						}
					}
				}
			}
			else
			{
				EmitAmbientSound("weapons/bottle_impact_hit_flesh1.wav",player_pos,client);
				SDKHooks_TakeDamage(closest, melee, client, 55.0, DMG_CLUB, melee, NULL_VECTOR, impact_pos, false);
			}
		}
	}
	return Plugin_Continue;
}

public Action SMGTauntkill(Handle timer, int client)
{
	int idx, closest = -1;
	char class[64];
	float player_pos[3], target_pos[3], impact_pos[3], angles1[3], angles2[3], vector[3];
	float distance,closestDistance = 0.0;

	GetClientEyePosition(client, player_pos);
	GetClientEyeAngles(client, angles1);
	int secondary = TF2Util_GetPlayerLoadoutEntity(client, TFWeaponSlot_Secondary, true);

	GetClientWeapon(client,class,64);
	if((StrEqual(class,"tf_weapon_charged_smg") || StrEqual(class,"tf_weapon_smg") || StrEqual(class,"SMG") || StrEqual(class,"Charged SMG")) && TF2_IsPlayerInCondition(client,TFCond_Taunting))
	{
		for(idx = 1; idx < MaxClients; idx++)
		{
			if(IsValidClient(idx,false))
			{
				if(IsPlayerAlive(idx) && GetClientTeam(idx) != GetClientTeam(client))
				{
					GetEntPropVector(idx, Prop_Send, "m_vecOrigin", target_pos);
					distance = GetVectorDistance(player_pos, target_pos);
					if(distance < 102)
					{
						MakeVectorFromPoints(player_pos, target_pos, vector);
						GetVectorAngles(vector, angles2);
						angles2[1] = angles2[1] > 180.0 ? (angles2[1] - 360.0) : angles2[1];
						angles1[0] = 0.0;
						angles2[0] = 0.0;
						
						float limit = ValveRemapVal(distance, 0.0, 200.0, 80.0, 40.0);
						
						if(CalcViewsOffset(angles1, angles2) < limit)
						{
							TR_TraceRayFilter(player_pos, target_pos, MASK_SOLID, RayType_EndPoint, TraceFilter, idx);
							
							if(TR_DidHit() == false)
							{
								if(closestDistance > distance || closestDistance == 0.0)
								{
									closest = idx; closestDistance = distance;
									impact_pos[0] = (player_pos[0]+target_pos[0])/2;
									impact_pos[1] = (player_pos[1]+target_pos[1])/2;
									impact_pos[2] = (player_pos[2]+target_pos[2])/2;
								}
							}
						}
					}
				}
			}
		}
		if(closest != -1)
		{
			SDKHooks_TakeDamage(closest, secondary, client, 65.0, DMG_CLUB, secondary, NULL_VECTOR, impact_pos, false);
		}
	}
	return Plugin_Continue;
}

public Action TeleportResup(Handle timer, int iClient)
{
	if(IsValidClient(iClient))
	{
		if(IsPlayerAlive(iClient) && g_condFlags[iClient]&TF_CONDFLAG_INSPAWN)
		{
			TF2Util_TakeHealth(iClient,150.0);

			int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
			int primaryIndex = -1;
			if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
			int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
			int secondaryIndex = -1;
			if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");

			int clip = 0;
			int reserve = 32;
			switch(primaryIndex)
			{
				//frontier
				case 141,1004: clip = 3;
				//rescue
				case 997:
				{
					clip = 4;
					reserve = 16;
				}
				//panic
				case 1153: clip = 4;
				//pomson
				case 588: SetEntPropFloat(primary, Prop_Send, "m_flEnergy", 20.0);
				//widowmaker
				case 527: clip = 0;
				//other shottguns
				default: clip = 6;
			}
			if(clip>0)
			{
				int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
				SetEntData(primary, iAmmoTable, clip, 4, true);
				SetEntProp(primary, Prop_Send, "m_iClip1",clip);
				int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
				SetEntProp(iClient, Prop_Data, "m_iAmmo", reserve , _, primaryAmmo);
			}
			clip = 12;
			reserve = 200;
			switch(secondaryIndex)
			{
				//wrangler, short circuit
				case 140,528,1086,30668:
				{
					clip = 0;
				}
			}
			if(clip>0)
			{
				int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
				SetEntData(secondary, iAmmoTable, clip, 4, true);
				SetEntProp(secondary, Prop_Send, "m_iClip1", clip);
				int secondaryAmmo = GetEntProp(secondary, Prop_Send, "m_iPrimaryAmmoType");
				SetEntProp(iClient, Prop_Data, "m_iAmmo", reserve , _, secondaryAmmo);
			}
			SetEntData(iClient, FindDataMapInfo(iClient, "m_iAmmo") + (3 * 4), 200, 4);
		}
	}
	return Plugin_Continue;					
}

public void NeonExplosion(DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	int victim = pack.ReadCell();
	float player_pos[3], target_pos[3], force_vec[3], force_client[3];
	float distance = 0.0;

	int melee = TF2Util_GetPlayerLoadoutEntity(client, TFWeaponSlot_Melee, true);
	char class[64];
	GetEntityClassname(victim,class,64);
	if(StrEqual(class, "tank_boss"))
		GetClientEyePosition(client,player_pos);
	else
		GetClientEyePosition(victim,player_pos);
	
	for(int idx = 1; idx < MaxClients; idx++)
	{
		if(IsValidClient(idx,false) && idx != victim)
		{
			if(IsPlayerAlive(idx) && (GetClientTeam(idx) != GetClientTeam(client) || idx == client))
			{
				GetClientEyePosition(idx,target_pos);
				distance = GetVectorDistance(player_pos, target_pos);
				if(distance < 126)
				{
					float damage = 55.0 + 25.0*((110-distance)/110);
					int damagetype = DMG_BLAST;
					if(idx==client)
					{
						force_client[2] = -200.0;
						TeleportEntity(idx,_,_,force_client);
						damage = 75.0;
					}
					else if (TF2_IsPlayerInCondition(idx,TFCond_Gas) || TF2_IsPlayerInCondition(idx,TFCond_Milked) || TF2_IsPlayerInCondition(idx,TFCond_Jarated))
						damagetype |= DMG_CRIT;
					SDKHooks_TakeDamage(idx, client, client, damage, damagetype, melee, force_vec, player_pos, false);
				}
			}
		}
	}
}

public Action SpeedThruster(Handle timer, int iClient)
{
	if(IsValidClient(iClient,false))
	{
		int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
		int secondaryIndex = -1;
		if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
		if(secondaryIndex==1179)
		{
			SetEntPropFloat(secondary, Prop_Send, "m_flNextPrimaryAttack",GetGameTime()-2.0);
			SetEntProp(secondary, Prop_Send, "m_bEnabled", 1); //overwrite thruster launch time
			SetEntPropFloat(secondary, Prop_Send, "m_flToggleEndTime", -1.0);
			int view = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
			if (!IsValidEdict(view)) return Plugin_Continue;
			SetEntProp(view, Prop_Send, "m_nSequence",40);
		}
	}
	return Plugin_Continue;
}

public void CannonKnockback(int victim)
{
	//loose cannon undo stun and strafelock
	TF2_RemoveCondition(victim,TFCond_KnockedIntoAir);
	TF2_RemoveCondition(victim,TFCond_AirCurrent);
	TF2_RemoveCondition(victim,TFCond_Dazed);
}

public void DryFireSniper(int iClient)
{
	if(IsValidClient(iClient))
	{
		int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
		int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
		SetEntProp(iClient, Prop_Data, "m_iAmmo", 0, _, primaryAmmo);
	}
}

public void ResetClassic(int iClient)
{
	if(IsValidClient(iClient))
	{
		int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
		int flags = GetEntityFlags(iClient);
		SetEntityFlags(iClient,flags & ~FL_ONGROUND);
		TF2Attrib_SetByDefIndex(primary,636,1.0); //sniper crit no scope
	}
}

public void BleedBuff(DataPack pack)
{
	pack.Reset();
	int victim = pack.ReadCell();
	int attacker = pack.ReadCell();
	int weapon = pack.ReadCell();
	int damage = pack.ReadCell();
	float duration = pack.ReadFloat();
	TF2Util_MakePlayerBleed(victim,attacker,duration,weapon,damage);
}

public void IronFire(int iClient)
{
	if(IsValidClient(iClient))
	{
		int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
		// SetEntProp(primary, Prop_Send, "m_iWeaponState", 0);
		float time = GetGameTime();
		SetEntPropFloat(primary, Prop_Send, "m_flNextPrimaryAttack",time+1.05);
		SetEntPropFloat(primary, Prop_Send, "m_flNextSecondaryAttack",time+1.05);
		SetEntPropFloat(primary, Prop_Send, "m_flTimeWeaponIdle",GetGameTime());
		g_condFlags[iClient] &= ~TF_CONDFLAG_HEATER;
		g_condFlags[iClient] &= ~TF_CONDFLAG_FAKE;
	}
}

public void LeapCharge(DataPack pack)
{
	pack.Reset();
	int iClient = pack.ReadCell();
	float charge = pack.ReadFloat();
	SetEntPropFloat(iClient, Prop_Send,"m_flChargeMeter",charge);
}

public void Switch2nd(int iClient)
{
	ClientCommand(iClient,"slot2");
}
public void Switch3rd(int iClient)
{
	ClientCommand(iClient,"slot3");
}

float ValveRemapVal(float val, float a, float b, float c, float d)
{
	// https://github.com/ValveSoftware/source-sdk-2013/blob/master/sp/src/public/mathlib/mathlib.h#L648
	float tmp;
	if (a == b) return (val >= b ? d : c);
	tmp = ((val - a) / (b - a));
	if (tmp < 0.0) tmp = 0.0;
	if (tmp > 1.0) tmp = 1.0;
	return (c + (d - c) * tmp);
}

float CalcViewsOffset(float angle1[3], float angle2[3])
{
	float v1, v2;
	v1 = FloatAbs(angle1[0] - angle2[0]);
	v2 = FloatAbs(angle1[1] - angle2[1]);
	v2 = v2 > 180.0 ? (v2 - 360.0) : v2;
	return SquareRoot(Pow(v1, 2.0) + Pow(v2, 2.0));
}

Action GasTouch(int gas, int other)
{
	if(IsValidClient(other))
	{
		bool decreased = false;
		int owner = GetEntPropEnt(gas, Prop_Send, "m_hOwnerEntity");
		int gasTeam = GetClientTeam(owner);
		int clientTeam = GetClientTeam(other);
		if(gasTeam == clientTeam)
		{
			float burning = TF2Util_GetPlayerBurnDuration(other);
			if(burning > 0)
			{
				TF2Util_SetPlayerBurnDuration(other,burning-1.0/66);
				decreased = true;
			}
			float pissed = TF2Util_GetPlayerConditionDuration(other,TFCond_Jarated);
			if(pissed > 0)
			{
				TF2Util_SetPlayerConditionDuration(other,TFCond_Jarated,pissed-1.0/66);
				decreased = true;
			}
			float milked = TF2Util_GetPlayerConditionDuration(other,TFCond_Milked);
			if(milked > 0)
			{
				TF2Util_SetPlayerConditionDuration(other,TFCond_Milked,milked-1.0/66);
				decreased = true;
			}
			float gassed = TF2Util_GetPlayerConditionDuration(other,TFCond_Gas);
			if(gassed > 0)
			{
				TF2Util_SetPlayerConditionDuration(other,TFCond_Gas,gassed-1.0/66);
				decreased = true;
			}
			if(decreased) //if ally is debuff cleansed, recharge 
			{
				float gasmeter = GetEntPropFloat(owner, Prop_Send, "m_flItemChargeMeter", 1) + 1.0/66;
				SetEntPropFloat(owner, Prop_Send, "m_flItemChargeMeter", gasmeter, 1);
			}
		}
	}
	return Plugin_Continue;
}

public Action gasExplode(Handle timer, DataPack pack)
{
	pack.Reset();
	int victim = pack.ReadCell();
	int gasser = pack.ReadCell();
	float meter = pack.ReadFloat();
	// float damagePosition[3];

	if(IsPlayerAlive(victim))
	{
		// GetEntPropVector(victim, Prop_Send, "m_vecOrigin", damagePosition);
		// int secondary = TF2Util_GetPlayerLoadoutEntity(gasser, TFWeaponSlot_Secondary, true);
		// SDKHooks_TakeDamage(victim, gasser, gasser, 20.0, DMG_SLASH, secondary, NULL_VECTOR, damagePosition);
	}
	// CreateParticle(victim,"dragons_fury_effect",2.0);
	SetEntPropFloat(gasser, Prop_Send, "m_flItemChargeMeter", meter, 1);
	return Plugin_Continue;
}

public void VolcanoBurst(DataPack pack)
{
	pack.Reset();
	int victim = pack.ReadCell();
	int attacker = pack.ReadCell();

	if(IsPlayerAlive(victim))
	{
		float targetPos[3];
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", targetPos);
		int burnerMelee = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Melee, true);

		SDKHooks_TakeDamage(victim, attacker, attacker, 18.0, DMG_IGNITE | DMG_BURN, burnerMelee, NULL_VECTOR, targetPos, false);
		g_condFlags[victim] |= TF_CONDFLAG_VOLCANO;
		if(TF2Util_GetPlayerBurnDuration(victim)<8)
		{
			if(TF2_GetPlayerClass(victim) == TFClass_Pyro)
				TF2_AddCondition(victim,TFCond_BurningPyro,8.0);
			else 
				TF2_AddCondition(victim,TFCond_OnFire,8.0);
			TF2Util_SetPlayerBurnDuration(victim,8.0);
		}
	}
}

public void SetDisguise(int attacker) //set enforcer disguise
{
	if(IsValidClient(attacker))
	{
		int weapon = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Secondary, true);
		int secondaryIndex = -1;
		if(weapon>0) secondaryIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		if(secondaryIndex==460)
		{
			float disguise = g_meterSec[attacker];
			int target = RoundToFloor(disguise - RoundToFloor(disguise/100)*100);
			int class = RoundToFloor((disguise - RoundToFloor(disguise/1000)*1000 - target)/100);
			int team = RoundToFloor((disguise - class - target)/1000);
			if(!IsValidClient(target,false))
			{
				for(int i=1;i<MaxClients;++i)
				{
					if(IsValidClient(target,false))
					{
						target = i;
						team = GetClientTeam(i);
						if(GetEntProp(attacker, Prop_Send, "m_iClass") == class)
							break;
					}
				}
			}
			TF2_DisguisePlayer(attacker,view_as<TFTeam>(team),view_as<TFClassType>(class),target);
		}
	}
}

Action ResetPressure(Handle timer, int user)
{
	if(IsValidClient(user))
	{
		int primary = TF2Util_GetPlayerLoadoutEntity(user, TFWeaponSlot_Primary, true);
		int primaryIndex = -1;
		if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");

		float pressure = GetEntPropFloat(user, Prop_Send, "m_flItemChargeMeter", 0);
		if(primaryIndex == 1178) pressure = g_meterPri[user];
		if(pressure < 100-PRESSURE_COST)
		{
			if(primaryIndex == 1178) g_meterPri[user] = pressure+PRESSURE_COST;
			else SetEntPropFloat(user, Prop_Send, "m_flItemChargeMeter", pressure+PRESSURE_COST, 0);
		}
		else 
		{
			if(primaryIndex == 1178) g_meterPri[user] = 100.0;
			else SetEntPropFloat(user, Prop_Send, "m_flItemChargeMeter", 100.0, 0);
		}
	}
	return Plugin_Continue;
}

Action FlagThink(int flag) //flag logic, detect nearby teammates when dropped and emit ring
{
	char[] mapName = new char[64];
	GetCurrentMap(mapName,64);
	if(StrContains(mapName, "pd_" , false) == -1)
	{
		int status = GetEntProp(flag, Prop_Send, "m_nFlagStatus"); // 0=home, 1=pickup, 2=dropped
		switch(status)
		{
			case 2:
			{
				int helpers=0;
				for(int i=1; i<MaxClients; ++i) //find teammates nearby
				{
					if(IsValidClient(i))
					{
						int flagTeam = GetEntProp(flag, Prop_Send, "m_iTeamNum");
						int clientTeam = GetClientTeam(i);
						if((flagTeam == clientTeam || flagTeam == 0 || flagTeam == 1) && IsPlayerAlive(i))
						{
							if(getPlayerDistance(flag,i)<240)
							{
								int primary = TF2Util_GetPlayerLoadoutEntity(i, TFWeaponSlot_Primary, true);
								int primaryIndex = -1;
								if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
								int secondary = TF2Util_GetPlayerLoadoutEntity(i, TFWeaponSlot_Secondary, true);
								int secondaryIndex = -1;
								if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");

								if(!TF2_IsPlayerInCondition(i,TFCond_Ubercharged) && !TF2_IsPlayerInCondition(i,TFCond_MegaHeal) && !TF2_IsPlayerInCondition(i,TFCond_UberBlastResist) 
									&& !TF2_IsPlayerInCondition(i,TFCond_UberBulletResist) && !TF2_IsPlayerInCondition(i,TFCond_UberFireResist)
									&& primaryIndex != 237 && secondaryIndex != 265 && secondaryIndex != 1179)
								{
									helpers++;
									SetHudTextParams(0.4, -0.2, 0.25, 255, 255, 255, 255);

									int melee = TF2Util_GetPlayerLoadoutEntity(i, TFWeaponSlot_Melee, true);
									int meleeIndex = -1;
									if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");

									if(TF2_GetPlayerClass(i)==TFClass_Scout || meleeIndex==154)
									{
										helpers++;
										ShowHudText(i,5,"REVERTING CAPTURE x2");
									}
									else
										ShowHudText(i,5,"REVERTING CAPTURE");
								}
							}
						}
					}
				}
				g_flagHelpers[flag] = helpers;
				if(helpers>0) //speed up return time if teammates are near
				{
					//m_bDisabled = 1;
					float time = GetEntPropFloat(flag, Prop_Send, "m_flResetTime");
					SetEntPropFloat(flag, Prop_Send, "m_flResetTime",time-0.255*helpers);
				}
				else
				{
					//m_bDisabled = 0;
				}
				
				//emit ring in intervals to show return area
				g_flagTime[flag] += 1;
				if(g_flagTime[flag]>3)
				{
					CreateParticle(flag,"bomibomicon_ring",1.0,_,_,_,_,_,_,false);
					g_flagTime[flag] = 0.0;
				}
			}
			case 0,1:
			{
				//reset everything while at home
				g_flagHelpers[flag] = 0;
				g_flagTime[flag] = 0.0;
				//m_bDisabled = 0;
			}
		}
	}
	return Plugin_Continue;
}

Action FlagTouch(int flag, int other)
{
	char[] mapName = new char[64];
	GetCurrentMap(mapName,64);
	if(StrContains(mapName, "pd_" , false) == -1)
	{
		int status = GetEntProp(flag, Prop_Send, "m_nFlagStatus"); // 0=home, 1=pickup, 2=dropped
		switch(status)
		{
			case 2:
			{
				if(IsValidClient(other))
				{
					int flagTeam = GetEntProp(flag, Prop_Send, "m_iTeamNum");
					int clientTeam = GetClientTeam(other);
					if(flagTeam != clientTeam && IsPlayerAlive(other))
					{
						//block capture if enemy is defending their flag
						if(g_flagHelpers[flag]>0)
							return Plugin_Stop;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

Action PointTouchStart(int entity, int other)
{
	if(IsValidClient(other,false))
	{
		g_condFlags[other] |= TF_CONDFLAG_CAPPING;
	}
	return Plugin_Continue;
}

Action PointTouchEnd(int entity, int other)
{
	if(IsValidClient(other,false))
	{
		g_condFlags[other] &= ~TF_CONDFLAG_CAPPING;
	}
	return Plugin_Continue;
}

void OnMoneySpawn(int money) //setup money
{
	if(IsValidEdict(money))
	{
		g_moneyFrames[money] = -10;
	}
}

Action FlameTouch(int flame, int other) //lingering flamethrower flames
{
	float time = GetGameTime();
	int owner = GetEntPropEnt(flame, Prop_Send, "m_hAttacker");
	if(IsValidClient(owner))
	{
		int primary = TF2Util_GetPlayerLoadoutEntity(owner, TFWeaponSlot_Primary, true);
		int primaryIndex = -1;
		if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
		//index to exclude degreaser 215

		char class[64];
		GetEntityClassname(other, class, sizeof(class));
		
		if(g_lastFire[owner]+0.06<time && primaryIndex!=215)
		{
			if(other==0 || StrEqual(class,"func_brush"))
			{
				float pos[3],ang[3],ownerPos[3];
				GetEntPropVector(flame, Prop_Send, "m_vecOrigin", pos);
				GetClientEyeAngles(owner, ang);
				
				Handle trace = TR_TraceRayFilterEx(pos, ang, MASK_SHOT, RayType_Infinite, TraceFilter, flame);
				if(!TR_DidHit(trace))
				{
					trace.Close();
					return Plugin_Continue;
				}
				TR_GetEndPosition(pos, trace);
				GetEntPropVector(owner, Prop_Send, "m_vecOrigin", ownerPos);
				if(GetVectorDistance(pos,ownerPos)>340)
				{
					trace.Close();
					return Plugin_Continue;
				}

				if(ang[0]<-70) pos[2]-=10; //adjust flame down when aiming up
				else pos[2]+=2.5;

				int team = GetEntProp(flame, Prop_Send, "m_iTeamNum");
				float fireTime = FIRE_TIME;
				if(g_bIsMVM) //mvm burn time
				{
					Address addr = TF2Attrib_GetByName(primary, "weapon burn time increased");
					if(addr != Address_Null)
					{
						float value = TF2Attrib_GetValue(addr);
						fireTime *= value;
					}
				}
				CreateParticle(0,"burninggibs",fireTime/1.25,_,_,pos[0],pos[1],pos[2],0.2,_,_,_,_,owner);
				if(team==2)
				{
					CreateParticle(0,"burningplayer_glow",fireTime,_,_,pos[0],pos[1],pos[2],_,false);
				}
				else if(team==3)
				{
					CreateParticle(0,"burningplayer_glow_blue",fireTime,_,_,pos[0],pos[1],pos[2],_,false);
				}
				g_lastFire[owner] = time;
			}
		}
	}
	return Plugin_Continue;
}

// Action FireTouch(int flame, int other) //lingering flamethrower flames
// {
// 	int owner = GetEntPropEnt(flame, Prop_Send, "m_hOwnerEntity");
// 	int weapon = GetEntPropEnt(flame, Prop_Send, "m_hLauncher");
// 	int weaponIndex = -1;
// 	if(weapon >= 0) weaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

// 	char class[64];
// 	GetEntityClassname(other, class, sizeof(class));
	
// 	if(weaponIndex==1178)
// 	{
// 		if(other==0 || StrEqual(class,"func_brush"))
// 		{
// 			float pos[3],ang[3],ownerPos[3];
// 			GetEntPropVector(flame, Prop_Send, "m_vecOrigin", pos);
// 			GetClientEyeAngles(owner, ang);
			
// 			Handle trace = TR_TraceRayFilterEx(pos, ang, MASK_SHOT, RayType_Infinite, TraceFilter, flame);
// 			if(!TR_DidHit(trace))
// 			{
// 				trace.Close();
// 				return Plugin_Continue;
// 			}
// 			TR_GetEndPosition(pos, trace);
// 			GetEntPropVector(owner, Prop_Send, "m_vecOrigin", ownerPos);
// 			if(GetVectorDistance(pos,ownerPos)>340)
// 			{
// 				trace.Close();
// 				return Plugin_Continue;
// 			}

// 			GetEntPropVector(flame, Prop_Send, "m_vecOrigin", pos);
// 			int team = GetEntProp(flame, Prop_Send, "m_iTeamNum");
// 			float fireTime = FIRE_TIME;
// 			if(g_bIsMVM) //mvm burn time
// 			{
// 				Address addr = TF2Attrib_GetByName(weapon, "weapon burn time increased");
// 				if(addr != Address_Null)
// 				{
// 					float value = TF2Attrib_GetValue(addr);
// 					fireTime *= value;
// 				}
// 			}
// 			CreateParticle(0,"burninggibs",fireTime/1.25,_,_,pos[0],pos[1],pos[2],0.2,_,_,_,_,owner);
// 			if(team==2)
// 			{
// 				CreateParticle(0,"burningplayer_glow",fireTime,_,_,pos[0],pos[1],pos[2],_,false);
// 			}
// 			else if(team==3)
// 			{
// 				CreateParticle(0,"burningplayer_glow_blue",fireTime,_,_,pos[0],pos[1],pos[2],_,false);
// 			}
// 		}
// 	}
// 	return Plugin_Continue;
// }

void laserSpawn(int iEnt)
{
	char class[64],class2[64];
	int weapon;
	float maxs[3],mins[3];
	GetEntityClassname(iEnt, class, sizeof(class));
	if (StrEqual(class, "tf_projectile_energy_ring"))
	{
		g_bisonHit[iEnt] = 0;
		weapon = GetEntPropEnt(iEnt, Prop_Send, "m_hLauncher");
		if (weapon > 0)
		{
			GetEntityClassname(weapon, class2, sizeof(class2));
			if (StrEqual(class, "tf_weapon_raygun")||StrEqual(class, "tf_weapon_drg_pomson"))
			{
				SetEntProp(iEnt, Prop_Send, "m_triggerBloat", 8);
				maxs[0] = 2.0; maxs[1] = 2.0; maxs[2] = 10.0;
				mins[0] = (0.0 - maxs[0]); mins[1] = (0.0 - maxs[1]); mins[2] = (0.0 - maxs[2]);
				SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", maxs);
				SetEntPropVector(iEnt, Prop_Send, "m_vecMins", mins);
			}
			SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", (GetEntProp(iEnt, Prop_Send, "m_usSolidFlags") | 0x80));
			if (StrEqual(class2, "tf_weapon_drg_pomson"))
			{
				float pos[3];
				GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", pos);
				pos[2]+=10;
				TeleportEntity(iEnt,pos,_,_);
			}
		}
	}
}

Action laserTouch(int entity, int other)
{
	char class[64];
	int owner;
	int weapon;
	GetEntityClassname(entity, class, sizeof(class));

	if (StrEqual(class, "tf_projectile_energy_ring"))
	{
		if (other >= 1 && other <= MaxClients)
		{
			owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			weapon = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
			if (owner > 0 && weapon > 0)
			{
				GetEntityClassname(weapon, class, sizeof(class));
				if (StrEqual(class, "tf_weapon_drg_pomson"))
				{
					if (TF2_GetClientTeam(owner) == TF2_GetClientTeam(other))
						return Plugin_Handled;
				}
				else if (StrEqual(class, "tf_weapon_raygun"))
				{
					if (TF2_GetClientTeam(owner) != TF2_GetClientTeam(other))
					{
						if(g_bisonHit[entity] == other)
							return Plugin_Handled;
						else
							g_bisonHit[entity] = other;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

Action rocketTouch(int entity, int other)
{
	if(IsValidEdict(entity))
	{
		int weapon = GetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher");
		int weaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
		if(IsValidClient(other))
		{
			if(weaponIndex == 127 && GetClientTeam(owner) != GetClientTeam(other))
			{
				if(g_condFlags[other] & TF_CONDFLAG_BLJUMP || TF2_IsPlayerInCondition(other,TFCond_BlastJumping))
					TF2_AddCondition(other,TFCond_MarkedForDeathSilent,0.015);
			}
		}
	}
	return Plugin_Continue;
}

void flareSpawn(int entity)
{
	char class[64];
	int weapon;
	GetEntityClassname(entity, class, sizeof(class));
	if (StrEqual(class, "tf_projectile_flare"))
	{
		weapon = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
		int wepIndex = -1;
		if (weapon != -1) wepIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		if (740 == wepIndex) //scorch bounce set
		{
			SetEntProp(entity, Prop_Data, "m_iHealth",0);
			// CreateTimer(0.045,flareActivate,entity);
		}
	}
}

public void Syringe_PrimaryAttack(int iClient,int primary,float angles[3],int index)
{
	int syringe = CreateEntityByName("tf_projectile_syringe");
	if(syringe != -1)
	{
		int team = GetClientTeam(iClient);
		bool kritzed = isKritzed(iClient);
		float pos[3],vel[3],ang[3],playervel[3],offset[3];
		GetClientEyePosition(iClient, pos);
		GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", playervel);
		ang=angles;
		ang[0] += GetRandomFloat(-1.75,1.75) - 1.5; ang[1] += GetRandomFloat(-1.75,1.75) + 0.25; //add spread
		offset[0] = (1.0 * Sine(DegToRad(ang[1])));
		offset[1] = (-1.0 * Cosine(DegToRad(ang[1])));
		offset[2] = -2.5;
		//inherit player velocity
		offset[0] += playervel[0]*0.1125;
		offset[1] += playervel[1]*0.1125;
		offset[2] += playervel[2]*0.1125;
		pos[0]+=offset[0]; pos[1]+=offset[1]; pos[2]+=offset[2];

		char wepSound[64];
		if(index==412)
		{
			if(kritzed) strcopy(wepSound, 64, "weapons/tf_medic_syringe_overdose_crit.wav");
			else strcopy(wepSound, 64, "weapons/tf_medic_syringe_overdose.wav");
		}
		else
		{
			if(kritzed) strcopy(wepSound, 64, "weapons/syringegun_shoot_crit.wav");
			else strcopy(wepSound, 64, "weapons/syringegun_shoot.wav");
		}
		//produce sound to those nearby
		int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
		int clip = GetEntData(primary, iAmmoTable, 4);
		int channel = clip%2 == 0 ? SNDCHAN_WEAPON : SNDCHAN_ITEM; //alternate channel based on clip
		EmitSoundToClient(iClient,wepSound,iClient,channel,SNDLEVEL_GUNFIRE);
		for(int idx = 1; idx < MaxClients; idx++)
		{
			if(IsValidClient(idx) && idx!=iClient)
			{
				//play sound
				float dist = getPlayerDistance(idx,iClient);
				dist = dist > 1800 ? 1800.0 : (dist < 512 ? 512.0 : dist);
				EmitSoundToClient(idx,wepSound,iClient,_,SNDLEVEL_GUNFIRE,_,1.0-(dist/1800));
			}
		}

		SetEntPropEnt(syringe, Prop_Send, "m_hOwnerEntity", iClient);
		SetEntPropEnt(syringe, Prop_Send, "m_hLauncher", primary);
		SetEntProp(syringe, Prop_Data, "m_iTeamNum", team);
		SetEntProp(syringe, Prop_Send, "m_iTeamNum", team);
		SetEntProp(syringe, Prop_Data, "m_CollisionGroup", 24);
		SetEntProp(syringe, Prop_Data, "m_usSolidFlags", 0);
		// SetEntProp(syringe, Prop_Send, "m_iProjectileType", 8);
		SetEntProp(syringe, Prop_Data, "m_nSkin", team-2);
		SetEntProp(syringe, Prop_Send, "m_nSkin", team-2);
		SetEntPropVector(syringe, Prop_Data, "m_angRotation", ang);
		if(index==36) SetEntityModel(syringe, "models/weapons/c_models/c_leechgun/c_leech_proj.mdl");
		else SetEntityModel(syringe, "models/weapons/w_models/w_syringe_proj.mdl");
		SetEntPropFloat(syringe, Prop_Send, "m_flModelScale", 1.5);
		
		DispatchSpawn(syringe);
		
		vel[0] = Cosine(DegToRad(ang[0]))*Cosine(DegToRad(ang[1]))*1400.0 + playervel[0]*0.0;
		vel[1] = Cosine(DegToRad(ang[0]))*Sine(DegToRad(ang[1]))*1400.0 + playervel[1]*0.0;
		vel[2] = Sine(DegToRad(ang[0]))*-1400.0 + playervel[2]*0.0;

		TeleportEntity(syringe, pos, ang, vel);			//Transport syringe
	}
}

void needleSpawn(int entity)
{
	int weapon = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
	int wepIndex = -1;
	if (weapon != -1) wepIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	bool kritzed = isKritzed(owner);
	if(kritzed)
		SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 1.0);
	else
		SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 0.0);
	SetEntPropFloat(entity, Prop_Data, "m_flGravity", 0.3);
	SetEntPropFloat(entity, Prop_Data, "m_flRadius", 0.3);
	if(wepIndex==36) SetEntityModel(entity, "models/weapons/c_models/c_leechgun/c_leech_proj.mdl");
	else SetEntityModel(entity, "models/weapons/w_models/w_syringe_proj.mdl");

	int team = GetEntProp(entity, Prop_Send, "m_iTeamNum");
	float ang[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", ang);
	ang[0] = DegToRad(ang[0]); ang[1] = DegToRad(ang[1]); ang[2] = DegToRad(ang[2]);
	if(team == 2)
	{
		if (kritzed) CreateParticle(entity,"nailtrails_medic_red_crit",1.0,ang[0],ang[1],_,_,_,_,_,false);
		else CreateParticle(entity,"nailtrails_medic_red",1.0,ang[0],ang[1],_,_,_,_,_,false);
	}
	if(team == 3)
	{
		if (kritzed) CreateParticle(entity,"nailtrails_medic_blue_crit",1.0,ang[0],ang[1],_,_,_,_,_,false);
		else CreateParticle(entity,"nailtrails_medic_blue",1.0,ang[0],ang[1],_,_,_,_,_,false);
	}

	SDKHook(entity, SDKHook_StartTouch, needleTouch);
}

Action needleTouch(int entity, int other)
{
	int weapon = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
	int wepIndex = -1;
	if (weapon != -1) wepIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	switch(wepIndex)
	{
		case 17,204,36,412:
		{
			int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			if(IsValidClient(owner))
			{
				char class[64];
				GetEntityClassname(other, class, 64);
				if (other != owner && other >= 1 && other <= MaxClients)
				{
					TFTeam team = TF2_GetClientTeam(other);
					//set teammates crit heals to max with syringes
					if(TF2_GetClientTeam(owner) == team)
					{
						// int dmg = GetEntProp(iClient, Prop_Data, "m_lastDamageAmount");
						float dmgTime = GetEntDataFloat(other,LAST_DAMAGE); //m_flLastDamageTime
						float currTime = GetGameTime();
						if(currTime - dmgTime < 10.0) //only set it to 10 seconds to when ramp up starts
						{
							SetEntDataFloat(other,LAST_DAMAGE,currTime-10.0,true); //set last damage time back
							if(!TF2_IsPlayerInCondition(other,TFCond_Cloaked)&&!TF2_IsPlayerInCondition(other,TFCond_CloakFlicker))
							{
								if(team == TFTeam_Blue)
									CreateParticle(other,"soldierbuff_blue_buffed",1.0,_,_,_,_,_,_,false,false);
								else if(team == TFTeam_Red)
									CreateParticle(other,"soldierbuff_red_buffed",1.0,_,_,_,_,_,_,false,false);
							}
							EmitSoundToClient(owner,"player/recharged.wav");
							EmitSoundToClient(other,"player/recharged.wav");
							
							// float recovery = 2.0;
							if(wepIndex==36) //Blutsauger heal on recovery
							{
								SetHudTextParams(0.1, -0.16, 0.1, 255, 255, 255, 255);
								ShowHudText(owner,2,"+10 HP");
								TF2Util_TakeHealth(owner,10.0);
							}
						}
						else
						{
							EmitSoundToClient(owner,"weapons/syringegun_reload_air2.wav");
							EmitSoundToClient(other,"weapons/syringegun_reload_air2.wav");
						}
					}
					else
					{
						//syringe is crit?
						int damagetype = DMG_BULLET;
						float damage = 10.0;
						if(GetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate") == 1.0)
						{
							damage *= 3.0;
							damagetype |= DMG_CRIT;
						}
						//syringe aim punch
						g_syringeHit[other] = damage;
						SDKHooks_TakeDamage(other,entity,owner,0.01,damagetype);
					}
					return Plugin_Stop;
				}
				else if (other == 0 || StrEqual(class, "propr_dynamic") || StrEqual(class, "func_door"))
				{
					CreateParticle(entity,"impact_metal",1.0,_,_,_,_,_,_,false);
					AcceptEntityInput(entity,"Kill");
					// SDKHook(entity, SDKHook_Touch, needleOnTouch);
				}
			}
		}
	}
	return Plugin_Continue;
}

Action flareTouch(int entity, int other)
{
	char class[64];
	int owner;
	int weapon;
	GetEntityClassname(entity, class, sizeof(class));

	owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	weapon = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
	int wepIndex = -1;
	if (weapon != -1) wepIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	if (StrEqual(class, "tf_projectile_flare") && 740 == wepIndex) //scorch shot bounce
	{
		GetEntityClassname(other, class, sizeof(class));
		if (IsValidClient(other)) //bounce off players
		{
			if(TF2_GetClientTeam(owner) != TF2_GetClientTeam(other))
			{
				if(GetEntProp(entity, Prop_Data, "m_iHealth")==1)
				{
					SetEntityGravity(entity,0.3);
				}
				else
				{
					SetEntProp(entity, Prop_Data, "m_iHealth",1);
				}
			}
		}
		else if (StrContains(class, "obj_") != 0 && StrContains(class, "tf_projectile_") == -1) //bounce off world
		{
			if(GetEntProp(entity, Prop_Data, "m_iHealth") == 0)
			{
				SDKHook(entity, SDKHook_Touch, flareOnTouch);
				return Plugin_Handled;
			}
		}
		return Plugin_Changed;
	}
	if(StrEqual(class, "tf_projectile_mechanicalarmorb")) //short circuit jump
	{
		if (other == 0)
		{
			float flarePos[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", flarePos);
			float targetPos[3];
			GetEntPropVector(owner, Prop_Send, "m_vecOrigin", targetPos);
			float dist = GetVectorDistance(flarePos,targetPos);
			if(dist<=150)
			{
				float damage = 25.0;
				int type = DMG_SHOCK | DMG_BLAST;
				float vel[3];
				float force[3];
				GetEntPropVector(entity, Prop_Data, "m_vecVelocity",force);
				GetEntPropVector(owner, Prop_Data, "m_vecVelocity",vel);
				float mag = GetVectorLength(force);
				force[0]/=mag;force[1]/=mag;force[2]/=mag;
				force[0]*=-100.0;force[1]*=-100.0;force[2]*=-100.0;
				vel[0]+=force[0];vel[1]+=force[1];vel[2]+=force[2];
				TeleportEntity(owner,NULL_VECTOR,NULL_VECTOR,vel);
				SDKHooks_TakeDamage(owner, owner, owner, damage, type, weapon, NULL_VECTOR, flarePos, false);
				TF2_AddCondition(owner,TFCond_BlastJumping,_,owner);
			}
		}
	}
	return Plugin_Continue;
}

Action flareOnTouch(int entity, int other)
{
	int weapon = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
	int wepIndex = -1;
	if (weapon != -1) wepIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	switch(wepIndex)
	{
		case 740:
		{
			float vOrigin[3], vAngles[3], vVelocity[3];
			GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vOrigin);
			GetEntPropVector(entity, Prop_Data, "m_angRotation", vAngles);
			GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vVelocity);
			
			Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceFilter, entity);
			if(!TR_DidHit(trace))
			{
				trace.Close();
				return Plugin_Continue;
			}
			
			float vNormal[3],vScaledNormal[3];
			TR_GetPlaneNormal(trace, vNormal);
			vScaledNormal = vNormal;
			trace.Close();

			float dotProduct = GetVectorDotProduct(vNormal, vVelocity);
			
			ScaleVector(vScaledNormal, dotProduct);
			// ScaleVector(vScaledNormal, 2.0);
			ScaleVector(vNormal, 150.0);
			
			float vBounceVec[3];
			SubtractVectors(vVelocity, vScaledNormal, vBounceVec);
			ScaleVector(vBounceVec, 0.33);
			// vBounceVec[2] = 0.0;

			AddVectors(vNormal,vBounceVec,vScaledNormal);
			vScaledNormal[2] = 250.0;
				
			float vNewAngles[3];
			GetVectorAngles(vNormal, vNewAngles);
			
			TeleportEntity(entity, NULL_VECTOR, vNewAngles, vScaledNormal);
			SetEntProp(entity, Prop_Data, "m_iHealth",1);
			SetEntityGravity(entity,0.6);
			SDKUnhook(entity,SDKHook_Touch,flareOnTouch);
			CreateTimer(0.105,RotateFlare,entity,TIMER_REPEAT);
		}
	}
	return Plugin_Handled;
}

Action RotateFlare(Handle timer, int entity)
{
	if(IsValidEdict(entity))
	{
		char class[64];
		GetEntityClassname(entity, class, sizeof(class));
		if (StrEqual(class, "tf_projectile_flare"))
		{
			float vAngles[3];
			GetEntPropVector(entity, Prop_Data, "m_angRotation", vAngles);
			ScaleVector(vAngles, 1.05);
			TeleportEntity(entity, NULL_VECTOR, vAngles, NULL_VECTOR);
			return Plugin_Continue;
		}
	}
	return Plugin_Stop;
}

Action SlowOrb(Handle timer, DataPack pack)
{
	pack.Reset();
	int entity = pack.ReadCell();
	float scale = pack.ReadFloat();
	if(IsValidEdict(entity))
	{
		//alter short circuit orb speed
		float vel[3];
		GetEntPropVector(entity, Prop_Data, "m_vecVelocity", vel);
		vel[0]*= 0.1 + 0.9*scale;
		vel[1]*= 0.1 + 0.9*scale;
		vel[2]*= 0.1 + 0.9*scale;
		TeleportEntity(entity,_,_,vel);
	}
	return Plugin_Continue;
}
Action KillOrb(Handle timer, int flare)
{
	if(IsValidEdict(flare))
	{
		char class[64];
		GetEntityClassname(flare, class, sizeof(class));
		if (StrEqual(class, "tf_projectile_mechanicalarmorb")) //create explosion for short circuit
		{
			int team = GetEntProp(flare, Prop_Data, "m_iTeamNum");
			if(team == 3)
				CreateParticle(flare,"drg_cow_explosioncore_normal_blue",3.0,_,_,_,_,_,_,false);
			else if(team == 2)
				CreateParticle(flare,"drg_cow_explosioncore_normal",3.0,_,_,_,_,_,_,false);
		}
		AcceptEntityInput(flare,"KillHierarchy");
	}
	return Plugin_Continue;
}

void AirblastPush(int client,float base)
{
	int primary = TF2Util_GetPlayerLoadoutEntity(client, TFWeaponSlot_Primary, true);
	int primaryIndex = -1;
	if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");

	float meter = base;
	meter *= PRESSURE_FORCE;
	if (primaryIndex==40||primaryIndex==1146) //backburner force
		meter *= 1.3;
	else if(primaryIndex==594) //phlogistinator "force"
		meter *= 0.00;
	if(g_bIsMVM) //mvm force
	{
		Address addr = TF2Attrib_GetByName(primary, "melee range multiplier");
		if(addr != Address_Null)
		{
			float value = TF2Attrib_GetValue(addr);
			meter *= value;
		}
	}
	float force[3],angles[3],vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity",vel);
	GetClientEyeAngles(client,angles);
	float angle1 = angles[1]*0.01745329;
	float angle2 = angles[0]*0.01745329;
	force[0] = Cosine(angle1) * Cosine(angle2);
	force[1] = Sine(angle1) * Cosine(angle2);
	force[2] = Sine(angle2);
	force[0]*=-1*meter;force[1]*=-1*meter;force[2]*=meter;
	//scale forces
	// force[0]*=0.8;force[1]*=0.8;force[2]*=1.25;
	vel[0]+=force[0]; vel[1]+=force[1]; vel[2]+=force[2];

	TeleportEntity(client,_,_,vel);
	TF2_AddCondition(client,TFCond_BlastJumping,_,client);
}

void manglerSpawn(int entity)
{
	if(g_manglerCharge[entity]==0)
		RequestFrame(manglerCheck,entity);
	g_manglerCharge[entity]=1;
}
void manglerCheck(int entity)
{
	if(IsValidEdict(entity))
	{
		int charged = GetEntProp(entity, Prop_Send, "m_bChargedShot");
		if(charged==1)
		{
			g_manglerCharge[entity] = 0;
			CreateTimer(1.4,manglerBoom,entity);
		}
	}
}
Action manglerBoom(Handle timer, int entity)
{
	if(IsValidEdict(entity))
	{
		char class[64];
		GetEntityClassname(entity, class, sizeof(class));
		if (StrEqual(class, "tf_projectile_energy_ball"))
		{
			if(GetEntProp(entity, Prop_Send, "m_bChargedShot"))
			{
				int weapon = GetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher");
				int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
				float projectile_pos[3], target_pos[3], force_vec[3];
				float distance = 0.0;
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", projectile_pos);

				//recoil blast
				int team = GetEntProp(client, Prop_Data, "m_iTeamNum");
				if(team == 3)
					CreateParticle(entity,"drg_cow_explosioncore_charged_blue",3.0,_,_,_,_,_,3.0,false);
				else if(team == 2)
					CreateParticle(entity,"drg_cow_explosioncore_charged",3.0,_,_,_,_,_,3.0,false);
				EmitAmbientSound("mvm/giant_soldier/giant_soldier_explode.wav",projectile_pos,entity);
				
				for(int idx = 1; idx < MaxClients; idx++)
				{
					if(IsValidClient(idx,false))
					{
						if(IsPlayerAlive(idx) && (GetClientTeam(idx) != GetClientTeam(client) || idx == client))
						{
							GetClientEyePosition(idx,target_pos);
							distance = GetVectorDistance(projectile_pos, target_pos);
							if(distance < 156)
							{
								float damage = 45.0 + 15.0*((156-distance)/156);
								int damagetype = DMG_BLAST | DMG_IGNITE;
								if(idx==client)
									damage = 60.0;
								TF2_AddCondition(idx,TFCond_MarkedForDeathSilent,0.015);
								SDKHooks_TakeDamage(idx, entity, client, damage, damagetype, weapon, force_vec, projectile_pos, false);
								if(TF2_GetPlayerClass(idx)!=TFClass_Pyro) TF2Util_SetPlayerBurnDuration(idx,6.0);
							}
						}
					}
				}
				AcceptEntityInput(entity,"Kill");
				return Plugin_Stop;
			}
		}
	}
	return Plugin_Continue;
}

void orbSpawn(int entity)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	if (StrEqual(class, "tf_projectile_mechanicalarmorb"))
	{
		int weapon = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
		int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
		float scale = g_meterSec[owner]/1.9;
		// destroy short circuit orb much sooner
		DataPack pack = new DataPack();
		pack.Reset();
		pack.WriteCell(entity);
		pack.WriteFloat(scale);
		CreateTimer(0.075,SlowOrb,pack);
		CreateTimer(1.0,KillOrb,entity);
		SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack",GetGameTime()+0.6);
		g_meterSec[owner] = 2.5;
	}
}

void FlameSpawn(int flame)
{
	int owner = GetEntPropEnt(flame, Prop_Send, "m_hAttacker");
	if(IsValidClient(owner))
		g_Flames[owner] = flame;
}

void PipeSpawn(int grenade)
{
	g_Grenades[grenade] = -1.0;
}

public Action KillNeighbor(Handle timer, int neighbor)
{
	//iron bomber destroy
	g_Grenades[neighbor] = -1.0;
	// bool self = false;
	// bool jump = true;
	int weapon = GetEntPropEnt(neighbor, Prop_Send, "m_hLauncher");
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	float pos2[3],vicPos[3];
	GetEntPropVector(neighbor, Prop_Send, "m_vecOrigin", pos2);
	
	CreateParticle(neighbor,"ExplosionCore_MidAir",2.0);
	EmitAmbientSound("weapons/pipe_bomb1.wav",pos2,neighbor);
	for (int j = 1 ; j <= MaxClients ; j++)
	{
		if(IsValidClient(j,false))
		{
			GetEntPropVector(j, Prop_Send, "m_vecOrigin", vicPos);
			vicPos[2]+=5;
			float dist = GetVectorDistance(vicPos,pos2);
			if(dist<=148 && (TF2_GetClientTeam(owner) != TF2_GetClientTeam(j) || owner == j))
			{
				Handle hndl = TR_TraceRayFilterEx(pos2, vicPos, MASK_SOLID, RayType_EndPoint, PlayerTraceFilter, neighbor);
				if(TR_DidHit(hndl) == false || IsValidClient(TR_GetEntityIndex(hndl),false))
				{
					float damage = 60 - 30*(dist/148);
					if(g_bIsMVM) //mvm damage
					{
						Address addr = TF2Attrib_GetByName(weapon, "damage bonus");
						if(addr != Address_Null)
						{
							float value = TF2Attrib_GetValue(addr);
							damage *= value;
						}
					}
					int type = DMG_BLAST;
					if(owner == j)
					{
						// damage *= 0.75;
					}
					else if(owner != j)
					{
						// jump = false;
						int crit = GetEntProp(neighbor, Prop_Send, "m_bCritical");
						if(crit)
						{
							type |= DMG_CRIT;
						}
					}
					SDKHooks_TakeDamage(j, neighbor, owner, damage, type, weapon, NULL_VECTOR, pos2, false);
				}
				delete hndl;
			}
		}
	}
	AcceptEntityInput(neighbor,"Kill");
	return Plugin_Continue;
}

void BlastJump(int iClient)
{
	if(IsClientInGame(iClient))
	{
		if(IsPlayerAlive(iClient))
		{
			TF2_AddCondition(iClient,TFCond_BlastJumping,_,iClient);
		}
	}
}

void CleanDOT(DataPack pack)
{
	pack.Reset();
	int iClient = pack.ReadCell();
	int bash = pack.ReadCell();
	if(IsClientInGame(iClient))
	{
		if(IsPlayerAlive(iClient))
		{
			TF2_RemoveCondition(iClient,TFCond_OnFire);
			TF2_RemoveCondition(iClient,TFCond_Bleeding);
			if(bash)
			{
				TF2_RemoveCondition(iClient,TFCond_Milked);
				TF2_RemoveCondition(iClient,TFCond_Jarated);
				TF2_RemoveCondition(iClient,TFCond_MarkedForDeath);
				TF2_RemoveCondition(iClient,TFCond_MarkedForDeathSilent);
			}
		}
	}
}

void FlushCleaver(int iClient)
{
	if(IsClientInGame(iClient))
	{
		if(IsPlayerAlive(iClient))
		{
			int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
			int iOffset = GetEntProp(secondary, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
			int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
			int ammo = GetEntData(iClient, iAmmoTable+iOffset, 4);
			float regen = GetEntPropFloat(secondary,Prop_Send,"m_flEffectBarRegenTime");

			if(regen!=g_meterSec[iClient]) //match regen
				SetEntPropFloat(secondary,Prop_Send,"m_flEffectBarRegenTime",g_meterSec[iClient]);
			if(ammo>0) //wipe ammo
				SetEntData(iClient, iAmmoTable+iOffset, -1, 4, true);
		}
	}
}

void RemoveMeltCrit(int iClient)
{
	if(IsClientInGame(iClient))
	{
		if(IsPlayerAlive(iClient))
		{
			int crits = GetEntProp(iClient, Prop_Send, "m_iRevengeCrits");
			SetEntProp(iClient, Prop_Send, "m_iRevengeCrits",crits-1);
		}
	}
}
// Action DetectReload (int weapon)
// {
// 	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
// 	PrintToChat(owner,"RELOAD");
// }


void SetAnimation(int client, char[] Animation, int AnimationType, int ClientCommandType)
{
	SetCommandFlags("mp_playanimation", GetCommandFlags("mp_playanimation") ^FCVAR_CHEAT);
	SetCommandFlags("mp_playgesture", GetCommandFlags("mp_playgesture") ^FCVAR_CHEAT);
	char Anim[PLATFORM_MAX_PATH];
	switch(AnimationType)
	{
		case 1:
		{
			Format(Anim, PLATFORM_MAX_PATH, "mp_playanimation %s", Animation);
		}
		case 2:
		{
			Format(Anim, PLATFORM_MAX_PATH, "mp_playgesture %s", Animation);
		}
	}
	switch(ClientCommandType)
	{
		case 1: ClientCommand(client, Anim);
		case 2: FakeClientCommand(client, Anim);
		case 3:	FakeClientCommandEx(client, Anim);
	}
}

bool TraceFilter(int entity, int contentsmask, any data)
{
	char class[64];
	if (entity == data)
		return false;
	if (entity <= MaxClients)
		return false;
	GetEntityClassname(entity, class, sizeof(class));
	if (StrContains(class, "obj_") == 0 || StrContains(class, "tf_projectile_") == 0)
		return false;
	return true;
}

bool SimpleTraceFilter(int entity, int contentsMask, any data)
{
	if(entity != data)
		return (false);
	return (true);
}

bool PlayerTraceFilter(int entity, int contentsMask, any data)
{
	if(entity == data)
		return (false);
	if(IsValidClient(entity))
		return (false);
	return (true);
}

float getPlayerDistance(int clientA, int clientB)
{
	float clientAPos[3], clientBPos[3];
	GetEntPropVector(clientA, Prop_Send, "m_vecOrigin", clientAPos);
	GetEntPropVector(clientB, Prop_Send, "m_vecOrigin", clientBPos);
	return GetVectorDistance(clientAPos,clientBPos);
}

bool isKritzed(int client)
{
	int secondary = TF2Util_GetPlayerLoadoutEntity(client, TFWeaponSlot_Secondary, true);
	int secondaryIndex = -1;
	if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
	float charge = GetEntPropFloat(client, Prop_Send, "m_flChargeMeter");

	return (TF2_IsPlayerInCondition(client,TFCond_Kritzkrieged) ||
	TF2_IsPlayerInCondition(client,TFCond_CritOnFirstBlood) ||
	TF2_IsPlayerInCondition(client,TFCond_CritOnWin) ||
	TF2_IsPlayerInCondition(client,TFCond_CritOnFlagCapture) ||
	TF2_IsPlayerInCondition(client,TFCond_CritOnKill) ||
	TF2_IsPlayerInCondition(client,TFCond_CritOnDamage) ||
	TF2_IsPlayerInCondition(client,TFCond_CritMmmph) ||
	(TF2_IsPlayerInCondition(client,TFCond_CritDemoCharge) && ((charge<=40 && secondaryIndex!=1099) || charge==100.0)) ||
	TF2_IsPlayerInCondition(client,TFCond_HalloweenCritCandy));
}

bool isMiniKritzed(int client,int victim=-1)
{
	int secondary = TF2Util_GetPlayerLoadoutEntity(client, TFWeaponSlot_Secondary, true);
	int secondaryIndex = -1;
	if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
	float charge = GetEntPropFloat(client, Prop_Send, "m_flChargeMeter");
	bool result=false;

	if(victim!=-1)
	{
		if (TF2_IsPlayerInCondition(victim,TFCond_Jarated) || TF2_IsPlayerInCondition(victim,TFCond_MarkedForDeath) || TF2_IsPlayerInCondition(victim,TFCond_MarkedForDeathSilent))
			result = true;
	}
	if (TF2_IsPlayerInCondition(client,TFCond_MiniCritOnKill) || TF2_IsPlayerInCondition(client,TFCond_Buffed) || TF2_IsPlayerInCondition(client,TFCond_CritCola) || (TF2_IsPlayerInCondition(client,TFCond_CritDemoCharge) && ((charge<=75 && charge>40) || (charge<=75 && secondaryIndex==1099))))
		result = true;
	return result;
}

stock int GetHealingTarget(int client)
{
	if(IsValidClient(client))
	{
		int index = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		int secondary = TF2Util_GetPlayerLoadoutEntity(client, TFWeaponSlot_Secondary, true);
		if(secondary == index)
		{
			if( GetEntProp(index, Prop_Send, "m_bHealing") == 1 )
			{
				return GetEntPropEnt(index, Prop_Send, "m_hHealingTarget");
			}
		}
	}
	return -1;
}

stock bool IsValidClient(int client, bool attributes = true)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (!CanClientReceiveClassAttributes(client) && attributes) return false;
	return true;
}

public bool CanClientReceiveClassAttributes(int iClient)
{
	if (IsFakeClient(iClient))
	{
		if (!g_bApplyClassChangesToBots.BoolValue) return false;
		else
		{
			if (g_bIsMVM
			&& TF2_GetClientTeam(iClient) == TFTeam_Blue
			&& !g_bApplyClassChangesToMvMBots.BoolValue)
			{
				return false;
			}
		}
	}
	
	return true;
}

stock bool IsHalloweenMap(const char[] mapName)
{
	int mapIndex = FindStringInArray(g_Maplist, mapName);
	return (mapIndex > -1);
}

public void SpawnSpooky(int victim)
{
	int skeleton = CreateEntityByName("tf_zombie");
	if(IsValidEntity(skeleton))
	{
		DispatchKeyValue(skeleton, "targetname", "tf_zombie");
		int team = GetEntProp(victim, Prop_Send, "m_iTeamNum")==3 ? 2 : 3;
		SetEntProp(skeleton, Prop_Send, "m_iTeamNum", team);
		if(team==2)
			DispatchKeyValue(skeleton, "skin", "0");
		else
			DispatchKeyValue(skeleton, "skin", "1");
		float victimPos[3];
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
		TeleportEntity(skeleton, victimPos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(skeleton);
		EmitAmbientSound("misc/halloween/spell_skeleton_horde_cast.wav",victimPos,skeleton);
		CreateTimer(15.0,KillSpooky,skeleton);
	}
}

public Action KillSpooky(Handle timer, int skeleton)
{
	//reset afterburn immunity on spy-cicle
	if (IsValidEntity(skeleton))
	{
		AcceptEntityInput(skeleton,"Kill");
	}
	return Plugin_Continue;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask, any data)
{
    return entity == 0 || entity > MaxClients;
}

int GetRandomUInt(int min, int max)
{
	return RoundToFloor(GetURandomFloat() * (max - min + 1)) + min;
}

float GetMax(float a, float b)
{
	return a > b ? a : b;
}
float GetMin(float a, float b)
{
	return a < b ? a : b;
}