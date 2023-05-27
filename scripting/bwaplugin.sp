#include <sourcemod>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf2condhooks>
#include <tf2utils>
#pragma newdecls required
#pragma semicolon 1
#define VDECODE_FLAG_ALLOWWORLD  (1<<2)

ConVar g_bEnablePlugin; // Convar that enables plugin
ConVar g_bApplyClassChangesToBots; // Convar that decides if attributes should apply to bots.
ConVar g_bApplyClassChangesToMvMBots; // Convar that decides if attributes should apply to MvM bots.

bool g_bIsMVM = false; // Is the mode MvM?

float g_lastHit[MAXPLAYERS+1];
float g_nextHit[MAXPLAYERS+1];
float g_lastFire[MAXPLAYERS+1];
float g_meleeStart[MAXPLAYERS+1];
float g_lastFlamed[MAXPLAYERS+1];
float g_temperature[MAXPLAYERS+1];
int g_TrueLastButtons[MAXPLAYERS+1];
int g_LastButtons[MAXPLAYERS+1];
int g_consecHits[MAXPLAYERS+1];
int g_condFlags[MAXPLAYERS+1];
int g_lastHeal[MAXPLAYERS+1];
int g_lockOn[MAXPLAYERS+1];
int g_Fov[MAXPLAYERS+1];
int g_bisonHit[2048];
int g_Grenades[2048];
bool g_holstering[MAXPLAYERS+1];
float g_holsterPri[MAXPLAYERS+1];
float g_holsterSec[MAXPLAYERS+1];
float g_holsterMel[MAXPLAYERS+1];
float g_meterPri[MAXPLAYERS+1];
float g_meterSec[MAXPLAYERS+1];
float g_meterMel[MAXPLAYERS+1];
float g_flameHit[2048];

float IRON_DETECT = 80.0;
float HOVER_TIME = -2.0;
float PARACHUTE_TIME = 6.0;
float KUNAI_MAX = 190.0;
float KUNAI_MIN = 45.0;
float FIRE_TIME = 3.0;
float SODA_DAMAGE = 30.0;
float PRESSURE_TIME = 6.0;
float PRESSURE_FORCE = 2.2;
#define TF_CONDFLAG_VACCMIN			(1 << 0)
#define TF_CONDFLAG_VACCMED			(1 << 1)
#define TF_CONDFLAG_VACCMAX      	(1 << 2)
#define TF_CONDFLAG_VOLCANO      	(1 << 3)
#define TF_CONDFLAG_HEAT	      	(1 << 4)
#define TF_CONDFLAG_HEATSPAWN		(1 << 5)
#define TF_CONDFLAG_HEALBLOCK		(1 << 6)
#define TF_CONDFLAG_HEALSTEAL		(1 << 7)
#define TF_CONDFLAG_HOVER			(1 << 8)
#define TF_CONDFLAG_FAKE			(1 << 9)
#define TF_CONDFLAG_INFIRE			(1 << 10)
#define TF_CONDFLAG_INMELEE			(1 << 11)
#define TF_CONDFLAG_QUICK			(1 << 12)
#define TF_CONDFLAG_HEATER			(1 << 13)
#define TF_CONDFLAG_FANHIT			(1 << 14)
#define TF_CONDFLAG_FANFLY			(1 << 15)

#define EF_BONEMERGE                (1 << 0)
#define EF_NOSHADOW                 (1 << 4)
#define EF_PARENT_ANIMATES          (1 << 9)

#define CPS_NOFLAGS           	 	0
#define CPS_RENDER            		(1 << 0)
#define CPS_NOATTACHMENT    		(1 << 1)

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
	g_bEnablePlugin = CreateConVar("sm_bwaplugin_enable", "1",
	"Enables/Disables the plugin. Default = 1, 0 to disable.",
	FCVAR_PROTECTED, true, 0.0, true, 1.0);
	g_bApplyClassChangesToBots = CreateConVar("sm_bwaplugin_bots_apply", "1",
	"Should changes apply to Bots? Enabling this could cause issues. Default = 1, 1 to enable.",
	FCVAR_PROTECTED, true, 0.0, true, 1.0);
	g_bApplyClassChangesToMvMBots = CreateConVar("sm_bwaplugin_botsmvm_apply", "0",
	"Should changes apply to MvM Bots? Enabling this could cause issues. Default = 0, 1 to enable.",
	FCVAR_PROTECTED, true, 0.0, true, 1.0);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_builtobject", Event_BuildObject);
	// HookEvent("object_destroyed", Event_ObjectDestroyed);

	AddCommandListener(PlayerListener,"taunt");

	AddGameLogHook(LogGameMessage);
	
	for (int i = 1 ; i <= MaxClients ; i++)
	{
		if(IsClientInGame(i))
			OnClientPutInServer(i);
		g_temperature[i]=0.5;
		g_holsterPri[i]=1.0;
		g_holsterSec[i]=1.0;
		g_holsterMel[i]=1.0;
	}

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
	PrecacheSound("weapons/bottle_impact_hit_flesh1.wav",true);
	PrecacheSound("weapons/medigun_no_target.wav",true);
	PrecacheSound("misc/flame_engulf.wav",true);
	PrecacheSound("misc/halloween/spell_fireball_impact.wav",true);
	PrecacheSound("weapons/syringegun_shoot.wav",true);
	PrecacheSound("weapons/overdose_shoot.wav",true);
	PrecacheSound("weapons/syringegun_shoot_crit.wav",true);
	PrecacheSound("weapons/overdose_shoot_crit.wav",true);
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
	PrecacheModel("models/weapons/w_models/w_syringe_proj.mdl",true);
	PrecacheModel("models/weapons/c_models/c_leechgun/c_leech_proj.mdl",true);
	PrecacheModel("models/workshop/weapons/c_models/c_chocolate/plate_chocolate.mdl",true);
	PrecacheModel("models/workshop/weapons/c_models/c_quadball/w_quadball_grenade.mdl",true);
	if (GameRules_GetProp("m_bPlayingMannVsMachine"))
		g_bIsMVM = true;
}

public void OnEntityCreated(int iEnt, const char[] classname)
{
	if(IsValidEntity(iEnt))
	{
		if(StrContains(classname,"healthkit") != -1 && StrContains(classname,"small") != -1)
		{
			SDKHook(iEnt, SDKHook_Touch, Event_PickUpHealth);
		}
		if(StrContains(classname, "ammopack") != -1 || StrContains(classname, "ammo_pack") != -1)
		{
			// SDKHook(iEnt, SDKHook_SpawnPost, Event_SpawnAmmo);
			SDKHook(iEnt, SDKHook_StartTouch, Event_PickUpAmmo);
		}else if(StrEqual(classname,"tf_projectile_mechanicalarmorb"))
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
		else if(StrEqual(classname,"obj_sentrygun") || StrEqual(classname,"obj_dispenser") || StrEqual(classname,"obj_teleporter"))
		{
			SDKHook(iEnt, SDKHook_SetTransmit, BuildingThink);
			SDKHook(iEnt, SDKHook_OnTakeDamage, BuildingDamage);
		}
		else if(StrEqual(classname,"tf_gas_manager"))
		{
			SDKHook(iEnt, SDKHook_Touch, GasTouch);
		}
		else if(StrEqual(classname,"item_teamflag"))
		{
			SDKHook(iEnt, SDKHook_Touch, FlagTouch);
		}
		else if(StrEqual(classname,"tf_flame_manager"))
		{
			SDKHook(iEnt, SDKHook_Touch, FlameTouch);
		}
		else if(StrEqual(classname,"tf_projectile_pipe"))
		{
			SDKHook(iEnt, SDKHook_SpawnPost, PipeSpawn);
			SDKHook(iEnt, SDKHook_Think, PipeSet);
			// SDKHook(iEnt, SDKHook_Touch, PipeTouch);
		}
		else if(StrEqual(classname, "item_healthkit_small")) //syringe
		{
			RequestFrame(chocolateSpawn,iEnt);
		}
		// else if(StrEqual(classname, "tf_projectile_arrow")) //syringe
		// {
		// 	SDKHook(iEnt, SDKHook_StartTouch, arrowTouch);
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
	if(StrContains(message,"player_extinguished") != -1 && (StrContains(message,"tf_weapon_jar") != -1 || StrContains(message,"tf_weapon_flaregun_revenge") != -1))
	{
		int idStartPos = StrContains(message,"<")+1;
		int idEndPos = StrContains(message,"[U:1:") - 2;
		if(idEndPos < 0)
			idEndPos = StrContains(message,"<BOT>") - 1;
		char[] id = new char[MAX_NAME_LENGTH];
		strcopy(id,MAX_NAME_LENGTH,message[idStartPos]);
		id[idEndPos-idStartPos] = 0;
		int user = GetClientOfUserId(StringToInt(id));
		int secondary = TF2Util_GetPlayerLoadoutEntity(user, TFWeaponSlot_Secondary, true);
		int secondaryIndex = -1;
		if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
		switch(secondaryIndex)
		{
			case 1180: //gas passer
				SetEntPropFloat(user, Prop_Send, "m_flItemChargeMeter", 20.0, 1);
			case 58,222,1121,1083,1105: //milk and jarate
			{
				SetEntPropFloat(secondary, Prop_Send, "m_flLastFireTime",GetGameTime()+32);
				SetEntPropFloat(secondary, Prop_Send, "m_flEffectBarRegenTime",GetGameTime()+32);
			}
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Handle hEvent, const char[] cName, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	char[] event = new char[64];
	GetEventName(hEvent,event,64);
	DataPack pack = new DataPack();
	pack.Reset();
	pack.WriteCell(iClient);
	pack.WriteString(event);
	float time=0.1;
	if(IsFakeClient(iClient)) time=0.25;
	CreateTimer(time,PlayerSpawn,pack);
	return Plugin_Changed;
}

public Action PlayerSpawn(Handle timer, DataPack dPack)
{
	dPack.Reset();
	int iClient = dPack.ReadCell();
	char[] event = new char[64];
	dPack.ReadString(event,64);

	if (IsValidClient(iClient) && g_bEnablePlugin.BoolValue)
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
		int watch = TF2Util_GetPlayerLoadoutEntity(iClient, 6, true);
		int watchIndex = -1;
		if(watch >= 0) watchIndex = GetEntProp(watch, Prop_Send, "m_iItemDefinitionIndex");
		
		g_holsterPri[iClient] = 1.0;
		g_holsterSec[iClient] = 1.0;
		g_holsterMel[iClient] = 1.0;
		TF2Attrib_SetByDefIndex(iClient,177,1.0);

		switch(TF2_GetPlayerClass(iClient))
		{
			case TFClass_Sniper:
			{
				//modify sniper ammo
				if(primaryIndex!=56 && primaryIndex!=1005 && primaryIndex!=1092) //ignore bows
				{					
					TF2Attrib_SetByDefIndex(primary,77,0.68); //set max ammo
					if(primaryIndex != 526 && primaryIndex != 30665) //set tracers
					{ 
						TF2Attrib_SetByDefIndex(primary,647,1.0);
						if(primaryIndex != 230) TF2Attrib_SetByDefIndex(primary,144,3.0);
						if(primaryIndex == 752) TF2Attrib_SetByDefIndex(primary,51,0.0);
					}
					//set clip and reserve
					TF2Attrib_SetByDefIndex(primary,303,4.0); //set clip ammo
					int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
					switch(primaryIndex)
					{
						case 1098: //Classic clip bonus
						{	
							SetEntData(primary, iAmmoTable, 6, 4, true);
							SetEntProp(primary, Prop_Send, "m_iClip1",6);
						}
						case 526, 30665: //Machina clip penalty
						{	
							SetEntData(primary, iAmmoTable, 3, 4, true);
							SetEntProp(primary, Prop_Send, "m_iClip1",3);
						}
						default: //default clip size
						{
							SetEntData(primary, iAmmoTable, 4, 4, true);
							SetEntProp(primary, Prop_Send, "m_iClip1",4);
						}
					}
					int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
					SetEntProp(iClient, Prop_Data, "m_iAmmo", 17 , _, primaryAmmo);
				}
			}
			case TFClass_Pyro: 
			{
				//modify pyro airblast
				if(primaryIndex!=594 && primaryIndex!=1178) //ignore DF and phlog
				{
					SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 100.0, 0);
					SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, 10);
					TF2Attrib_SetByDefIndex(primary,255,1.0); //airblast force
				}
			}
			case TFClass_Engineer:
			{
				TF2Attrib_SetByDefIndex(iClient,321,0.5); //build rate bonus
				TF2Attrib_SetByDefIndex(iClient,464,0.45); //engineer sentry build rate multiplier
				// TF2Attrib_SetByDefIndex(melee,6,0.25);
			}
			case TFClass_Spy:
			{
				TF2Attrib_SetByDefIndex(watch,253,-0.25); //mult cloak rate
				TF2Attrib_SetByDefIndex(watch,221,0.75); //mult decloak rate
				TF2Attrib_SetByDefIndex(secondary,51,1.0); //revolver use hit locations
			}
			// case TFClass_Heavy:
			// {
			// 	TF2Attrib_SetByDefIndex(iClient,107,240.0/230.0); //move speed bonus
			// 	TF2Attrib_SetByDefIndex(primary,54,0.9); //move speed penalty
			// 	TF2Attrib_SetByDefIndex(primary,128,1.0); //provide while active
			// 	int current = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
			// 	if (current==primary)
			// 	{
			// 		if(!TF2_IsPlayerInCondition(iClient,TFCond_Slowed))
			// 			SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",216.0);
			// 	}
			// 	else
			// 	{
			// 		if (current==melee && meleeIndex==239) SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",312.0);
			// 		else if (current==melee && meleeIndex==239) SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",276.0);
			// 		else SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",240.0);
			// 	}

			// 	// if(primaryIndex != 41 && primaryIndex != 312 && primaryIndex != 424 && primaryIndex != 811 && primaryIndex != 832)
			// 	// 	TF2Attrib_SetByDefIndex(primary,86,1.0/0.814); //minigun spinup time increased
			// }
		}

		//Panic Attack
		if(secondaryIndex == 1153 || primaryIndex == 1153)
		{
			int wep = secondaryIndex == 1153 ? secondary : primary;
			TF2Attrib_SetByDefIndex(wep,6,1.0); //firing speed bonus
			TF2Attrib_SetByDefIndex(wep,3,0.66); //clip size penalty
			TF2Attrib_SetByDefIndex(wep,1,0.85); //damage penalty
			TF2Attrib_SetByDefIndex(wep,106,0.85); //weapon spread bonus
			int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
			SetEntData(wep, iAmmoTable, 4, _, true);
		}
		//Reserve Shooter
		if(secondaryIndex == 415)
		{
			TF2Attrib_SetByDefIndex(secondary,3,0.5); //clip size penalty
			int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
			SetEntData(secondary, iAmmoTable, 3, _, true);
			TF2Attrib_SetByDefIndex(secondary,106,0.75); //weapon spread bonus
		}

		switch(primaryIndex)
		{
			//The Classic
			case 1098:
			{
				TF2Attrib_SetByDefIndex(primary,306,0.0); //headshots only at full charge
				TF2Attrib_SetByDefIndex(primary,4,1.5); //clip size bonus
			}
			//Brass Beast
			case 312:
			{
				// TF2Attrib_SetByDefIndex(primary,86,1.4/0.814); //spinup time penalty
				TF2Attrib_SetByDefIndex(primary,86,1.4); //spinup time penalty
				TF2Attrib_SetByDefIndex(primary,738,1.0); //spinup damge resistance
				// TF2Attrib_SetByDefIndex(primary,199,0.8); //holster speed bonus
			}
			//Huo-Long Heater
			case 811,832:
			{
				// TF2Attrib_SetByDefIndex(primary,86,1.0/0.814); //spinup time penalty
				TF2Attrib_SetByDefIndex(primary,1,1.0); //damage penalty
				TF2Attrib_SetByDefIndex(primary,21,0.9); //damage penalty vs non-burning players
				TF2Attrib_SetByDefIndex(primary,795,1.15); //damage bonus vs burning
				TF2Attrib_SetByDefIndex(primary,430,12.0); //ring of fire
				TF2Attrib_SetByDefIndex(primary,431,4.0); //spinup ammo drain
			}
			//Baby Face's Blaster
			case 772:
			{
				TF2Attrib_SetByDefIndex(primary,733,2.0); //hype lost on damge
				TF2Attrib_SetByDefIndex(primary,419,50.0); //hype resets on jump
			}
			//Liberty Launcher
			case 414:
			{
				TF2Attrib_SetByDefIndex(primary,6,0.85); //firing speed bonus
				TF2Attrib_SetByDefIndex(primary,100,0.9); //Blast radius decreased
			}
			//The Pomson 6000
			case 588:
			{
				TF2Attrib_SetByDefIndex(primary,337,0.0); //victim loses medigun charge
				TF2Attrib_SetByDefIndex(primary,338,0.0); //victim loses cloak
				TF2Attrib_SetByDefIndex(primary,6,0.8); //firing speed bonus
				TF2Attrib_SetByDefIndex(primary,97,0.8); //reload speed bonus
				TF2Attrib_SetByDefIndex(primary,335,1.5); //clip size upgrade
				SetEntPropFloat(primary, Prop_Send, "m_flEnergy", 30.0);
				TF2Attrib_SetByDefIndex(primary,103,1.5); //projectile speed
			}
			//The Back Scatter
			case 1103:
			{
				TF2Attrib_SetByDefIndex(primary,36,1.0); //spread penalty
				TF2Attrib_SetByDefIndex(primary,303,1.0); //set clip ammo
				TF2Attrib_SetByDefIndex(primary,97,0.7); //reload speed bonus
				TF2Attrib_SetByDefIndex(primary,5,1.20); //firing speed penalty
				// TF2Attrib_SetByDefIndex(primary,3,1.0/6); //clip size penalty
				int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
				SetEntData(primary, iAmmoTable, 1, _, true);
			}
			//The Shortstop
			case 220:
			{
				TF2Attrib_SetByDefIndex(primary,97,0.85); //Reload time decreased
				TF2Attrib_SetByDefIndex(primary,535,1.0); //damage force increase hidden
			}
			//Syringe Gun
			case 17,204:
			{
				TF2Attrib_SetByDefIndex(primary,280,9.0); //projectile override
			}
			//The Blutsauger
			case 36:
			{
				TF2Attrib_SetByDefIndex(primary,280,9.0); //projectile override
				TF2Attrib_SetByDefIndex(primary,881,0.0); //add_health_regen
				TF2Attrib_SetByDefIndex(primary,3,0.63); //clip size penalty
				int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
				SetEntData(primary, iAmmoTable, 25, _, true);
			}
			//The Overdose
			case 412:
			{
				TF2Attrib_SetByDefIndex(primary,280,9.0); //projectile override
				TF2Attrib_SetByDefIndex(primary,1,0.8); //damage penalty
				TF2Attrib_SetByDefIndex(primary,547,0.75); //deploy speed bonus
			}
			//The Phlogistinator
			case 594:
			{
				TF2Attrib_SetByDefIndex(primary,869,1.0); //crits become minicrits
				TF2Attrib_SetByDefIndex(primary,2,1.0); //damage bonus
			}
			//Natascha
			case 41:
			{
				TF2Attrib_SetByDefIndex(primary,32,0.0); //slow on hit
				TF2Attrib_SetByDefIndex(primary,1,0.80); //damage penalty
				TF2Attrib_SetByDefIndex(primary,738,1.0); //spinup damge resistance
				TF2Attrib_SetByDefIndex(primary,69,0.33); //health from healers reduced
				// TF2Attrib_SetByDefIndex(primary,16,5.0); //heal on hit for rapidfire
				TF2Attrib_SetByDefIndex(primary,76,1.5); //maxammo primary increased
				int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
				SetEntProp(iClient, Prop_Data, "m_iAmmo", 300 , _, primaryAmmo);
			}
			//Bazaar Bargain
			case 402:
			{
				TF2Attrib_SetByDefIndex(primary,1,0.9); //damage penalty
				TF2Attrib_SetByDefIndex(primary,41,1.1); //sniper charge
			}
			//Loch-n-Load
			case 308:
			{
				TF2Attrib_SetByDefIndex(primary,6,0.67); //fire rate bonus
				TF2Attrib_SetByDefIndex(primary,3,0.5); //clip size penalty
				int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
				SetEntData(primary, iAmmoTable, 2, _, true);
				TF2Attrib_SetByDefIndex(primary,96,1.35); //Reload time increased
				TF2Attrib_SetByDefIndex(primary,114,1.0); //mini-crit airborne
				TF2Attrib_SetByDefIndex(primary,137,1.0); //dmg bonus vs buildings
			}
			//Sydney Sleeper
			case 230:
			{
				TF2Attrib_SetByDefIndex(primary,175,3.0); //jarate duration
				TF2Attrib_SetByDefIndex(primary,869,1.0); //crits become minicrits
				TF2Attrib_SetByDefIndex(primary,42,3.0); //weapon mode
			}
			//Air Strike
			case 1104:
			{
				TF2Attrib_SetByDefIndex(primary,100,0.8); //Blast radius decreased
			}
			//B.A.S.E. Jumper Demo
			case 1101:
			{
				TF2Attrib_SetByDefIndex(primary,610,2.0); //increased air control
				TF2Attrib_SetByDefIndex(primary,135,0.75); //rocket jump damage reduction
			}
			//The Machina
			case 526,30665:
			{
				TF2Attrib_SetByDefIndex(primary,304,1.0); //sniper full charge damage bonus
				TF2Attrib_SetByDefIndex(primary,266,1.0); //projectile penetration
				TF2Attrib_SetByDefIndex(primary,3,0.75); //clip size penalty
			}
			//Force-A-Nature
			case 45,1078:
			{
				TF2Attrib_SetByDefIndex(primary,97,0.85); //Reload time decreased
				TF2Attrib_SetByDefIndex(primary,106,1.0); //spread bonus
			}
			//Soda Popper
			case 448:
			{
				TF2Attrib_SetByDefIndex(primary,97,0.85); //Reload time decreased
				TF2Attrib_SetByDefIndex(primary,793,0.0); //hype on damage
			}
			//Tomislav
			case 424:
			{
				// TF2Attrib_SetByDefIndex(primary,87,0.7/0.814); //minigun spinup time decreased
				TF2Attrib_SetByDefIndex(primary,87,0.7); //minigun spinup time decreased
				TF2Attrib_SetByDefIndex(primary,5,1.3); //fire rate penalty
			}
			//Loose Cannon
			case 996:
			{
				TF2Attrib_SetByDefIndex(primary,207,0.75); //blast dmg to self decreased
			}
			//Backburner
			case 40,1146:
			{
				TF2Attrib_SetByDefIndex(primary,170,2.0); //airblast cost increased
			}
			//Iron Bomber
			case 1151:
			{
				TF2Attrib_SetByDefIndex(primary,100,0.7); //blast radius decreased
				TF2Attrib_SetByDefIndex(primary,787,1.3); //fuse bonus
			}
		}

		switch(secondaryIndex)
		{
			//Pretty Boy's Pocket Pistol
			case 773:
			{
				TF2Attrib_SetByDefIndex(secondary,1,0.8); //damage penalty
			}
			//The Righteous Bison
			case 442:
			{
				TF2Attrib_SetByDefIndex(secondary,2,2.5); //damage bonus
				TF2Attrib_SetByDefIndex(secondary,6,0.8); //firing speed bonus
				TF2Attrib_SetByDefIndex(secondary,335,1.5); //clip size upgrade
				SetEntPropFloat(secondary, Prop_Send, "m_flEnergy", 30.0);
				TF2Attrib_SetByDefIndex(secondary,103,1.5); //projectile speed
			}
			//The Enforcer
			case 460:
			{
				TF2Attrib_SetByDefIndex(secondary,410,1.4); //damage bonus while disguised
				TF2Attrib_SetByDefIndex(secondary,221,0.5); //mult decloak rate
			}
			//Buffalo Steak Sandvich
			case 311:
			{
				TF2Attrib_SetByDefIndex(secondary,798,0.85); //energy buff dmg taken multiplier
			}
			//Dalokohs Bar
			case 159, 433:
			{
				Address addr = TF2Attrib_GetByDefIndex(secondary,26);
				if(addr==Address_Null)
					TF2Attrib_SetByDefIndex(secondary,26,0.0); //max health additive bonus
				else if(TF2Attrib_GetValue(addr)==0.0)
					g_meterSec[iClient] = 0.0;
				TF2Attrib_SetByDefIndex(secondary,139,6.0); //set_weapon_mode
				TF2Attrib_SetByDefIndex(secondary,876,0.8); //lunchbox healing decreased
				TF2Attrib_SetByDefIndex(secondary,801,15.0); //item_meter_charge_rate
			}
			//Jarate, Mad Milk
			case 58,222,1121,1083,1105:
			{
				TF2Attrib_SetByDefIndex(secondary,856,3.0); //meter type
				TF2Attrib_SetByDefIndex(secondary,848,-1.0); //spawn doesn't affect resup
				TF2Attrib_SetByDefIndex(secondary,278,2.0); //recharge rate
				if(secondaryIndex == 222 || secondaryIndex == 1121)
					TF2Attrib_SetByDefIndex(secondary,2059,500.0); //damage to recharge
				if(strcmp(event,"player_spawn") == 0) //reset meter it on spawn
				{
					int iOffset = GetEntProp(secondary, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
					int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
					SetEntData(iClient, iAmmoTable+iOffset, -1, 4, true);//wipe ammo
					SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, 1);
					SetEntPropFloat(secondary, Prop_Send, "m_flLastFireTime",GetGameTime());
					SetEntPropFloat(secondary, Prop_Send, "m_flEffectBarRegenTime",GetGameTime());
				}
			}
			//The Gas Passer
			case 1180:
			{
				TF2Attrib_SetByDefIndex(secondary,801,40.0); //recharge time
				TF2Attrib_SetByDefIndex(secondary,2059,500.0); //damage to recharge
				TF2Attrib_SetByDefIndex(secondary,74,1.0); //burn time
				if(strcmp(event,"player_spawn") == 0)//reset meter it on spawn
					SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, 1);
			}
			//The Razorback
			case 57:
			{
				//set sheild status txt
				SetEntProp(secondary, Prop_Data, "m_fEffects",129);
				SetHudTextParams(-0.1, -0.13, 0.5, 255, 255, 255, 255);
				ShowHudText(iClient,3,"Shield: Intact");
			}
			//Cleaner's Carbine
			case 751:
			{
				TF2Attrib_SetByDefIndex(secondary,106,0.75); //spread bonus
				TF2Attrib_SetByDefIndex(secondary,5,1.2); //fire rate penalty
				TF2Attrib_SetByDefIndex(secondary,780,0.8333); //minicrit boost charge rate
			}
			//Thermal Thruster
			case 1179:
			{
				TF2Attrib_SetByDefIndex(secondary,840,0.4); //holster anim time
				TF2Attrib_SetByDefIndex(secondary,547,0.5); //deploy speed bonus
				TF2Attrib_SetByDefIndex(secondary,780,1.0); //damage force increase hidden
				TF2Attrib_SetByDefIndex(secondary,400,1.0); //cannot pick up intelligence
			}
			//B.A.S.E. Jumper Soldier
			case 1101:
			{
				TF2Attrib_SetByDefIndex(secondary,610,2.0); //increased air control
				TF2Attrib_SetByDefIndex(secondary,135,0.75); //rocket jump damage reduction
			}
			//The Vaccinator
			case 998:
			{
				TF2Attrib_SetByDefIndex(secondary,503,0.0); //bullet resist passive
				TF2Attrib_SetByDefIndex(secondary,504,0.0); //blast resist passive
				TF2Attrib_SetByDefIndex(secondary,505,0.0); //fire resist passive
				TF2Attrib_SetByDefIndex(secondary,506,0.0); //bullet resist deployed
				TF2Attrib_SetByDefIndex(secondary,507,0.0); //blast resist deployed
				TF2Attrib_SetByDefIndex(secondary,508,0.0); //fire resist deployed
			}
			//Darwin's Danger Shield
			case 231:
			{
				TF2Attrib_SetByDefIndex(secondary,26,15.0); //max health additive bonus
				TF2Attrib_SetByDefIndex(secondary,60,1.0); //fire resistance
				TF2Attrib_SetByDefIndex(secondary,527,0.0); //afterburn immunity
				SetEntityHealth(iClient,140);
			}
			//The Diamondback
			case 525:
			{
				TF2Attrib_SetByDefIndex(secondary,296,0.0); //sapper kills collect crits
				TF2Attrib_SetByDefIndex(secondary,1,1.0); //damage penalty
				TF2Attrib_SetByDefIndex(secondary,3,0.67); //clip size penalty
				int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
				SetEntData(secondary, iAmmoTable, 4, _, true);
				TF2_RemoveCondition(iClient,TFCond_Kritzkrieged);
			}
			//Detonator
			case 351:
			{
				TF2Attrib_SetByDefIndex(secondary,207,1.2); //self blast damge increased
			}
			//Short Circuit
			case 528:
			{
				TF2Attrib_SetByDefIndex(secondary,2,2.0); //damage bonus
				TF2Attrib_SetByDefIndex(secondary,614,1.0); //no metal from dispensers while active
			}
			//Buff Banner
			case 129,1001:
			{
				TF2Attrib_SetByDefIndex(secondary,76,1.5); //maxammo primary increased
			}
			//Scorch Shot
			case 740:
			{
				TF2Attrib_SetByDefIndex(secondary,1,0.85); //damage penalty
				TF2Attrib_SetByDefIndex(secondary,59,1.0); //self dmg push force decreased
			}
			// Manmelter
			case 595:
			{
				TF2Attrib_SetByDefIndex(secondary,1,0.8); //damage penalty
				TF2Attrib_SetByDefIndex(secondary,6,0.67); //fire rate bonus
				TF2Attrib_SetByDefIndex(secondary,74,0.6); //weapon burn time reduced
			}
			//Quick-Fix
			case 411:
			{
				TF2Attrib_SetByDefIndex(secondary,10,1.33); //ubercharge rate bonus
			}
		}

		// add 3-hit crit combo to (most) melee weapons - exemptions including swords & knives or those with "no random crits" and/or situational (mini)crits; KGB, SoaS, Skullcutter, atomizer made exempt
		switch(meleeIndex)
		{
			case 349,43,357,416,38,1000,457,813,834,307,132,172,266,327,404,482,1082,155,232,450,37,1003:
			{
				g_consecHits[iClient] = -1; //at -1, the consecutive hits won't be counted
				TF2Attrib_SetByDefIndex(melee,15,0.0); //crit mod disabled
				switch(meleeIndex) //specific melee changes
				{
					//The Eyelander
					case 132,266,482,1082:
					{
						TF2Attrib_SetByDefIndex(melee,249,0.75); //shield recharge rate
						TF2Attrib_SetByDefIndex(melee,79,0.25); //maxammo secondary reduced
						TF2Attrib_SetByDefIndex(melee,736,3.0); //speed_boost_on_kill
						//reset head boost on spawn or retain on resup
						int heads = GetEntProp(iClient, Prop_Send, "m_iDecapitations");
						if(strcmp(event,"player_spawn") == 0)//reset meter it on spawn
							heads = 0;
						DataPack pack = new DataPack();
						pack.Reset();
						pack.WriteCell(iClient);
						pack.WriteCell(heads);
						pack.WriteCell(1);
						CreateTimer(2.0/66,updateHeads,pack);
					}
					//Sun-On-A-Stick
					case 349:
					{
						TF2Attrib_SetByDefIndex(melee,5,1.2); //fire rate penalty
						SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
						ShowHudText(iClient,4,"HEAT: 0%");
						if(strcmp(event,"player_spawn") == 0)
						{
							g_meterMel[iClient] = 0.0;
							g_condFlags[iClient] |= TF_CONDFLAG_HEATSPAWN;
						}
						else
							SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",g_meterMel[iClient],2); //set SOAS HEAT meter
					}
					//Southern Hospitality
					case 155:
					{
						TF2Attrib_SetByDefIndex(melee,61,1.0); //dmg taken from fire increased
						TF2Attrib_SetByDefIndex(melee,345,4.5); //engy dispenser radius increased
						TF2Attrib_SetByDefIndex(melee,81,0.75); //maxammo metal reduced
						TF2Attrib_SetByDefIndex(melee,148,0.745); //building cost reduction
						SetEntData(iClient, FindDataMapInfo(iClient, "m_iAmmo") + (3 * 4), 150, 4);
					}
					//Claidheamh Mor
					case 327:
					{
						TF2Attrib_SetByDefIndex(melee,5,1.2); //fire rate penalty
						TF2Attrib_SetByDefIndex(melee,199,0.5714); //holster speed bonus
						TF2Attrib_SetByDefIndex(melee,412,1.0); //dmg taken increased
					}
					//Persian Persuader
					case 404:
					{
						TF2Attrib_SetByDefIndex(melee,77,0.5); //maxammo primary reduced
						TF2Attrib_SetByDefIndex(melee,79,0.5); //maxammo secondary reduced
					}
					//The Ubersaw
					case 37,1003:
					{
						TF2Attrib_SetByDefIndex(melee,128,1.0); //provide while active
						TF2Attrib_SetByDefIndex(melee,5,1.25); //fire rate penalty
						TF2Attrib_SetByDefIndex(melee,547,0.8); //deploy speed bonus
						TF2Attrib_SetByDefIndex(melee,412,1.25); //dmg taken increased
					}
					//Scotsman's skullcutter
					case 172:
					{
						TF2Attrib_SetByDefIndex(melee,249,1.25); //shield recharge rate
					}
					//The Axtinguisher
					case 38,457,1000:
					{
						g_holsterMel[iClient] = 1.35;
						TF2Attrib_SetByDefIndex(melee,772,1.0); //single wep holster time increased
					}
					//Ullapool Caber
					case 307:
					{
						float gameTime = GetGameTime();
						SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
						ShowHudText(iClient,4,"Caber: 100 %");
						SetEntPropFloat(melee, Prop_Send, "m_flLastFireTime",gameTime);
					}
					//Neon Annihilator
					case 813, 834:
					{
						float gameTime = GetGameTime();
						TF2Attrib_SetByDefIndex(melee,146,0.0); //damage applies to sappers
						TF2Attrib_SetByDefIndex(melee,773,1.5); //deploy time increased
						TF2Attrib_SetByDefIndex(melee,264,1.5); //melee range multiplier
						SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
						SetEntProp(melee, Prop_Send, "m_bBroken",0);
						ShowHudText(iClient,4,"Charge: 100 %");
						SetEntPropFloat(melee, Prop_Send, "m_flLastFireTime",gameTime-40.0);
					}
				}
			}
			default:
			{
				if(TF2_GetPlayerClass(iClient) == TFClass_Spy)
				{
					g_consecHits[iClient] = -1;
					switch(meleeIndex)
					{
						//Your Eternal Reward
						case 225,574:
						{
							TF2Attrib_SetByDefIndex(watch,84,1.2); //cloak regen rate increased
							TF2Attrib_SetByDefIndex(melee,34,1.0); //cloak drain penalty
						}
						default:
						{
							TF2Attrib_SetByDefIndex(watch,84,1.0); //cloak regen rate increased
							switch(meleeIndex)
							{
								//Conniver's Kunai
								case 356:
								{
									TF2Attrib_SetByDefIndex(melee,217,0.0); //sanguisuge
									TF2Attrib_SetByDefIndex(melee,125,-30.0); //max health additive penalty
									if(GetClientHealth(iClient)<95)
										SetEntityHealth(iClient,95);
								}
								//The Spy-cicle
								case 649:
								{
									TF2Attrib_SetByDefIndex(melee,359,0.0); //melts in fire
									TF2Attrib_SetByDefIndex(melee,361,0.0); //become fireproof on hit by fire
									SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",100.0,2); //durability meter
									SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
									ShowHudText(iClient,4,"Spy-Cicle: 100%");
									SetEntPropFloat(melee, Prop_Send, "m_flLastFireTime",GetGameTime());
								}
							}
						}
					}
				}
				else g_consecHits[iClient] = 0;
				switch(meleeIndex) //other melee changes
				{
					//Warrior's Spirit
					case 310:
					{
						SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",100.0,2);
						TF2Attrib_SetByDefIndex(melee,412,1.0); //dmg taken increased
						// TF2Attrib_SetByDefIndex(melee,2,1.355); //damage bonus
						// TF2Attrib_SetByDefIndex(melee,5,1.25); //fire rate penalty
					}
					//The Equalizer
					case 128:
					{
						// TF2Attrib_SetByDefIndex(melee,115,0.0); //mod shovel damage boost
						TF2Attrib_SetByDefIndex(melee,224,1.4); //increase damage below 50% HP
						TF2Attrib_SetByDefIndex(melee,225,0.8); //decrease damage above 50% HP
						TF2Attrib_SetByDefIndex(melee,205,0.8); //damage from range
						TF2Attrib_SetByDefIndex(melee,252,0.8); //damage force reduction
						TF2Attrib_SetByDefIndex(melee,5,1.2); //fire rate penalty
					}
					//Eviction Notice
					case 426:
					{
						TF2Attrib_SetByDefIndex(melee,1,0.55); //damage penalty
						TF2Attrib_SetByDefIndex(melee,855,0.0); //max health drain
						TF2Attrib_SetByDefIndex(melee,412,1.25); //damage taken increased
						TF2Attrib_SetByDefIndex(melee,547,0.8); //deploy speed bonus
						TF2Attrib_SetByDefIndex(melee,128,1.0); //provide while active
					}
					//The Sandman
					case 44:
					{
						TF2Attrib_SetByDefIndex(melee,278,1.0); //effect bar recharge rate
					}
					//Candy Cane
					case 317:
					{
						TF2Attrib_SetByDefIndex(melee,65,1.0); //dmg taken from blast 
						TF2Attrib_SetByDefIndex(melee,69,0.25); //health from healers reduced
						TF2Attrib_SetByDefIndex(melee,800,0.5); //patient overheal penalty
					}
					//Tribalman's shiv
					case 171:
					{
						TF2Attrib_SetByDefIndex(melee,149,8.0); //bleeding duration
						TF2Attrib_SetByDefIndex(melee,877,2.0); //speed boost on hit enemy
						TF2Attrib_SetByDefIndex(melee,797,1.0); //dmg pierces resists absorbs
					}
					//Fan O'War
					case 355:
					{
						TF2Attrib_SetByDefIndex(melee,199,0.75); //holster speed bonus
					}
					//Sharpened Volcano Fragment
					case 348:
					{
						TF2Attrib_SetByDefIndex(melee,773,1.35); //single wep deploy time increased
					}
					//Hot Hand
					case 1181:
					{
						TF2Attrib_SetByDefIndex(melee,1,1.0); //damage penalty
						TF2Attrib_SetByDefIndex(melee,877,3.0); //speed boost on hit enemy
					}
					//Third Degree
					case 593:
					{
						TF2Attrib_SetByDefIndex(melee,1,0.67); //damage penalty
						TF2Attrib_SetByDefIndex(melee,110,30.0); //heal on hit for slowfire
						TF2Attrib_SetByDefIndex(melee,69,0.25); //health from healers reduced 
						TF2Attrib_SetByDefIndex(melee,360,0.0); //damage all connected
					}
					//The Vita-Saw
					case 173:
					{
						TF2Attrib_SetByDefIndex(melee,811,0.001); //ubercharge_preserved
					}
					//The Shahanshah
					case 401:
					{
						TF2Attrib_SetByDefIndex(melee,547,0.75); //deploy speed bonus
					}
					//The Jag
					case 329:
					{
						TF2Attrib_SetByDefIndex(melee,95,0.67); //repair rate decreased
					}
					//Gloves of Running Urgently
					case 239,1084,1100:
					{
						g_holsterMel[iClient] = 1.5;
						TF2Attrib_SetByDefIndex(melee,772,1.0); //single wep holster time increased
					}
					//Fists of Steel
					case 331:
					{
						g_holsterMel[iClient] = 2.0;
						TF2Attrib_SetByDefIndex(melee,772,1.0); //single wep holster time increased
					}
					//The Homewrecker
					case 153,466:
					{
						TF2Attrib_SetByDefIndex(melee,128,1.0); //provide while active
						TF2Attrib_SetByDefIndex(melee,205,0.8); //damage from range
						TF2Attrib_SetByDefIndex(melee,252,0.5); //damage force reduction
						g_holsterMel[iClient] = 2.0;
						TF2Attrib_SetByDefIndex(melee,772,1.0); //single wep holster time increased
					}
					//The Amputator
					case 304:
					{
						TF2Attrib_SetByDefIndex(melee,1,0.75); //damage penalty
					}
				}
			}
		}

		//Dead Ringer
		if(watchIndex == 59)
		{
			TF2Attrib_SetByDefIndex(watch,35,2.0); //mult cloak meter regen rate
		}

		//reset variables for client on spawn
		if(meleeIndex != 349) g_meterMel[iClient] = 0.0;
		if(secondaryIndex != 159 && secondaryIndex != 433) g_meterSec[iClient] = 0.0;
		if(primaryIndex != 811 && primaryIndex != 832) g_meterPri[iClient] = 0.0;
		g_lastFire[iClient] = 0.0;
		g_meleeStart[iClient] = 0.0;
		g_lastHit[iClient] = 0.0;
		g_nextHit[iClient] = 0.0;
		g_lastFlamed[iClient] = 0.0;
		g_temperature[iClient] = 0.5;
		g_condFlags[iClient] = 0;
		g_lastHeal[iClient] = 0;
		g_lockOn[iClient] = 0;
		g_holstering[iClient] = false;
		// g_Grenades[iClient][0]=0;g_Grenades[iClient][2]=0;g_Grenades[iClient][2]=0;g_Grenades[iClient][3]=0;g_Grenades[iClient][4]=0;
		// g_Grenades[iClient][5]=0;g_Grenades[iClient][6]=0;g_Grenades[iClient][7]=0;g_Grenades[iClient][8]=0;g_Grenades[iClient][9]=0;
		
		if(StrContains(event,"player_spawn") != -1) g_Fov[iClient] = GetEntProp(iClient, Prop_Send, "m_iFOV");
		SetEntProp(iClient, Prop_Send, "m_iFOV", g_Fov[iClient]);
		TF2Attrib_SetByDefIndex(iClient,69,1.0); //set attr indexes for third degree
		SetEntityGravity(iClient,1.0); //reset jetpack gravity;
	}
	return Plugin_Changed;
}

public Action Event_PlayerDeath(Event event, const char[] cName, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	int victim = event.GetInt("victim_entindex");
	int weaponIndex = event.GetInt("weapon_def_index");
	int customKill = event.GetInt("customkill");
	int inflict = event.GetInt("inflictor_entindex");


	if(IsValidClient(attacker))
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
					case 38,457,1000: //axtinguisher
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
						TF2_AddCondition(attacker,TFCond_SpeedBuffAlly,3.1);
					}
					case 357: //half-zatoichi
					{
						int maxHealth = 200;
						if(TF2_GetPlayerClass(attacker)==TFClass_DemoMan && primaryIndex != 405 && primaryIndex != 608)
							maxHealth = 175;
						if(TF2_GetPlayerClass(attacker)==TFClass_Soldier && secondaryIndex != 226)
							maxHealth = 220;
						int currHealth = GetClientHealth(attacker);

						float healing = maxHealth/2+currHealth > maxHealth*1.5 ? maxHealth*1.5-currHealth : maxHealth/2.0;
						SetHudTextParams(0.1, -0.16, 0.1, 255, 255, 255, 255);
						ShowHudText(attacker,4,"+%.0f HP",healing);
						TF2Util_TakeHealth(attacker,healing,TAKEHEALTH_IGNORE_MAXHEALTH);
					}
					case 327: //claidheamh mor
					{
						addCharge += 25;
					}
					case 43: //KGB
					{
						TF2_AddCondition(attacker,TFCond_CritOnKill,5.1);
					}
					case 310: //warrior's spirit
					{
						SetHudTextParams(0.1, -0.16, 0.1, 255, 255, 255, 255);
						ShowHudText(attacker,4,"+50 HP");
						TF2Util_TakeHealth(attacker,50.0);
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
			if(inflict == secondary) //shield bash kills
			{
				float addCharge = 0.0;
				if(primaryIndex == 405 || primaryIndex == 608) addCharge += 25; //add booties on-kill
				if(secondaryIndex == 1099) addCharge += 75; //add tide turner on-kill
				if(meleeIndex == 327) addCharge += 25; //add claid on-kill

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
				SetEntPropFloat(secondary, Prop_Send, "m_flLastFireTime", secondaryLast-4.0);
				float secondaryRegen = GetEntPropFloat(secondary, Prop_Send, "m_flEffectBarRegenTime");
				SetEntPropFloat(secondary, Prop_Send, "m_flEffectBarRegenTime", secondaryRegen-4.0);
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
			TF2_AddCondition(attacker,TFCond_CritCola,5.1);
		}
		
		switch(weaponIndex)
		{
			case 811,832: //Heater explode on kill
			{
				float toggle = TF2Attrib_GetValue(TF2Attrib_GetByDefIndex(primary,430));
				if (toggle==12.0)
				{
					g_condFlags[victim] |= TF_CONDFLAG_HEATER;
					float targetPos[3], victimPos[3];
					GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
					EmitAmbientSound("misc/halloween/spell_fireball_impact.wav",victimPos,victim);
					CreateParticle(victim,"ExplosionCore_MidAir_Flare",5.0,_,_,_,_,100.0,1.5,false);
					for (int i = 1 ; i <= MaxClients ; i++)
					{
						if(IsClientInGame(i) && i!=victim && !(g_condFlags[i] & TF_CONDFLAG_HEATER))
						{
							if(IsPlayerAlive(i))
							{
								GetEntPropVector(i, Prop_Send, "m_vecOrigin", targetPos);
								float dist = GetVectorDistance(victimPos,targetPos);
								if(victim != i && dist<=146 && TF2_GetClientTeam(i) != TF2_GetClientTeam(attacker))
								{
									SDKHooks_TakeDamage(i, attacker, attacker, 15.0, DMG_IGNITE | DMG_BURN, primary, NULL_VECTOR, targetPos);
									if(TF2_GetPlayerClass(i) != TFClass_Pyro) TF2Util_SetPlayerBurnDuration(i,4.0);
								}
							}
						}
					}
				}
			}
			case 310: //reset warrior's spirit honorbound on kill
			{
				SetEntPropFloat(attacker, Prop_Send,"m_flItemChargeMeter",100.0,2);
			}
			case 132,266,482,1082: //eyelander
			{
				//adjust max health on kill
				int heads = GetEntProp(attacker, Prop_Send, "m_iDecapitations");
				DataPack pack = new DataPack();
				pack.Reset();
				pack.WriteCell(attacker);
				pack.WriteCell(heads);
				pack.WriteCell(0);
				CreateTimer(2.0/66,updateHeads,pack);
			}
			case 356: //Kunai health on kill
			{
				if(customKill == TF_CUSTOM_BACKSTAB)
				{
					//current user HP
					float current = GetClientHealth(attacker) + 0.0;
					//get health of user before death, can be calculated since backstab does 6x current health in damage
					float health = GetClientHealth(victim)/-5.0;
					//bind amount gained between 45 and 190
					health = current > 95 ? health/3.0 : 2.0*health/3.0; //give 2/3 targets health at <=90 current HP, else give 1/3 targets health
					health = health < KUNAI_MIN ? KUNAI_MIN : health; //45 minimum
					health = current + health > KUNAI_MAX ? KUNAI_MAX - current : health; //cap HP at 190
					DataPack pack = new DataPack();
					pack.Reset();
					pack.WriteCell(attacker);
					pack.WriteFloat(health);
					// CreateTimer(0.09,KunaiTimer,pack,TIMER_REPEAT);
					SetHudTextParams(0.1, -0.16, 0.1, 255, 255, 255, 255);
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
						MeltKnife(attacker,melee,10.0);
				}
			}
		}

		//marked speed buff for Fan of War
		if(TF2Util_GetPlayerConditionProvider(victim,TFCond_MarkedForDeath)==attacker)
		{
			TF2_AddCondition(attacker,TFCond_SpeedBuffAlly,3.1);
		}
	}
	
	if(g_condFlags[victim] & TF_CONDFLAG_VOLCANO) //sharpened volcano, if player hit while burning dies they explode
	{
		int burner = TF2Util_GetPlayerConditionProvider(victim,TFCond_OnFire);
		int burnerMelee = TF2Util_GetPlayerLoadoutEntity(burner, TFWeaponSlot_Melee, true);
		float targetPos[3], victimPos[3];
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
		EmitAmbientSound("misc/halloween/spell_fireball_impact.wav",victimPos,victim);
		CreateParticle(victim,"ExplosionCore_MidAir_Flare",5.0,_,_,_,_,100.0,1.5,false);
		for (int i = 1 ; i <= MaxClients ; i++)
		{
			if(IsClientInGame(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", targetPos);
				float dist = GetVectorDistance(victimPos,targetPos);
				if(victim != i && dist<=125 && TF2_GetClientTeam(i) != TF2_GetClientTeam(burner))
				{
					SDKHooks_TakeDamage(i, burner, burner, 18.0, DMG_IGNITE | DMG_BURN, burnerMelee, NULL_VECTOR, targetPos);
					if(TF2_GetPlayerClass(i) != TFClass_Pyro) TF2Util_SetPlayerBurnDuration(i,7.5);
				}
			}
		}
		g_condFlags[victim] &= ~TF_CONDFLAG_VOLCANO;
	}

	return Plugin_Continue;
}

public Action Event_BuildObject(Event event, const char[] cName, bool dontBroadcast)
{
	int user = GetClientOfUserId(GetEventInt(event, "userid"));
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
					TF2_AddCondition(user,TFCond_SpeedBuffAlly,3.1);
				}
			}
		}
	}
	return Plugin_Continue;
}

public void OnGameFrame()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		int iClient = i;
		if (IsClientInGame(i) && IsPlayerAlive(i))
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
			int current = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");

			if(GetGameTime() - g_lastFlamed[iClient] > 6.0/66 && g_temperature[iClient]>0.5) //client temperature from flamethrowers
			{
				g_temperature[iClient] *= 0.971875; //25 frames to decrease to 0, 31 frames total including grace period
				if(g_temperature[iClient]<0.5) g_temperature[iClient] = 0.5;
			}

			if(g_condFlags[iClient] & TF_CONDFLAG_FANHIT || g_condFlags[iClient] & TF_CONDFLAG_FANFLY) //track force-a-nature knockback
			{
				if(clientFlags & FL_ONGROUND)
				{
					g_condFlags[iClient] &= ~TF_CONDFLAG_FANHIT;
					g_condFlags[iClient] &= ~TF_CONDFLAG_FANFLY;
				}
			}

			//count airtime until pyro can jetpack boost
			if(g_condFlags[iClient] & TF_CONDFLAG_HOVER)
			{
				g_meterSec[iClient] -= 1.0/66;
				if((clientFlags & FL_ONGROUND) || g_meterSec[iClient] < HOVER_TIME)
				{
					SetEntityGravity(iClient,1.0);
					g_meterSec[iClient] = 0.0;
					g_condFlags[iClient] &= ~TF_CONDFLAG_HOVER;
				}
				else if(secondaryIndex == 1179 && g_meterSec[iClient] > -1)
					g_meterSec[iClient] += 0.1;
			}
			//count airtime for BASE Jumper
			if(secondaryIndex == 1101 || primaryIndex == 1101)
			{
				if(TF2_IsPlayerInCondition(iClient,TFCond_Parachute))
				{
					g_meterSec[iClient] += 1.0/66;
					SetHudTextParams(-1.0, -0.4, 0.1, 255, 255, 255, 255);
					ShowHudText(iClient,3,"%.0f%% CHUTE",(PARACHUTE_TIME-g_meterSec[iClient])*100/PARACHUTE_TIME);

					if((clientFlags & FL_ONGROUND) || g_meterSec[iClient] > PARACHUTE_TIME)
					{
						TF2_RemoveCondition(iClient,TFCond_Parachute);
						TF2_AddCondition(iClient,TFCond_ParachuteDeployed);
					}
				}
				else if(TF2_IsPlayerInCondition(iClient,TFCond_ParachuteDeployed))
					g_meterSec[iClient] = 0.0;
			}

			switch(TF2_GetPlayerClass(iClient))
			{
				case TFClass_Scout:
				{
					switch(meleeIndex)
					{
						case 349:
						{
							float meter = GetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",2);
							if(g_condFlags[iClient] & TF_CONDFLAG_HEATSPAWN) //makes sure HEAT resets post-spawn
							{
								g_condFlags[iClient] &= ~TF_CONDFLAG_HEATSPAWN;
								SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",0.0,2);
							}
							
							//update HEAT meter
							if(g_condFlags[iClient] & TF_CONDFLAG_HEAT)
							{
								meter -= 1.0/3.96;
								SetHudTextParams(-0.1, -0.1, 0.5, 255, 50, 50, 255);
								if(meter<=0.0)
								{
									meter = 0.0;
									g_condFlags[iClient] &= ~TF_CONDFLAG_HEAT;
									SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
								}
								g_meterMel[iClient] = meter;
								SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",meter,2);
							}
							else
								SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
							
							ShowHudText(iClient,4,"HEAT: %.0f%",meter);
						}
					}
				}
				case TFClass_Pyro:
				{
					if(primaryIndex != 594 && primaryIndex !=1) //handle airblast, except for dragon's fury and phlog
					{
						float meter = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0);
						float meter2 = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 10);
						int weaponState = GetEntProp(primary, Prop_Send, "m_iWeaponState");
						if(weaponState==3) //in-airblast
						{
							if((primaryIndex != 1178 && meter2 < meter) || (primaryIndex == 1178 && meter == 0.0)) //done to make limit it to first frame in this state
							{
								if(!(clientFlags & FL_ONGROUND)) AirblastPush(iClient);
								if(primaryIndex != 1178)
								{
									meter-=33.0;
									if(meter<0.0) meter = 0.0;
									//update pressure meter
									SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", meter, 0);
									SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", meter, 10);
									TF2Attrib_SetByDefIndex(primary,255,0.5+meter/200); //set next airblast force
								}
							}
						}
						else if(weaponState!=3 && primaryIndex != 1178) //out of airblast
						{
							//update pressure meter
							if(meter<100.0) SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", meter+100.0/(66*PRESSURE_TIME), 0);
							else if(meter>100.0) SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 100.0, 0);
							//update force of airblast in increments
							int force = RoundToNearest(meter);
							if(force % 5 == 0) TF2Attrib_SetByDefIndex(primary,255,0.5+meter/200);
						}
						SetHudTextParams(-0.1, -0.16, 0.5, 255, 255, 255, 255);
						ShowHudText(iClient,2,"%.0f%% PRESSURE",meter);
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
						}
					}
					switch(meleeIndex)
					{
						case 813, 834: //check Neon Annihilator state
						{
							float gameTime = GetGameTime();
							int broken = GetEntProp(melee, Prop_Send, "m_bBroken");
							float lastTime = GetEntPropFloat(melee, Prop_Send, "m_flLastFireTime");
							if(broken==1)
							{
								int charge = RoundToFloor((gameTime-lastTime)/40.0 * 100);
								SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
								ShowHudText(iClient,4,"Charge: %d %",charge);
								if(gameTime>lastTime+40)
								{
									SetEntProp(melee, Prop_Send, "m_bBroken",0);
								}
							}
						}
					}
				}
				case TFClass_DemoMan:
				{
					switch(primaryIndex)
					{
						case 308: //loch-n-load reload
						{
							if(GetEntProp(primary, Prop_Send, "m_iReloadMode")==2)
							{
								if(GetEntPropFloat(primary, Prop_Send, "m_flNextPrimaryAttack") - GetGameTime() < 0.1)
								{
									int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
									int currAmmo = GetEntProp(iClient, Prop_Data, "m_iAmmo", _, primaryAmmo);
									SetEntProp(primary, Prop_Send, "m_iClip1",currAmmo>1 ? 2 : 1);
									SetEntProp(iClient, Prop_Data, "m_iAmmo", currAmmo>1 ? currAmmo-2 : 0 , _, primaryAmmo);
									SetEntProp(primary, Prop_Send, "m_iReloadMode",3);
									SetEntPropFloat(primary, Prop_Send, "m_flNextPrimaryAttack",GetGameTime()+0.2);
								}
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
							int charge = RoundToFloor((gameTime-lastTime)/60.0 * 100);

							if(detonated==1)
							{
								SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
								ShowHudText(iClient,4,"Caber: %d %",charge);
								switch(broken)
								{
									case 1:
									{
										SetEntPropFloat(melee, Prop_Send, "m_flLastFireTime", gameTime);
										SetEntProp(melee, Prop_Send, "m_bBroken",0);
									}
									case 0:
									{
										if(gameTime>lastTime+60)
										{
											EmitSoundToClient(iClient,"player/recharged.wav");
											SetEntProp(melee, Prop_Send, "m_iDetonated",0);
										}
									}
								}
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
						float cycle = GetEntPropFloat(view, Prop_Data, "m_flCycle");
						if(sequence == 23 && weaponState == 0)
						{
							if(cycle < 0.2) //set idle time faster
							{
								SetEntPropFloat(primary, Prop_Send, "m_flTimeWeaponIdle",GetGameTime()+0.4);
							}
							SetEntPropFloat(view, Prop_Send, "m_flPlaybackRate",1.33); //speed up animation
							g_holsterPri[iClient] = 0.66;
							g_meterPri[iClient] = 0.495;
						}
						
						if(g_meterPri[iClient]>0 && current==primary)
							g_meterPri[iClient] -= 0.015;
						else
						{
							g_holsterPri[iClient] = 1.0;
							g_meterPri[iClient] = 0.0;
						}
						
					}
					switch(secondaryIndex)
					{
						case 311: //update buffalo steak speed
						{
							if(TF2_IsPlayerInCondition(iClient,TFCond_CritCola))
							{
								if(meleeIndex==239||meleeIndex==1084||meleeIndex==1100||TF2_IsPlayerInCondition(iClient,TFCond_SpeedBuffAlly))
									SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",370.0);
							}
						}
						case 159, 433: //dalokohs bar max health
						{
							if(g_meterSec[iClient]>0)
								g_meterSec[iClient]-=0.015;
							else if(g_meterSec[iClient]<0.0)
							{
								g_meterSec[iClient] = 0.0;
								TF2Attrib_SetByDefIndex(secondary,26,0.0); //max health additive bonus
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
								if(lastAttack > g_lastFire[iClient] && g_condFlags[iClient] & TF_CONDFLAG_INFIRE)
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
								if(meter+15>100)
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
									SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",meter+15,0);
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
								float meter = 1.0 - (GetGameTime()-time)/6.0;
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
										g_meterMel[iClient] = 0.0;
										SetEntProp(iClient, Prop_Send, "m_bAllowMoveDuringTaunt",1);
										SetEntProp(iClient, Prop_Send, "m_iTauntIndex",3);
										SetEntProp(iClient, Prop_Send, "m_iTauntConcept",94);
									}
									else g_meterMel[iClient] += 1.0/66;
								}
							}
						}
					}
				}
				case TFClass_Sniper:
				{
					//sniper rifle reload
					if(primaryIndex!=56 && primaryIndex!=1005 && primaryIndex!=1092)
					{
						int view = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
						int reload = GetEntProp(primary, Prop_Send, "m_iReloadMode");
						int sequence = GetEntProp(view, Prop_Send, "m_nSequence");
						if(sequence==29 || sequence==28) //in case of last shot in clip, allows for auto-reload
						{
							float cycle = GetEntPropFloat(view, Prop_Data, "m_flCycle");
							if (cycle>=1.0) SetEntProp(view, Prop_Send, "m_nSequence",30);
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
								SetEntPropFloat(view, Prop_Data, "m_flCycle",g_meterPri[iClient]); //1004
								SetEntDataFloat(view, 1004,g_meterPri[iClient], true); //1004
								if(g_meterPri[iClient]/reloadSpeed>0.1)
								{
									EmitAmbientSound("weapons/widow_maker_pump_action_forward.wav",clientPos,iClient,SNDLEVEL_TRAIN,_,0.4);
									SetEntProp(primary, Prop_Send, "m_iReloadMode",2);
								}
							}else if(reload==2)
							{
								if(sequence!=relSeq) SetEntProp(view, Prop_Send, "m_nSequence",relSeq);
								SetEntPropFloat(view, Prop_Data, "m_flCycle",g_meterPri[iClient]); //1004
								SetEntDataFloat(view, 1004,g_meterPri[iClient], true); //1004
								if(g_meterPri[iClient]/reloadSpeed>0.4)
								{
									EmitAmbientSound("weapons/revolver_reload_cylinder_arm.wav",clientPos,iClient,SNDLEVEL_TRAIN,_,0.4);
									SetEntProp(primary, Prop_Send, "m_iReloadMode",3);
								}
							}else if(reload==3)
							{
								if(sequence!=relSeq) SetEntProp(view, Prop_Send, "m_nSequence",relSeq);
								SetEntPropFloat(view, Prop_Data, "m_flCycle",g_meterPri[iClient]); //1004
								SetEntDataFloat(view, 1004,g_meterPri[iClient], true); //1004
								if(g_meterPri[iClient]/reloadSpeed>0.8)
								{
									EmitAmbientSound("weapons/widow_maker_pump_action_back.wav",clientPos,iClient,SNDLEVEL_TRAIN,_,0.4);
									SetEntProp(primary, Prop_Send, "m_iReloadMode",4);
								}
							}

							g_meterPri[iClient] += 1.0/66;
						}
					}
					switch(secondaryIndex)
					{
						case 231: //Danger shield reducing afterburn time
						{
							float burntime = TF2Util_GetPlayerBurnDuration(iClient);
							burntime -= 0.0105;
							TF2Util_SetPlayerBurnDuration(iClient,burntime);
						}
						case 57: //razorback status
						{
							int flags = GetEntProp(secondary, Prop_Data, "m_fEffects"); //129 = intact, 161 = broken
							SetHudTextParams(-0.1, -0.13, 0.5, 255, 255, 255, 255);
							if(flags==129) ShowHudText(iClient,3,"Shield: Intact");
							if(flags==161) ShowHudText(iClient,3,"Shield: Broken");
						}
					}
				}
				case TFClass_Spy:
				{
					// spy radar
					float meter = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 1);
					if(meter<100.0) { meter+=1.0/20; SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", meter, 1); }
					if(meter>100.0) meter=100.0;
					SetHudTextParams(-0.1, -0.13, 0.5, 255, 255, 255, 255);
					ShowHudText(iClient,3,"RADAR %.0f%%",meter);

					switch(meleeIndex)
					{
						case 649: //spy-cicle
						{
							//update hud and meter
							SetHudTextParams(-0.1, -0.1, 0.5, 255, 255, 255, 255);
							int melted = GetEntProp(melee, Prop_Send,"m_bKnifeExists");
							float dur = GetEntPropFloat(melee, Prop_Send,"m_flKnifeRegenerateDuration");
							float time = GetEntPropFloat(melee, Prop_Send,"m_flKnifeMeltTimestamp");
							if(melted==0 && dur+time > GetGameTime())
								ShowHudText(iClient,4,"Spy-Cicle: MELTED");
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
								g_meterMel[iClient] -= 0.015; //reduce resistance time
								if(g_meterMel[iClient] <= 0) //reset if time's up
								{
									g_meterMel[iClient] = 0.0;
									g_condFlags[iClient] &= ~TF_CONDFLAG_INFIRE;
								}

								// reducing afterburn time
								float burntime = TF2Util_GetPlayerBurnDuration(iClient);
								burntime -= 0.0225;
								TF2Util_SetPlayerBurnDuration(iClient,burntime);
							}
						}
					}
				}
			}
		}
	} 
}

public Action TF2_OnAddCond(int iClient,TFCond &condition,float &time, int &provider)
{
	TFClassType tfClientClass = TF2_GetPlayerClass(iClient);
	// TFTeam team  = TF2_GetClientTeam(iClient);
	
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
		}
		case TFClass_Pyro:
		{
			switch(condition)
			{
				case TFCond_MegaHeal,TFCond_UberchargedCanteen:
				{
					if(TF2_IsPlayerInCondition(iClient,TFCond_CritMmmph) && 2.6>=time>=2.5)
					{
						time=1.74; //speed up invuln from phlog taunt
					}
				}
				case TFCond_CritMmmph:
				{
					int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
					TF2Attrib_SetByDefIndex(primary,2,1.30); //phlog damage bonus
				}
			}
		}
		case TFClass_Heavy:
		{
			if(condition == TFCond_CritCola) //steak resistances & duration
			{
				time = 20.0;
				TF2Attrib_SetByDefIndex(iClient,252,0.5);
				TF2Attrib_SetByDefIndex(iClient,329,0.5);
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
				case TFCond_Jarated,TFCond_Bleeding,TFCond_Milked,TFCond_MarkedForDeath,TFCond_MarkedForDeathSilent,TFCond_Gas:
				{
					if(secondaryIndex==231)
						time *= 0.667;
					if(meleeIndex==649 && g_condFlags[iClient] & TF_CONDFLAG_INFIRE)
						time *= 0.25;
				}
			}
		}
		case TFClass_Medic:
		{
			//vita-saw attributes
			if(condition == TFCond_CritHype)
			{
				int organs = GetEntProp(iClient, Prop_Send, "m_iDecapitations");
				
				float buff = 0.33;//organs * 0.11 > 0.33 ? 0.33 : organs * 0.11;
				organs -= 1;
				// organs = organs - 3 < 0 ? 0 : organs - 3;
				SetEntProp(iClient, Prop_Send, "m_iDecapitations", organs);

				int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
				int primaryIndex = -1;
				if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
				int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
				int secondaryIndex = -1;
				if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
				int melee = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Melee, true);
				int meleeIndex = -1;
				if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");

				TF2Attrib_SetByDefIndex(primary,97,1.0-buff);//reload speed
				switch(primaryIndex) //deploy speed
				{
					case 412: TF2Attrib_SetByDefIndex(primary,178,0.8*(1.0-buff));
					default: TF2Attrib_SetByDefIndex(primary,178,1.0*(1.0-buff));
				}
				TF2Attrib_SetByDefIndex(primary,6,1.0-buff);//fire rate

				switch(secondaryIndex)//heal rate
				{
					case 411: TF2Attrib_SetByDefIndex(secondary,8,1.4*(1.0+buff));
					default: TF2Attrib_SetByDefIndex(secondary,8,1.0+buff);
				}
				TF2Attrib_SetByDefIndex(secondary,178,1.0-buff);//deploy speed
				
				TF2Attrib_SetByDefIndex(melee,6,1.0*(1.0-buff));//fire rate
				TF2Attrib_SetByDefIndex(melee,178,1.0*(1.0-buff));//deploy speed
				if(meleeIndex == 173) TF2Attrib_SetByDefIndex(melee,811,0.0);//organ collecting

				CreateTimer(4.0,debuffVita,iClient);
			}
		}
		
	}
	switch (condition)
	{
		case TFCond_OnFire: //healing debuff on ALL afterburn
		{
			DataPack pack = new DataPack();
			pack.Reset();
			pack.WriteCell(iClient);
			pack.WriteCell(provider);
			pack.WriteFloat(time);
			CreateTimer(0.015,FireDebuff,pack);
		}
		case TFCond_HalloweenCritCandy: //disable crit pumpkins
		{
			return Plugin_Handled;
		}
		case TFCond_FocusBuff: //reset Heatmaker tracer
		{
			int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
			TF2Attrib_SetByDefIndex(primary,144,1.0);
			TF2Attrib_SetByDefIndex(primary,51,1.0);
		}
		case TFCond_Jarated:
		{
			if(time<3.0) //set sleeper jarate time to 3 secs minimum
				time=3.0;
		}
		case TFCond_UberFireResist,TFCond_UberBulletResist,TFCond_UberBlastResist:
		{
			time = 2.6; //update time
			float interval = 0.1;
			int flag = 0;
			if(!(g_condFlags[iClient] & TF_CONDFLAG_VACCMIN))
				flag = TF_CONDFLAG_VACCMIN;
			else if(!(g_condFlags[iClient] & TF_CONDFLAG_VACCMED))
				flag = TF_CONDFLAG_VACCMED;
			else if(!(g_condFlags[iClient] & TF_CONDFLAG_VACCMAX))
				flag = TF_CONDFLAG_VACCMAX;
			else
				return Plugin_Handled;
			
			DataPack pack = new DataPack();
			pack.Reset();
			pack.WriteCell(iClient);
			pack.WriteCell(flag);
			pack.WriteFloat(time);
			pack.WriteFloat(interval);
			CreateTimer(interval,updateVacc,pack,TIMER_REPEAT); //update flags, effects, and attributes for uber, and clear once over
			
			return Plugin_Handled;
		}
		case TFCond_KnockedIntoAir: //mark target to be hit by FaN
		{
			if(g_condFlags[iClient] & TF_CONDFLAG_FANHIT)
			{
				g_condFlags[iClient] |= TF_CONDFLAG_FANFLY;
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
				if(primaryIndex==1104)
				{
					TF2Attrib_SetByDefIndex(primary,100,0.8);
				}
			}
		}
		case TFClass_Pyro:
		{
			switch(condition)
			{
				case TFCond_MegaHeal,TFCond_UberchargedCanteen:
				{
					TF2Attrib_SetByDefIndex(iClient,201,1.0); //deactivate faster animations after phlog taunt/effect
				}
				case TFCond_CritMmmph:
				{
					int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, true);
					TF2Attrib_SetByDefIndex(primary,2,1.0); //reset phlog damage bonus
				}
			}
		}
		case TFClass_Heavy:
		{
			if(condition == TFCond_Taunting)
				TF2Attrib_SetByDefIndex(iClient,201,1.0); //deactivate faster animations after eating steak ends
			else if(condition == TFCond_CritCola) //steak resistances
			{
				TF2Attrib_SetByDefIndex(iClient,252,1.0);
				TF2Attrib_SetByDefIndex(iClient,329,1.0);
			}
		}
		case TFClass_Medic:
		{
			//vita-saw attributes
			if(condition == TFCond_CritHype)
			{
				CreateTimer(0.01,debuffVita,iClient);
			}
		}
	}
	switch(condition)
	{
		case TFCond_OnFire:
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
				SetEntPropFloat(iClient, Prop_Send,"m_flCloakMeter",0.0);
			}
		}
	}
	return Plugin_Changed;
}

public Action OnPlayerRunCmd(int iClient, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	
	bool buttonsModified = false;
	TFClassType tfClientClass = TF2_GetPlayerClass(iClient);
	int clientFlags = GetEntityFlags(iClient);
	int curr = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	// char[] current = new char[64];
	// GetClientWeapon(iClient,current,64);
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
	// int sapperIndex = -1;
	// if(sapper != -1) sapperIndex = GetEntProp(sapper, Prop_Send, "m_iItemDefinitionIndex");

	if((IsClientInGame(iClient) && IsPlayerAlive(iClient)))
	{	
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
				if(primaryIndex==1098) maxClip=6;
				else if(primaryIndex==526 || primaryIndex==30665) maxClip=3;

				int relSeq = 41;
				float altRel = 0.875;
				if(primaryIndex == 851 || primaryIndex == 1098)
				{
					relSeq = 5;
					altRel = 0.5625;
				}

				if(curr==primary)
				{
					if(primaryIndex==56 || primaryIndex==1005 || primaryIndex==1092)
					{
						maxClip = 1;
						if(clip==0 && ammoCount>0 && weapon != 0 && weapon != primary)
						{
							SetEntProp(iClient, Prop_Data, "m_iAmmo", ammoCount-1 , _, primaryAmmo);
							SetEntData(primary, iAmmoTable, 1, 4, true);
							// SetEntPropFloat(primary, Prop_Send, "m_flNextPrimaryAttack", GetGameTime());
						}
					}
					else
					{
						if(((buttons & IN_RELOAD) || clip==0) && reload==0 && (sequence==30 || sequence==33) && clip<maxClip && ammoCount>1)
						{
							g_meterPri[iClient] = 0.0;
							SetEntProp(primary, Prop_Send, "m_iReloadMode",1);
							SetEntProp(view, Prop_Send, "m_nSequence",relSeq);
							SetEntPropFloat(view, Prop_Send, "m_flPlaybackRate",(2.0*altRel)/reloadSpeed);
							if ((TF2_IsPlayerInCondition(iClient,TFCond_Slowed) && primaryIndex!=1098) && !TF2_IsPlayerInCondition(iClient,TFCond_FocusBuff))
								buttons |= IN_ATTACK2;
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
								int newClip = ammoCount-maxClip < 1 ? (ammoCount-maxClip+clip > maxClip ? maxClip : ammoCount-1+clip) : maxClip;
								int newAmmo  = ammoCount-maxClip+clip >= 1 ? ammoCount-maxClip+clip : 1;
								SetEntProp(iClient, Prop_Data, "m_iAmmo", newAmmo , _, primaryAmmo);
								SetEntData(primary, iAmmoTable, newClip, 4, true);
								SetEntProp(primary, Prop_Send, "m_iReloadMode",0);
								SetEntProp(view, Prop_Send, "m_nSequence",30);
								// SetEntityRenderMode(primary, RENDER_NORMAL);
								// SetEntityRenderColor(primary, _, _, _, 255);
								// SetEntityRenderMode(g_customWeapon[iClient], RENDER_TRANSCOLOR);
								// SetEntityRenderColor(g_customWeapon[iClient], _, _, _, 0);
								g_meterPri[iClient] = 0.0;
							}
						}
						else if(TF2_IsPlayerInCondition(iClient,TFCond_FocusBuff) && clip<maxClip)
						{
							int newClip = ammoCount-maxClip < 1 ? (ammoCount-maxClip+clip > maxClip ? maxClip : ammoCount-1+clip) : maxClip;
							int newAmmo  = ammoCount-maxClip+clip >= 1 ? ammoCount-maxClip+clip : 1;
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
							if ((weaponState==0 || weaponState==2) && nextAttack < time){
								SetEntPropFloat(primary, Prop_Send, "m_flNextPrimaryAttack", (time + 1.0));
								SetEntPropFloat(primary, Prop_Send, "m_flNextSecondaryAttack", (time + 0.75));
								Phlog_SecondaryAttack(primary,iClient,angles);
							}
						}
						if((buttons & IN_ATTACK3))
						{
							buttons &= ~IN_ATTACK3;
							buttons |= IN_ATTACK2;
							if(GetEntPropFloat(iClient, Prop_Send, "m_flRageMeter")>=100.0)
								TF2Attrib_SetByDefIndex(iClient,201,1.5); //speed up phlog taunt speed
						}
					}
				}
				// manmelter
				if(secondaryIndex == 595 && curr==secondary)
				{
					// //make sure revenge crits are active
					if(GetEntProp(iClient, Prop_Send, "m_iRevengeCrits")>0 && !isKritzed(iClient))
						TF2_AddCondition(iClient,TFCond_Kritzkrieged,1.0);
				}
				//thruster
				if(1179 == secondaryIndex)
				{
					bool rocketing = GetEntPropFloat(secondary, Prop_Send, "m_flLaunchTime") != 0.0 || TF2_IsPlayerInCondition(iClient,TFCond_RocketPack) || TF2_IsPlayerInCondition(iClient,TFCond_Parachute) || TF2_IsPlayerInCondition(iClient,TFCond_ParachuteDeployed);
					if(!(clientFlags & FL_ONGROUND) && !rocketing &&
					GetEntPropFloat(secondary, Prop_Send, "m_flLaunchTime") == 0.0 && GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 1) > 50)
					{
						if ((buttons & IN_JUMP))
						{
							if (!(g_LastButtons[iClient] & IN_JUMP) && g_meterSec[iClient] == -1.0)
							{
								//activate jetpack boost, consume 50% charge
								g_meterSec[iClient] = -1.33;
								TF2_AddCondition(iClient,TFCond_Dazed,1.0);
								TF2_AddCondition(iClient,TFCond_RocketPack);
								g_condFlags[iClient] |= TF_CONDFLAG_HOVER;
								SetEntityGravity(iClient,0.2);

								float regen = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 1);
								SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",regen-50.0,1);
								float angle = angles[1]*0.01745329;
								if(vel[0] != 0 && vel[1] != 0)
								{
									vel[0] *= 0.71; vel[1] *= 0.71;
								}
								currVel[0] = ((vel[0] * Cosine(angle)) - (-vel[1] * Sine(angle)))*0.75;
								currVel[1] = ((-vel[1] * Cosine(angle)) + (vel[0] * Sine(angle)))*0.75;
								currVel[2] = 225.0;
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
						else if (((g_LastButtons[iClient] & IN_JUMP) || g_meterSec[iClient]>1.0) && g_meterSec[iClient] != -2.0)
							g_meterSec[iClient] = -1.0; //allow player to access boost
					}
				}
			}
			case TFClass_Heavy:
			{
				if((primaryIndex==811||primaryIndex==832) && curr==primary && TF2_IsPlayerInCondition(iClient,TFCond_Slowed)) //Heater controls
				{
					float toggle = TF2Attrib_GetValue(TF2Attrib_GetByDefIndex(primary,430));
					if((buttons & IN_RELOAD) && !(g_LastButtons[iClient] & IN_RELOAD))
					{
						EmitSoundToClient(iClient,"weapons/vaccinator_toggle.wav");
						if(toggle==12.0)
							TF2Attrib_SetByDefIndex(primary,430,0.0);
						else if(toggle==0.0)
							TF2Attrib_SetByDefIndex(primary,430,12.0);
						int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
						float ammo = GetEntProp(iClient, Prop_Data, "m_iAmmo", _, primaryAmmo)/100.0;
						TF2Attrib_SetByDefIndex(primary,431,ammo);
					}
					float ammo = TF2Attrib_GetValue(TF2Attrib_GetByDefIndex(primary,431));
					if((g_LastButtons[iClient] & IN_ATTACK3 || g_LastButtons[iClient] & IN_RELOAD) && ammo > 0.0 && ammo <= 2.0)
					{
						int primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
						SetEntProp(iClient, Prop_Data, "m_iAmmo", RoundFloat(ammo*100)-1, _, primaryAmmo);
						if(toggle==12.0) TF2Attrib_SetByDefIndex(primary,431,4.0);
						else if(toggle==0.0) TF2Attrib_SetByDefIndex(primary,431,0.0);
					}
				}
				if(!(g_LastButtons[iClient] & IN_ATTACK) && buttons & IN_ATTACK && curr == secondary)
				{
					buffSteak(iClient,clientFlags); //speed up steak eating on attack
				}
				if(311 == secondaryIndex && TF2_IsPlayerInCondition(iClient,TFCond_CritCola))
				{
					if(weapon != 0)
					{
						float durr = TF2Util_GetPlayerConditionDuration(iClient,TFCond_CritCola);
						TF2_AddCondition(iClient,TFCond_MarkedForDeath,durr);
						TF2_RemoveCondition(iClient,TFCond_CritCola);
						TF2_RemoveCondition(iClient,TFCond_RestrictToMelee);
					}
				}
			}
			case TFClass_Engineer:
			{
				//short circuit slower alt-fire
				if(secondaryIndex == 528 && curr == secondary)
				{
					float nextAtk2 = GetEntPropFloat(secondary, Prop_Send, "m_flNextSecondaryAttack");
					if(buttons & IN_ATTACK2)
					{
						if(nextAtk2 <= GetGameTime())
							CreateTimer(0.01,shortCircuitAlt,secondary);
						else{
							g_TrueLastButtons[iClient] = buttons;
							buttonsModified = true;
							buttons &= ~IN_ATTACK2;
						}
					}
				}
			}
			case TFClass_DemoMan:
			{
				//mini-crit boost the caber during shield charge
				if (curr == melee && meleeIndex==307 && TF2_IsPlayerInCondition(iClient,TFCond_Charging) && (buttons & IN_ATTACK == IN_ATTACK) && !(g_LastButtons[iClient] & IN_ATTACK == IN_ATTACK))
				{
					float charge = GetEntPropFloat(iClient, Prop_Send, "m_flChargeMeter");
					if((charge<75 && charge>40) || (charge<75 && secondaryIndex==1099))
						TF2_AddCondition(iClient,TFCond_CritCola,0.6);
				}
				switch(meleeIndex)
				{
					case 132,266,482,1082:
					{
						int heads = GetEntProp(iClient, Prop_Send, "m_iDecapitations");
						if(weapon!=0)
						{
							DataPack pack = new DataPack();
							pack.Reset();
							pack.WriteCell(iClient);
							pack.WriteCell(heads);
							pack.WriteCell(0);
							CreateTimer(2.0/66,updateHeads,pack);
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
				//vita-saw alt-fire
				if (curr == melee && meleeIndex==173 &&
				(buttons & IN_ATTACK2 == IN_ATTACK2) && !(g_LastButtons[iClient] & IN_ATTACK2 == IN_ATTACK2) && !TF2_IsPlayerInCondition(iClient,TFCond_CritHype))
				{
					int organs = GetEntProp(iClient, Prop_Send, "m_iDecapitations");
					if(organs > 0)
					{
						TF2_AddCondition(iClient,TFCond_CritHype,4.1);
					}else{
						EmitSoundToClient(iClient,"weapons/medigun_no_target.wav");
					}
				}
				//space out vacc ubers
				if (curr == secondary && secondaryIndex==998)
				{
					if(buttons & IN_ATTACK2 == IN_ATTACK2 && (g_TrueLastButtons[iClient] & IN_ATTACK2 == IN_ATTACK2))
					{
						g_TrueLastButtons[iClient] = buttons;
						buttonsModified = true;
						buttons &= ~IN_ATTACK2;
					}
				}
				else if (curr == secondary && secondaryIndex==411) //quick-fix pop
				{
					if(buttons & IN_ATTACK2 == IN_ATTACK2 && !(g_condFlags[iClient] & TF_CONDFLAG_QUICK))
					{
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
				if((buttons & IN_RELOAD) && curr == sapper && !TF2_IsPlayerInCondition(iClient,TFCond_Cloaked) && !TF2_IsPlayerInCondition(iClient,TFCond_CloakFlicker))
				{
					float meter = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 1);
					if(meter>=100){
						SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, 1);
						EmitAmbientSound("ui/cyoa_ping_in_progress.wav",position,iClient,SNDLEVEL_MINIBIKE,_,2.5);
						SetEntProp(iClient, Prop_Send, "m_bGlowEnabled", 1);
						CreateTimer(3.0,updateGlow,iClient);
						int idx, currEnts = GetMaxEntities();
						for (idx = 1; idx < currEnts; idx++) {
							if(idx<=MaxClients) //find enemy players
							{
								if (IsClientInGame(idx) && idx != iClient) {
									if (IsPlayerAlive(idx) && GetClientTeam(idx) != GetClientTeam(iClient) && !TF2_IsPlayerInCondition(idx,TFCond_Cloaked) && !TF2_IsPlayerInCondition(idx,TFCond_CloakFlicker)) {
										float distance = getPlayerDistance(iClient,idx);
										if (distance < 768) {
											SetEntProp(idx, Prop_Send, "m_bGlowEnabled", 1);
											CreateTimer(3.0,updateGlow,idx);
										}
									}
								}
							}
							else //find enemy buildings
							{
								if(IsValidEntity(idx))
								{
									char class[64];
									GetEntityClassname(idx,class,64);
									if(StrEqual(class,"obj_sentrygun") || StrEqual(class,"obj_teleporter") || StrEqual(class,"obj_dispenser"))
									{
										float distance = getPlayerDistance(iClient,idx);
										if(GetEntProp(iClient, Prop_Send,"m_iTeamNum") != GetEntProp(idx, Prop_Send,"m_iTeamNum") && distance < 768)
										{
											SetEntProp(idx, Prop_Send, "m_bGlowEnabled", 1);
											CreateTimer(3.0,updateGlow,idx);
										}
									}
								}
							}
						}
					}
				}
				//Spy-cicle mechanics
				if(meleeIndex == 649){
					// int sapper = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Building, true);
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
								MeltKnife(iClient,melee,10.0);
						}
					}
				}

				if(TF2_IsPlayerInCondition(iClient,TFCond_Disguised) && !TF2_IsPlayerInCondition(iClient,TFCond_Cloaked))
				{
					//spy sprint
					if(buttons & IN_ATTACK3) SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",320.0);
					else if(g_LastButtons[iClient] & IN_ATTACK3)
					{
						int class = GetEntProp(iClient, Prop_Send, "m_nDisguiseClass");
						TFClassType disguiseClass = view_as<TFClassType>(class);
						switch(disguiseClass)
						{
							case TFClass_Pyro,TFClass_Engineer,TFClass_Sniper:
								SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",300.0);
							case TFClass_DemoMan:
								SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",280.0);
							case TFClass_Soldier,TFClass_Heavy:
								SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",240.0);
							// case TFClass_Heavy:
							// 	SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed",230.0);
						}
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
				if(primaryIndex==220 && curr==primary)
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
							// int view = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
							float time = GetGameTime()+0.03;
							// SetEntPropFloat(view, Prop_Send, "m_flPlaybackRate",99.0);
							SetEntProp(primary, Prop_Data, "m_bInReload",0);
							SetEntPropFloat(primary, Prop_Send, "m_flTimeWeaponIdle",time);
							SetEntPropFloat(primary, Prop_Send, "m_flNextPrimaryAttack",time);
							SetEntPropFloat(primary, Prop_Send, "m_flNextSecondaryAttack",time);
							SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack",time);
						}
					}
				}
				else if((primaryIndex==45 || primaryIndex==1078) && curr==primary)
				{
					int target = GetClientAimTarget(iClient);
					if(IsValidClient(target))
					{
						if((g_condFlags[target]& TF_CONDFLAG_FANFLY) && !(g_condFlags[iClient] & TF_CONDFLAG_INFIRE))
						{
							TF2Attrib_SetByDefIndex(primary,106,0.85); //spread bonus
							g_condFlags[iClient] |= TF_CONDFLAG_INFIRE;
						}
						else if(g_condFlags[iClient] & TF_CONDFLAG_INFIRE)
						{
							g_meterPri[iClient] += 0.015;
							if(g_meterPri[iClient]>0.225)
							{
								TF2Attrib_SetByDefIndex(primary,106,1.0); //spread bonus
								g_condFlags[iClient] &= ~TF_CONDFLAG_INFIRE;
								g_meterPri[iClient] = 0.0;
							}
						}
					}
					else if(g_condFlags[iClient] & TF_CONDFLAG_INFIRE)
						{
							g_meterPri[iClient] += 0.015;
							if(g_meterPri[iClient]>0.225)
							{
								TF2Attrib_SetByDefIndex(primary,106,1.0); //spread bonus
								g_condFlags[iClient] &= ~TF_CONDFLAG_INFIRE;
								g_meterPri[iClient] = 0.0;
							}
						}
				}
				if(curr == melee && meleeIndex==349)
				{
					float meter = GetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",2);
					if (meter>=100.0 && (buttons & IN_ATTACK2) && !(g_LastButtons[iClient] & IN_ATTACK2 == IN_ATTACK2) && !(g_condFlags[iClient] & TF_CONDFLAG_HEAT == TF_CONDFLAG_HEAT))
					{
						//activate SOAS HEAT effect
						g_condFlags[iClient] |= TF_CONDFLAG_HEAT;
						EmitAmbientSound("misc/flame_engulf.wav",position,iClient);
						CreateParticle(iClient,"heavy_ring_of_fire",2.0,_,_,_,_,5.0,_,false,false);
						CreateParticle(iClient,"superrare_burning1",5.0,_,_,_,_,_,_,false,false);
						// CreateTimer(0.5,SOASFlare,iClient);
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
					buttons |= IN_ATTACK;
					weapon = 0;
					int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
					int clip = GetEntData(wep, iAmmoTable, 4);
					if(clip==0 || !IsPlayerAlive(iClient))
					{
						TF2Attrib_SetByDefIndex(wep,6,1.0);
						g_condFlags[iClient] &= ~TF_CONDFLAG_INFIRE;
					}
				}
				else
				{
					if(buttons & IN_ATTACK2)
					{
						g_condFlags[iClient] |= TF_CONDFLAG_INFIRE;
						TF2Attrib_SetByDefIndex(wep,6,0.67);
					}
				}
			}
		}
		//weapon holstering speeds
		if(weapon!=0 && !g_holstering[iClient])
		{
			g_holstering[iClient] = true;
			float speed = 1.0;
			if(primary==curr) speed = g_holsterPri[iClient];
			else if(secondary==curr) speed = g_holsterSec[iClient];
			else if(melee==curr) speed = g_holsterMel[iClient];
			TF2Attrib_SetByDefIndex(iClient,177,speed);
		}
		else if(g_holstering[iClient])
		{
			if(GetGameTime() >= GetEntPropFloat(curr, Prop_Send, "m_flNextPrimaryAttack"))
			{
				TF2Attrib_SetByDefIndex(iClient,177,1.0);
				g_holstering[iClient] = false;
			}
		}
		if(weapon==melee && g_consecHits[iClient]!=-1) //reset melee combo when pulled out
			g_consecHits[iClient]=0;
	}
	g_LastButtons[iClient] = buttons;
	if(!buttonsModified) g_TrueLastButtons[iClient] = buttons;
	return Plugin_Continue;
}

public Action PlayerListener(int iClient, const char[] command, int argc)
{
	char[] args = new char[64];
	GetCmdArg(1,args,64);
	TFClassType tfClientClass = TF2_GetPlayerClass(iClient);
	int clientFlags = GetEntityFlags(iClient);
	char[] current = new char[64];
	GetClientWeapon(iClient,current,64);

	switch(tfClientClass)
	{
		case TFClass_Heavy:
		{
			if(StrEqual(command,"taunt") && (StrEqual(args,"0") || StrEqual(args,"")) &&
			(StrEqual(current,"tf_weapon_lunchbox") || StrEqual(current,"Lunch Box")))
			{
				buffSteak(iClient,clientFlags); //speed up steak eating on taunt and chocolate
			}
		}
		case TFClass_Pyro:
		{
			if(StrEqual(command,"taunt") && (StrEqual(args,"0") || StrEqual(args,"")) &&
			(StrEqual(current,"tf_weapon_flamethrower") || StrEqual(current,"Flame Thrower")) && GetEntPropFloat(iClient, Prop_Send, "m_flRageMeter")>=100.0)
			{
				TF2Attrib_SetByDefIndex(iClient,201,1.5); //speed up phlog taunt speed
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
		case TFClass_Spy:
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
	return Plugin_Continue;
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if(IsValidClient(attacker))
	{
		TFClassType tfAttackerClass = TF2_GetPlayerClass(attacker);
		switch(tfAttackerClass)
		{
			case TFClass_Spy:
			{
				if(damagetype & DMG_BULLET){ //extend ambassador range
					int secondary = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Secondary, true);
					int secondaryIndex = -1;
					if(secondary != -1) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
					if(secondaryIndex==61 || secondaryIndex==1006)
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
					else
					{
						damagetype &= ~DMG_USE_HITLOCATIONS;
					}
				}
			}
			case TFClass_Sniper:
			{
				if(TF2_IsPlayerInCondition(attacker,TFCond_Zoomed))
				{
					int primary = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Primary, true);
					int primaryIndex = -1;
					if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
					if(primaryIndex == 230)
					{
						if(hitgroup == 1)
							TF2_AddCondition(victim,TFCond_Jarated,5.1,attacker); //increase jarate duration on headshot
					}
					if(primaryIndex == 752) //track headshot on heatmaker
					{
						if(hitgroup == 1)
						{
							damagetype |= DMG_SHOCK;
						}
					}
				}
			}
		}

		//hit melee through teammates
		if(damagetype & DMG_CLUB && GetClientTeam(victim) == GetClientTeam(attacker) && victim != attacker)
		{
			int melee = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Melee, true);
			int meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
			if(meleeIndex != 447)
			{
				int idx, closest = -1;
				float player_pos[3], target_pos[3], angles1[3], angles2[3], vector[3];
				float rangeMult=1.0,distance,closestDistance = 0.0;

				GetClientEyePosition(attacker, player_pos);
				GetClientEyeAngles(attacker, angles1);

				for(idx = 1; idx < MaxClients; idx++)
				{
					if(IsClientInGame(idx))
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
					if(attacker != inflictor) SDKHooks_TakeDamage(closest, attacker, attacker, damage, damagetype, inflictor, NULL_VECTOR, target_pos); //shield bash
					else SDKHooks_TakeDamage(closest, attacker, inflictor, damage, damagetype, melee, NULL_VECTOR, target_pos); //otherwise
				}
			}
			return Plugin_Stop;
		}

		if(g_condFlags[victim] & TF_CONDFLAG_VOLCANO && damagetype & DMG_IGNITE) //increase fire damage for volcano marked targets
			TF2_AddCondition(victim,TFCond_MarkedForDeathSilent,0.015);

		if (damagetype & DMG_CLUB && GetClientTeam(victim) != GetClientTeam(attacker))
		{
			if(tfAttackerClass == TFClass_Scout)
			{
				if(g_consecHits[attacker]%4==1 || g_consecHits[attacker]%4==2) //minicrit
				{
					TF2_AddCondition(victim,TFCond_MarkedForDeathSilent,0.015);
				}
			}
			else
			{
				if(g_consecHits[attacker]%3==1) //minicrit
				{
					TF2_AddCondition(victim,TFCond_MarkedForDeathSilent,0.015);
				}
			}
		}
	}
	return Plugin_Changed;
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	TFClassType tfVictimClass = TF2_GetPlayerClass(victim);
	int weaponIndex = -1;
	if(weapon > 0) weaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

	//explode on ignite for single target
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

	if(IsValidClient(attacker))
	{
		TFClassType tfAttackerClass = TF2_GetPlayerClass(attacker);
		switch(tfAttackerClass)
		{
			case TFClass_Scout:
			{
				int melee = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Melee, true);
				int meleeIndex = -1;
				if(melee != -1)
					meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
				if(meleeIndex==349)
				{
					float meter = GetEntPropFloat(attacker, Prop_Send,"m_flItemChargeMeter",2);
					//set SOAS HEAT meter if HEAT is inactive
					if(!(g_condFlags[attacker] & TF_CONDFLAG_HEAT) && meter < 100.0)
					{
						meter += damage/3;
						if(meter>100.0)
							meter = 100.0;
						g_meterMel[attacker] = meter;
						SetEntPropFloat(attacker, Prop_Send,"m_flItemChargeMeter",meter,2);
					}
					//set burn on victims if HEAT is active
					if(g_condFlags[attacker] & TF_CONDFLAG_HEAT && (damagetype & DMG_IGNITE))
					{
						float duration = TF2Util_GetPlayerBurnDuration(victim);
						float dist = getPlayerDistance(attacker,victim); //scale afterburn time with distance,
						float ignition = dist>256 ? RoundToCeil(6.0*((768-dist)/512))/2.0 : 3.0; //max of 3s and intervals of 0.5s
						if(duration < ignition && tfVictimClass != TFClass_Pyro)
							TF2Util_SetPlayerBurnDuration(victim,ignition);
					}
				}
			}
		}
		switch(weaponIndex)
		{
			case 448: //soda popper replenish jumps on hit
			{
				int jumping = GetEntProp(attacker, Prop_Send,"m_bJumping");
				int jumps = GetEntProp(attacker, Prop_Send,"m_iAirDash");

				if(damage>SODA_DAMAGE && jumping>0 && jumps>0)
				{
					SetEntProp(attacker, Prop_Send,"m_iAirDash", jumps-1);
				}
			}
			case 45, 1078: //Force a Nature launch
			{
				if(damage>30.0 && getPlayerDistance(attacker,victim)<400)
				{
					g_condFlags[victim] |= TF_CONDFLAG_FANHIT;
				}
			}
			case 1103: //Back scatter reload on hit
			{
				if(damagetype & DMG_BULLET)
				{
					float time = GetGameTime();
					if(g_meterPri[attacker]!=time)
					{
						g_meterPri[attacker] = time;
						int primaryAmmo = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
						int ammoCount = GetEntProp(attacker, Prop_Data, "m_iAmmo", _, primaryAmmo);
						if(ammoCount>0)
						{
							int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
							SetEntData(weapon, iAmmoTable, 2, _, true);
							SetEntProp(attacker, Prop_Data, "m_iAmmo", ammoCount-1 , _, primaryAmmo);
						}
					}
				}
			}
			case 41: //natascha heal on hit
			{
				float dist = getPlayerDistance(attacker,victim);
				if(dist < 1024)
				{
					float healing = dist < 256.0 ? 5.0 : 4.0*((1024-dist)/768.0) + 1.0;
					TF2Util_TakeHealth(attacker,healing);
					SetHudTextParams(0.1, -0.16, 0.1, 255, 255, 255, 255);
					ShowHudText(attacker,2,"+%.0f HP",healing);
				}
			}
		}
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	TFClassType victimClass = TF2_GetPlayerClass(victim);

	if(attacker == 0)
	{
		if(victimClass == TFClass_Soldier)
		{
			int secondary = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Secondary, true);
			int secondaryIndex = -1;
			if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
			if(secondaryIndex == 444 && (damagetype & DMG_FALL == DMG_FALL))
				damage = 0.1; //reduce fall damage for mantreads
		}
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
		if (victimClass == TFClass_Engineer)
		{
			int secondary = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Secondary, true);
			int secondaryIndex = -1;
			if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
			if(secondaryIndex == 140 || secondaryIndex == 1086 || secondaryIndex == 30668)
				damage *= 0.2; //reduce sentry self-damage with wrangler equipped
		}
		if(IsValidEntity(weapon) && weapon)
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
	else if(inflictor == victim)
	{
		if(IsValidEntity(weapon) && weapon)
		{
			int weaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			switch(weaponIndex)
			{
				case 220: //shortstop shove
				{
					damageForce[0]*=0.025; damageForce[1]*=0.025; damageForce[2]=damageForce[2]*0.00625+300.0;
					TeleportEntity(victim,NULL_VECTOR,NULL_VECTOR,damageForce);
					TF2_AddCondition(victim,TFCond_KnockedIntoAir,3.0);
				}
			}
		}
	}
	if(IsValidEntity(weapon) && IsValidClient(attacker))
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
				if(g_consecHits[attacker]==-2 || g_consecHits[attacker]==-3)
				{
					//parry crit
					g_consecHits[attacker] += 2;
					CreateTimer((g_nextHit[attacker]-g_lastHit[attacker])*0.5,critGlow,attacker);
				}
				else
				{
					//increment 3-hit crit check
					g_consecHits[attacker]++;
					if((tfAttackerClass == TFClass_Scout && g_consecHits[attacker]%4==3) || (tfAttackerClass != TFClass_Scout && g_consecHits[attacker]%3==2))
						CreateTimer((g_nextHit[attacker]-g_lastHit[attacker])*0.5,critGlow,attacker);
				}
			}
			// if(g_condFlags[attacker] & TF_CONDFLAG_INMELEE != TF_CONDFLAG_INMELEE) //cancel parry damage
			// 	damage = 0.01;
		}

		if(StrEqual("tf_weapon_flamethrower",weaponName) && (damagetype & DMG_IGNITE))
		{
			//recreate flamethrower damage scaling, code inpsired by NotnHeavy
			//base damage plus any bonus
			Address bonus = TF2Attrib_GetByDefIndex(weapon,2);
			float value = bonus == Address_Null ? 1.0 : TF2Attrib_GetValue(bonus);
			damage = 13.0 * g_temperature[victim] * value;

			//crit damage multipliers
			if(damagetype & DMG_CRIT)
			{
				if(isMiniKritzed(attacker,victim) && !isKritzed(attacker))
					damage *= 1.35;
				else
					damage *= 3.0;
			}
			//fall-off based on range replacing age multiplier
			float dist = getPlayerDistance(attacker,victim);
			damage *= 1.0 - 0.5*(dist < 170 ? 0.0 : (dist>340 ? 1.0 : ((dist-170)/170)));
			//increment temperature based on range
			g_lastFlamed[victim] = GetGameTime();
			if(g_temperature[victim] < 1.0)
			{
				g_temperature[victim] += 0.0185 + Pow(0.285*((dist>340 ? 0.0 : 340-dist)/340),2.0);
				if(g_temperature[victim] > 1.0) g_temperature[victim] = 1.0;
			}
			damagetype &= ~DMG_USEDISTANCEMOD;

			if(damagetype & DMG_SONIC)
			{
				damagetype &= ~DMG_SONIC;
				damage = 0.01;
			}
		}
		
		switch(tfAttackerClass)
		{
			case TFClass_Spy:
			{
				if(weaponIndex==61 || weaponIndex==1006)
				{
					if(damagetype & DMG_SHOCK)
					{
						damagecustom = TF_CUSTOM_HEADSHOT;
						damagetype &= ~DMG_SHOCK;
					}
				}
			}
			case TFClass_Soldier:
			{
				if(weaponIndex == 444) //add mantreads damage
					damage += 20.0;
				if(weaponIndex == 128)
				{
					//redo damage
					damage = 65.0;
					int secondary = TF2Util_GetPlayerLoadoutEntity(attacker, TFWeaponSlot_Secondary, true);
					int secondaryIndex = -1;
					if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");

					if((secondaryIndex!=226 && GetClientHealth(attacker)>100) || (secondaryIndex==226 && GetClientHealth(attacker)>110))
						damage *= 0.8;
					else
						damage *= 1.4;
					//calculate crits
					if(isKritzed(attacker))
						damage *= 3.0;
					else if (isMiniKritzed(attacker,victim))
						damage *= 1.35;
				}
			}
			case TFClass_DemoMan:
			{
				if(weaponIndex == 307 && damagetype & DMG_BLAST == DMG_BLAST) //caber damage bonus just on explosion
					damage *= 1.11;
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
						if(weaponIndex != 349)
							damage *= 0.8; //damage penalty while igniting enemies
					}
					if((damagetype & DMG_BURN))
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
				if(weaponIndex == 44 && inflictor != attacker) //sandman ball
				{
					float distance = getPlayerDistance(attacker,victim); //get distance from attacker to victim; couldn't actually find travel time of ball
					if(distance>=1440.0)
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
					float duration = 0.1 + RoundToNearest(distance/72.0)/4.0; //round to nearest quarter second. range of 0-5
					if(duration>=1.0)
						TF2_AddCondition(victim,TFCond_MarkedForDeath,duration); //minimum 1 second, ~230 distance
					TF2_RemoveCondition(victim,TFCond_Dazed); //no slow (removes of other slow effects but most too situational to worry)
				}
			}
			case TFClass_Sniper:
			{
				switch(weaponIndex)
				{
					case 1098:
					{
						if(!isKritzed(attacker) &&
						!TF2_IsPlayerInCondition(attacker,TFCond_MiniCritOnKill) &&
						!TF2_IsPlayerInCondition(attacker,TFCond_Buffed) &&
						!TF2_IsPlayerInCondition(attacker,TFCond_CritCola) &&
						(damagetype & DMG_CRIT) == DMG_CRIT && damage > 65)
						{
							float charge = GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage");
							charge = charge < 45 ? 0.0 : charge-45; // bound Classic charge between 0 and 105
							float critMod = charge/105.0 * 1.65;
							damage *= (1.35+critMod)/3.0;
						}
					}
					case 752: //add headshot tag to heatmaker
					{
						if(damagetype & DMG_SHOCK)
						{
							damagecustom = TF_CUSTOM_HEADSHOT;
							damagetype &= ~DMG_SHOCK;
						}
					}
				}
			}
			case TFClass_Pyro:
			{
				switch(weaponIndex)
				{
					case 813, 834:
					{
						//neon explosion if intact
						int broken = GetEntProp(weapon, Prop_Send, "m_bBroken");
						if(broken==0){
							SetEntPropFloat(weapon, Prop_Send, "m_flLastFireTime", GetGameTime());

							int team = GetEntProp(attacker, Prop_Data, "m_iTeamNum");
							if(team == 3)
								CreateParticle(victim,"drg_cow_explosioncore_charged_blue",3.0,_,_,_,_,_,3.0,false);
							else if(team == 2)
								CreateParticle(victim,"drg_cow_explosioncore_charged",3.0,_,_,_,_,_,3.0,false);
							EmitAmbientSound("mvm/giant_soldier/giant_soldier_explode.wav",damagePosition,victim);
							SetEntProp(weapon, Prop_Send, "m_bBroken",1);
							DataPack pack = new DataPack();
							pack.Reset();
							pack.WriteCell(attacker);
							pack.WriteCell(victim);
							damagetype |= DMG_BLAST;
							damage += 80.0;
							RequestFrame(NeonExplosion,pack);
						}
						//neon crits on gassed enemies
						if(TF2_IsPlayerInCondition(victim,TFCond_Gas) && !(damagetype & DMG_CRIT))
						{
							damage *= 3.0;
							damagetype |= DMG_CRIT;
						}
					}
					case 740:
					{
						TF2_RemoveCondition(victim,TFCond_Dazed); //negate stun on scorch shot
						if(!(damagetype & DMG_BURN) && victim != attacker)
							TF2_AddCondition(victim,TFCond_MegaHeal,0.01,attacker); //negate knockback of scorch shot
					}
					case 595: //manmelter giving crits
					{
						if(TF2_IsPlayerInCondition(victim,TFCond_OnFire) && damagetype & DMG_BULLET)
						{
							RequestFrame(ExtinguishEnemy,victim);
							// damage += TF2Util_GetPlayerBurnDuration(victim)*8;
							int crits = GetEntProp(attacker, Prop_Send, "m_iRevengeCrits");
							SetEntProp(attacker, Prop_Send, "m_iRevengeCrits",crits+1);
						}
					}
					case 593:  //third degree
					{
						int health = GetClientHealth(attacker);
						if(health>=175)
						{
							if(health>230) TF2Util_TakeHealth(attacker,260.0-health,TAKEHEALTH_IGNORE_MAXHEALTH);
							else TF2Util_TakeHealth(attacker,30.0,TAKEHEALTH_IGNORE_MAXHEALTH);
						}
						if(!(damagetype & DMG_SHOCK))
						{
							for (int i = 1 ; i <= MaxClients ; i++)
							{
								if(IsClientInGame(i) && i!=victim)
								{
									float dist = getPlayerDistance(i,victim);
									if(GetClientTeam(i)==GetClientTeam(victim) && dist < 512)
									{
										if(TF2Util_GetPlayerConditionProvider(i,TFCond_OnFire)==attacker)
										{
											float dmg = damage;
											if(dist>256) dmg *= (256/dist);
											//add SHOCK damage flag to prevent recursive calls on this hook
											//check for minicrit
											if(damagetype & DMG_CRIT)
											{
												if(!isKritzed(attacker) && isMiniKritzed(attacker,victim))
												{
													damagetype &= ~DMG_CRIT;
													TF2_AddCondition(i,TFCond_MarkedForDeathSilent,0.015);
												}
											}
											SDKHooks_TakeDamage(i, inflictor, attacker, dmg, damagetype |= DMG_SHOCK, weapon, damageForce, damagePosition);
										}
									}
								}
							}
						}
						else
						{
							damagetype &= ~DMG_SHOCK;
						}
					}
					case 348: //sharpened volcano, player hit turns into living mine
					{
						if(damagetype & DMG_CLUB)
						{
							g_condFlags[victim] |= TF_CONDFLAG_VOLCANO;
						}
					}
				}
			}
			case TFClass_Medic:
			{
				switch(weaponIndex){
					case 17,204,36,412:{
						if(damage>1 && !(damagetype & DMG_BULLET)){
							int isCrit = 0;
							Address address = TF2Attrib_GetByDefIndex(weapon,1);
							damage = 10.0;
							if(address != Address_Null) damage *= TF2Attrib_GetValue(address);
							if(isKritzed(attacker))
							{
								isCrit = 1;
								damage *= 3;
							}
							else{
								float dist = getPlayerDistance(attacker,victim);
								if(dist<512) damage *= 1.0 + 0.2*(512-dist)/512;
								if(isMiniKritzed(attacker,victim)){
									isCrit = 1;
									damage *= 1.35;
								}else{
									if(dist>512) damage *= 1.0 - 0.50*(dist > 1024.0 ? 1024.0 : dist)/1024;
								}
							}
							
							damagetype = DMG_BULLET | DMG_NOCLOSEDISTANCEMOD | DMG_PREVENT_PHYSICS_FORCE | DMG_USEDISTANCEMOD;
							if (isCrit!=0) damagetype |= DMG_CRIT;
						}
					}
				}
			}
		}
		switch(victimClass)
		{
			case TFClass_Sniper:
			{
				int secondary = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Secondary, true);
				int secondaryIndex = -1;
				if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");

				if(weaponIndex != 460 && weaponIndex != 171 && secondaryIndex == 57 && damagetype & DMG_CRIT == DMG_CRIT)
				{
					//get razorback broken state and meter
					float ogDamage = damage;
					int flags = GetEntProp(secondary, Prop_Data, "m_fEffects"); //129 = intact, 161 = broken
					int critType = 0;
					float meter = GetEntPropFloat(victim, Prop_Send, "m_flItemChargeMeter", 1);
					if(flags == 129)
					{
						if(!(damagecustom==TF_CUSTOM_BACKSTAB || damagecustom==TF_CUSTOM_HEADSHOT))
						{
							//absorb crit damage from razorback, except headshots or backstabs (backstab breaks it)
							damagetype &= ~DMG_CRIT;
							if(isKritzed(attacker) || weaponIndex==355 || weaponIndex==232)
							{
								damage /=3;
								critType = 1;
							}
							else if(isMiniKritzed(attacker,victim))
							{
								damage /= 1.35;
								critType = 2;
							}
							else{
								switch(weaponIndex)
								{
									case 349,648,416,813,834,40,39,1081,1146: { damage /=3; critType = 1;}
									case 38,1000,457: { damage = 44.0; critType = 2; }
									default: { damage /= 1.35; critType = 2; }
								}
							}
							if(damagetype & DMG_USEDISTANCEMOD == DMG_USEDISTANCEMOD) //do normal falloff
							{
								float dist = getPlayerDistance(attacker,victim);
								if(dist<512 && damagetype & DMG_BLAST)
									damage *= 1.0 + 0.2*(512-dist)/512;
								else if(dist<512)
									damage *= 1.0 + 0.5*(512-dist)/512;
								if(dist>512)
									damage *= 1.0 - 0.50*(dist > 1024.0 ? 1024.0 : dist)/1024;
							}
							if(critType == 1)
							{
								SetEntPropFloat(victim, Prop_Send, "m_flItemChargeMeter", 0.0, 1);
								SetEntProp(secondary, Prop_Data, "m_fEffects",161); //break shield
							}
							else
							{
								SetEntPropFloat(victim, Prop_Send, "m_flItemChargeMeter", meter-(ogDamage-damage) > 0 ? meter-(ogDamage-damage) : 0.0, 1); //reduce shield
								if(meter-(ogDamage-damage) <= 0.0)
									SetEntProp(secondary, Prop_Data, "m_fEffects",161); //break shield?
							}
						}
					}
					if(damagecustom==TF_CUSTOM_BACKSTAB && damage == 0.0)
					{
						damage = 85.0;
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
					if(TF2_IsPlayerInCondition(victim,TFCond_Parachute) && (secondaryIndex == 1101 || primaryIndex == 1101)){
						g_meterSec[victim] += damage*(PARACHUTE_TIME/100.0);
					}
				}
			}
			case TFClass_Spy:
			{
				//Enforcer disguise resistance
				int secondary = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Secondary, true);
				int secondaryIndex = -1;
				if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
				int melee = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Melee, true);
				int meleeIndex = -1;
				if(melee>0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
				if(secondaryIndex == 460 && weaponIndex != 460 && weaponIndex != 171)
				{
					if(TF2_IsPlayerInCondition(victim,TFCond_Disguised) && !TF2_IsPlayerInCondition(victim,TFCond_Cloaked) && !TF2_IsPlayerInCondition(victim,TFCond_CloakFlicker))
						damage *= 0.8;
				}
				//spy-cicle melted resistance
				if(meleeIndex == 649 && weaponIndex != 460 && weaponIndex != 171)
				{
					if(g_condFlags[victim] & TF_CONDFLAG_INFIRE)
						damage *= 0.75;
				}
			}
			case TFClass_Heavy:
			{
				if(TF2_IsPlayerInCondition(victim,TFCond_Slowed) && weaponIndex != 460 && weaponIndex != 171)
				{
					//brass beast resistance
					int primary = TF2Util_GetPlayerLoadoutEntity(victim, TFWeaponSlot_Primary, true);
					int primaryIndex = -1;
					if(primary>0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
					int weaponState = GetEntProp(primary, Prop_Send, "m_iWeaponState");
					if(primaryIndex == 312 && (weaponState == 2 || weaponState == 3))
						damage *= 0.8;
				}
			}
		}

		if(g_condFlags[victim] & TF_CONDFLAG_VOLCANO)
		{
			if(damagetype & DMG_BURN)//afterburn effect for volcano
				CreateParticle(victim,"dragons_fury_effect",2.0);
		}
		
		//vaccinator passive offense bonuses
		if(TF2_IsPlayerInCondition(attacker,TFCond_SmallBulletResist) && damagetype & DMG_BUCKSHOT)
			damage *= 1.1;
		else if(TF2_IsPlayerInCondition(attacker,TFCond_SmallFireResist) && damagetype & DMG_IGNITE)
			damage *= 1.1;
		else if(TF2_IsPlayerInCondition(attacker,TFCond_SmallBlastResist) && damagetype & DMG_BLAST)
			damage *= 1.1;

		//calculate vaccinator resistance
		float shields = 0.0;
		if((g_condFlags[victim] & TF_CONDFLAG_VACCMIN)) shields++;
		if((g_condFlags[victim] & TF_CONDFLAG_VACCMED)) shields++;
		if((g_condFlags[victim] & TF_CONDFLAG_VACCMAX)) shields++;

		if (weaponIndex != 460 && weaponIndex != 171 && shields > 0 && damagecustom!=TF_CUSTOM_BACKSTAB)
		{
			float vacResistance = 1.0;
			vacResistance *= Pow(0.745,shields);
			if(TF2_IsPlayerInCondition(victim,TFCond_HealingDebuff)) //reduce res with afterburn
				vacResistance *= Pow(3.2/3,shields);

			if(damagetype & DMG_CRIT) //surpress kritz
			{
				if(isKritzed(attacker) || weaponIndex==355 || weaponIndex==232)
					damage *= 0.5555;
				else if(isMiniKritzed(attacker,victim))
					damage *= 0.8272;
				else{
					switch(weaponIndex)
					{
						case 349,648,416,813,834,40,39,1081,1146: { damage /=3; }
						case 38,1000,457: { damage = 44.0; }
						default: { damage /= 1.35; }
					}
				}
				if(damagetype & DMG_USEDISTANCEMOD == DMG_USEDISTANCEMOD) //do normal falloff
				{
					float dist = getPlayerDistance(attacker,victim);
					if(dist<512 && damagetype & DMG_BLAST)
						damage *= 1.0 + 0.2*(512-dist)/512;
					else if(dist<512)
						damage *= 1.0 + 0.5*(512-dist)/512;
					if(dist>512)
						damage *= 1.0 - 0.50*(dist > 1024.0 ? 1024.0 : dist)/1024;
				}
				damagetype &= ~DMG_CRIT;
			}
			damage *= vacResistance;
		}
	}

	// PrintToChat(attacker,"%.2f %.2f",damage,getPlayerDistance(victim,attacker));
	// PrintToChatAll("%.2f %.2f %.2f | %.2f %.2f %.2f",damageForce[0],damageForce[1],damageForce[2],damagePosition[0],damagePosition[1],damagePosition[2]);
	return Plugin_Changed;
}

Action BuildingThink(int building,int client)
{
	//update animation speeds for building construction
	char class[64];
	GetEntityClassname(building,class,64);
	int seq = GetEntProp(building, Prop_Data, "m_nSequence");
	float rate = RoundToFloor(GetEntPropFloat(building, Prop_Data, "m_flPlaybackRate")*100)/100.0;
	float cons = GetEntPropFloat(building, Prop_Send, "m_flPercentageConstructed");

	if(StrEqual(class,"obj_sentrygun") && seq == 2)
	{
		SetEntPropFloat(building, Prop_Send, "m_flCycle",cons);
	}
	else if((StrEqual(class,"obj_teleporter")||StrEqual(class,"obj_dispenser")) && seq == 1)
	{
		switch(rate)
		{
			case 0.50: SetEntPropFloat(building, Prop_Send, "m_flPlaybackRate", 1.00);
			case 1.25: SetEntPropFloat(building, Prop_Send, "m_flPlaybackRate", 2.50);
			case 1.47: SetEntPropFloat(building, Prop_Send, "m_flPlaybackRate", 2.94);
			case 0.87: SetEntPropFloat(building, Prop_Send, "m_flPlaybackRate", 1.74);
			case 2.00: SetEntPropFloat(building, Prop_Send, "m_flPlaybackRate", 4.00);
			case 2.75: SetEntPropFloat(building, Prop_Send, "m_flPlaybackRate", 5.50);
		}
	}
	return Plugin_Continue;
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
			case 17,204,36,412:{ //syringe damage
				if(damage>1 && !(damagetype & DMG_BULLET)){
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
				if(StrContains("sapper",class) != -1 || StrContains("builder",class) != -1)
					damage *= 0.5;
			}
		}
		if(StrEqual("obj_sentrygun",class))
		{
			int owner = GetEntPropEnt(building, Prop_Send, "m_hBuilder");
			if(owner != -1)
			{
				//half effective damage resistance of wrangler
				int secondary = TF2Util_GetPlayerLoadoutEntity(owner, TFWeaponSlot_Secondary, true);
				int secondaryIndex = -1;
				if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
				if(secondaryIndex == 140 || secondaryIndex == 1086 || secondaryIndex == 30668)
				{
					int shield = GetEntProp(building, Prop_Send, "m_nShieldLevel");
					
					if(shield > 0 && weaponIndex != 460 && weaponIndex != 171)
						damage *= 2;
				}
			}
		}
	}
	return Plugin_Changed;
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	// int weaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	TFClassType tfAttackerClass = TF2_GetPlayerClass(client);
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
	return Plugin_Continue;
}

Action critGlow(Handle timer, int attacker)
{
	TF2_AddCondition(attacker,TFCond_CritDemoCharge,(g_nextHit[attacker]-g_lastHit[attacker])*2.0);
	return Plugin_Continue;
}

// public void Event_SpawnAmmo(int entity)
// {
// 	char class[64];
// 	GetEntityClassname(entity, class, sizeof(class));
// 	char name[64];
// 	GetEntPropString(entity, Prop_Data, "m_iName",name,64);
// 	// PrintToChatAll("SPAWN %s %s",class,name);
// 	if(StrContains(class,"ammo_pack") != -1){
// 		int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
// 		// float speed = GetEntPropFloat(entity, Prop_Data, "m_flFadeScale");
// 		int hp = GetEntProp(entity, Prop_Data, "m_iHealth");
// 		PrintToChatAll("AMMO %d",hp);
// 		if(g_spawnPumpkin[owner] == 1){
// 			SetEntityModel(entity,"models/props_halloween/pumpkin_loot.mdl");
// 			float vel[3]; vel[2]=100.0;
// 			TeleportEntity(entity,NULL_VECTOR,NULL_VECTOR,vel);
// 		}
// 		// else if(StrContains(name,"custom") != -1){
// 		// 	int Ammopack = CreateEntityByName("tf_ammo_pack");
// 		// 	DispatchKeyValue(Ammopack, "OnPlayerTouch", "!self,Kill,,0,-1");
// 		// 	DispatchKeyValue(Ammopack, "targetname", "customAmmo");
// 		// 	DispatchSpawn(Ammopack);
// 		// 	float AmmoPos[3];
// 		// 	GetClientEyePosition(owner,AmmoPos);
// 		// 	TeleportEntity(Ammopack, AmmoPos, NULL_VECTOR, NULL_VECTOR);
// 		// 	AcceptEntityInput(entity,"Kill");
// 		// }
// 	}
// }

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
		// if(StrContains(model,"pumpkin_loot") != -1){
		// 	TF2_AddCondition(other,TFCond_HalloweenCritCandy,3.2,other);
		// }

		int melee = TF2Util_GetPlayerLoadoutEntity(other, TFWeaponSlot_Melee, true);
		int meleeIndex = -1;
		if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
		if(meleeIndex==307)
		{
			RefillCaber(other,factor,entity,regen);
		}
	}
	return Plugin_Continue;
}

public Action Event_PickUpHealth(int entity, int other)
{
	if(IsValidClient(other))
	{
		int melee = TF2Util_GetPlayerLoadoutEntity(other, TFWeaponSlot_Melee, true);
		int meleeIndex = -1;
		if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
		if(meleeIndex==317) //cap overheal on candycane
		{
			int health = GetClientHealth(other);
			int flags = GetEntProp(entity, Prop_Data, "m_fFlags"); //1 for drop kits, 0 for other
			if(health<158 && health>99 && flags == 1)
			{
				float heal = health+26.0 < 158 ? 26.0 : 158.0-health;
				TF2Util_TakeHealth(other,heal,TAKEHEALTH_IGNORE_MAXHEALTH);
				SetHudTextParams(0.1, -0.16, 0.1, 255, 255, 255, 255);
				ShowHudText(other,4,"+%.0f HP",heal);
				EmitSoundToClient(other,"items/smallmedkit1.wav");
				AcceptEntityInput(entity,"Kill");
			}
		}
	}
	return Plugin_Continue;
}

public void RefillMetal(int iClient, int size, int pack, int refill)
{
	int metal = GetEntData(iClient, FindDataMapInfo(iClient, "m_iAmmo") + (3 * 4), 4);
	float scale = GetEntPropFloat(pack, Prop_Data, "m_flModelScale");
	if(metal<200 && scale>0.6)
	{
		if(refill==1)
		{
			if(GetEntProp(pack,Prop_Send,"m_iTeamNum")==1)
				return;
			AcceptEntityInput(pack,"Disable");
			SetEntProp(pack,Prop_Send,"m_iTeamNum",1);
			CreateTimer(10.0, PackTimer, pack);
		}else{
			AcceptEntityInput(pack,"Kill");
		}
		EmitSoundToClient(iClient,"items/gunpickup2.wav");
		
		float bonus = 0.4 + refill;//southern hospitality bonus metal on pickups
		int primary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Primary, false);
		int primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
		int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, false);
		int secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
		int primaryAmmo = -1;
		int secondaryAmmo = -1;
		if(primary != -1 && primaryIndex != 527)
			primaryAmmo = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
		if(secondary != -1 && secondaryIndex != 140 && secondaryIndex != 1086 && secondaryIndex != 528 && secondaryIndex != 30668)
			secondaryAmmo = GetEntProp(secondary, Prop_Send, "m_iPrimaryAmmoType");
		if(primaryAmmo != -1)
		{
			int currAmmo = GetEntProp(iClient, Prop_Data, "m_iAmmo", _, primaryAmmo);
			switch(primaryIndex)
			{
				case 997:
				{
					currAmmo = 16/size + currAmmo;
					currAmmo = currAmmo>16 ? 16 : currAmmo;
				}
				default:
				{
					currAmmo = 32/size + currAmmo;
					currAmmo = currAmmo>32 ? 32 : currAmmo;
				}
			}
			SetEntProp(iClient, Prop_Data, "m_iAmmo", currAmmo , _, primaryAmmo);
		}
		if(secondaryAmmo != -1)
		{
			int currAmmo = GetEntProp(iClient, Prop_Data, "m_iAmmo", _, secondaryAmmo) + 200/size;
			SetEntProp(iClient, Prop_Data, "m_iAmmo", currAmmo > 200 ? 200 : currAmmo , _, secondaryAmmo);
		}
		char modelname[64];
		GetEntPropString(pack, Prop_Data, "m_ModelName",modelname,sizeof(modelname));
		float metalBack = 200.0/size; //default for packs
		//determine metal back from building gibs
		if(StrContains(modelname,"sentry")>-1) metalBack = 16.0;
		if(StrContains(modelname,"dispenser")>-1) metalBack = 10.0;
		if(StrContains(modelname,"teleporter")>-1) metalBack = 6.0;
		metal = metal+RoundFloat(metalBack*bonus);

		SetEntData(iClient, FindDataMapInfo(iClient, "m_iAmmo") + (3 * 4), metal>200 ? 200 : metal, 4);
	}
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
		}else{
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
				SetEntPropFloat(melee, Prop_Send, "m_flLastFireTime", lastFire-4.0);
			case 2:
				SetEntPropFloat(melee, Prop_Send, "m_flLastFireTime", lastFire-10.0);
			case 1:
				SetEntPropFloat(melee, Prop_Send, "m_flLastFireTime", lastFire-20.0);
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
	TF2_RemoveCondition(iClient,TFCond_MarkedForDeath);
	TF2_RemoveCondition(iClient,TFCond_MarkedForDeathSilent);
	EmitAmbientSound("player/flame_out.wav",position,iClient);
	SetEntProp(melee, Prop_Send,"m_bKnifeExists",0);
	SetEntPropFloat(melee, Prop_Send,"m_flKnifeRegenerateDuration",time);
	SetEntPropFloat(melee, Prop_Send,"m_flKnifeMeltTimestamp",GetGameTime());
	SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",100.0,2);
	g_meterMel[iClient] = 5.0;
	
	g_condFlags[iClient] |= TF_CONDFLAG_INFIRE;
	SetHudTextParams(0.1, -0.16, 0.1, 255, 255, 255, 255);
	ShowHudText(iClient,4,"+20 HP");
	TF2Util_TakeHealth(iClient,20.0);
}

public Action PackTimer(Handle timer, int pack)
{
	AcceptEntityInput(pack,"Enable");
	SetEntProp(pack,Prop_Send,"m_iTeamNum",0);
	return Plugin_Continue;
}

public void buffSteak(int iClient,int clientFlags)
{
	int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
	int secondaryIndex = -1;
	if(secondary >= 0)
		secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
	if ((311 == secondaryIndex || 159 == secondaryIndex || 433 == secondaryIndex) && (clientFlags & FL_ONGROUND) == FL_ONGROUND)
	{
		if(159 == secondaryIndex || 433 == secondaryIndex) //setup for dalokohs
		{
			g_meterSec[iClient] = 30.0;
			if(GetClientHealth(iClient)>1)
			{
				SDKHooks_TakeDamage(iClient,0,0,1.0);
				RequestFrame(chocolateTick,iClient);
			}
			CreateTimer(1.25,chocolateHeal,iClient);
		}
		TF2Attrib_SetByDefIndex(iClient,201,1.70); //faster steak eating activated on weapon taunt (0) with steak
	}
}

public Action honorBound(Handle timer, int iClient)
{
	char[] current = new char[64];
	GetClientWeapon(iClient,current,64);
	if(StrEqual(current,"tf_weapon_fists")) //set honorbound if melee is out
	{
		SetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",0.0,2);
	}
	return Plugin_Continue;
}

public Action debuffVita(Handle timer, int iClient)
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

	TF2Attrib_SetByDefIndex(primary,97,1.0);
	switch(primaryIndex)
	{
		case 412: TF2Attrib_SetByDefIndex(primary,178,0.8);
		default: TF2Attrib_SetByDefIndex(primary,178,1.0);
	}
	TF2Attrib_SetByDefIndex(primary,6,1.0);
	
	switch(secondaryIndex)
	{
		case 411: TF2Attrib_SetByDefIndex(secondary,8,1.4);
		default: TF2Attrib_SetByDefIndex(secondary,8,1.0);
	}
	TF2Attrib_SetByDefIndex(secondary,178,1.0);
	
	TF2Attrib_SetByDefIndex(melee,6,1.0);
	TF2Attrib_SetByDefIndex(melee,178,1.0);
	if(meleeIndex == 173) TF2Attrib_SetByDefIndex(melee,811,0.001);
	return Plugin_Continue;
}

public Action WeaponSwitch(int iClient, int weapon)
{
	TFClassType tfClientClass = TF2_GetPlayerClass(iClient);
	int melee = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Melee, true);
	int meleeIndex = -1;
	if(melee >= 0) meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
	char[] current = new char[64];
	GetClientWeapon(iClient,current,64);
	
	switch(tfClientClass)
	{
		case TFClass_Heavy:
		{
			if(meleeIndex==310)
			{
				if(weapon == melee)
					CreateTimer(0.5,honorBound,iClient); //time checking for honorbound after draw animation
				else if(StrEqual(current,"tf_weapon_fists") && GetEntPropFloat(iClient, Prop_Send,"m_flItemChargeMeter",2) == 0.0)
					TF2_AddCondition(iClient,TFCond_MarkedForDeath,6.0); //add mark for death when switching without kill
			}
		}
		case TFClass_Pyro: //make sure gravity resets on swapping weapons
		{
			int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
			int secondaryIndex = -1;
			if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
			if(secondaryIndex!=1179)
			{
				g_condFlags[iClient] &= ~TF_CONDFLAG_HOVER;
				TF2_RemoveCondition(iClient,TFCond_RocketPack);
				SetEntityGravity(iClient,1.0);
			}
		}
	}
	return Plugin_Continue;
}

public Action updateGlow(Handle timer, int client){ //radar glow
	if(IsValidEntity(client))
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
	return Plugin_Continue;
}

public Action updateHeads(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	int heads = pack.ReadCell();
	int respawn = pack.ReadCell();
	int melee = TF2Util_GetPlayerLoadoutEntity(client, TFWeaponSlot_Melee, true);
	if(heads>4)
		heads = 4; //cap heads 
	float healthPenalty = heads*-15.0;
	TF2Attrib_SetByDefIndex(melee,125,healthPenalty);
	if(respawn==1)
		TF2Util_TakeHealth(client,200.0);
	return Plugin_Continue;
}

public void updateShield(DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	float meter = pack.ReadFloat();
	
	SetEntPropFloat(client, Prop_Send,"m_flChargeMeter",meter);
}

Action updateVacc(Handle handle,DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	if(IsClientInGame(client))
	{
		TFTeam team = TF2_GetClientTeam(client);
		int flag = pack.ReadCell();
		float time = pack.ReadFloat();
		float interval = pack.ReadFloat();
		g_condFlags[client] &= ~flag;

		if(time > 0)
		{
			char[] resist = new char[64];
			char[] aura = new char[64];
			char[] overlay = new char[64];
			if(team == TFTeam_Blue)
			{
				StrCat(resist,64,"powerup_icon_resist_blue");
				StrCat(aura,64,"soldierbuff_blue_buffed");
				StrCat(overlay,64,"effects/invuln_overlay_blue");
			}
			else if(team == TFTeam_Red)
			{
				StrCat(resist,64,"powerup_icon_resist_red");
				StrCat(aura,64,"soldierbuff_red_buffed");
				StrCat(overlay,64,"effects/invuln_overlay_red");
			}
			int offset;
			if(flag == TF_CONDFLAG_VACCMIN)
				offset = 0;
			else if(flag == TF_CONDFLAG_VACCMED)
				offset = 10;
			else if(flag == TF_CONDFLAG_VACCMAX)
				offset = 20;
			
			CreateParticle(client,resist,interval,_,_,_,_,100.0+offset,_,false,false);
			CreateParticle(client,aura,interval,_,_,_,_,_,_,false,false);
			SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
			ClientCommand(client, "r_screenoverlay \"%s\"", overlay);
			SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") | FCVAR_CHEAT); 

			if(!(g_condFlags[client] & flag))
			{
				//set flag when checking resistances
				g_condFlags[client] |= flag;
				//block capture and uber build while ubered vacc 
				TF2Attrib_SetByDefIndex(client,239,0.01);//uber rate
				TF2Attrib_SetByDefIndex(client,68,-2.0);//capture rate
				TF2Attrib_SetByDefIndex(client,400,1.0);//pickup intel
			}
		}
		else{
			SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
			ClientCommand(client, "r_screenoverlay \"\"");
			SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") | FCVAR_CHEAT); 
			TF2Attrib_RemoveByDefIndex(client,239);//uber rate
			TF2Attrib_RemoveByDefIndex(client,68);//capture rate
			TF2Attrib_RemoveByDefIndex(client,400);//pickup intel
			return Plugin_Stop;
		}

		time -= interval;
		pack.Reset();
		pack.WriteCell(client);
		pack.WriteCell(flag);
		pack.WriteFloat(time);
		pack.WriteFloat(interval);
	}
	else
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public void chocolateSpawn(int entity)
{
	int iClient = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if(IsValidClient(iClient))
	{
		int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
		int secondaryIndex = -1;
		if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
		if(secondaryIndex == 159 || secondaryIndex == 433)
		{
			SetEntityModel(entity, "models/workshop/weapons/c_models/c_chocolate/plate_chocolate.mdl");
		}
	}
}

public void chocolateTick(int iClient)
{
	TF2Util_TakeHealth(iClient,1.0);
}

public Action chocolateHeal(Handle timer, int iClient)
{
	//add dalokohs max health
	int secondary = TF2Util_GetPlayerLoadoutEntity(iClient, TFWeaponSlot_Secondary, true);
	int secondaryIndex = -1;
	if(secondary>0) secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
	
	if(IsValidClient(iClient))
	{
		if(IsPlayerAlive(iClient) && (secondaryIndex == 159 || secondaryIndex == 433))
		{
			TF2Attrib_SetByDefIndex(secondary,26,50.0); //max health additive bonus
		}
	}
	return Plugin_Continue;
}

public Action shortCircuitAlt(Handle timer, int secondary)
{
	//increase next firing for alt fire
	SetEntPropFloat(secondary, Prop_Send, "m_flNextSecondaryAttack",GetGameTime()+1.0);
	return Plugin_Continue;
}

public void ExtinguishEnemy(int client)
{
	TF2_RemoveCondition(client,TFCond_OnFire);
}

stock void CreateParticle(int ent, char[] particleType, float time,float angleX=0.0,float angleY=0.0,float Xoffset=0.0,float Yoffset=0.0,float Zoffset=0.0,float size=1.0,bool update=true,bool parent=true,bool attach=false,float angleZ=0.0,int owner=-1)
{
	int particle = CreateEntityByName("info_particle_system");

	char[] name = new char[64];

	if (IsValidEdict(particle))
	{
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
}

public Action DeleteParticle(Handle timer, int particle)
{
	char[] classN = new char[64];
	if (IsValidEdict(particle))
	{
		GetEdictClassname(particle, classN, 64);
		if (StrEqual(classN, "info_particle_system", false))
			RemoveEdict(particle);
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

	if(IsValidEntity(particle))
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
					int primary = TF2Util_GetPlayerLoadoutEntity(owner, TFWeaponSlot_Primary, true);
					if(IsValidClient(owner))
					{
						int interval = RoundFloat(g_flameHit[particle]*1000);
						if(interval%75 == 0){
							for(int idx = 1; idx <= MaxClients; idx++)
							{
								if(IsValidClient(idx))
								{
									float targetpos[3],flamepos[3];
									GetEntPropVector(idx, Prop_Send, "m_vecOrigin", targetpos);
									if(GetClientTeam(owner) != GetClientTeam(idx))
									{
										GetEntPropVector(particle, Prop_Send, "m_vecOrigin", flamepos);
										float distance = GetVectorDistance(flamepos,targetpos);
										float damage = 4.0*((time-g_flameHit[particle])/time);

										if(distance<35.0)
											SDKHooks_TakeDamage(idx, primary, owner, damage, DMG_IGNITE|DMG_SONIC, primary, NULL_VECTOR, flamepos);
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

public Action MelterView(Handle timer, int view)
{
	if(GetEntProp(view, Prop_Send, "m_nSequence") == 24 || GetEntProp(view, Prop_Send, "m_nSequence") == 25)
	{
		SetEntProp(view, Prop_Send, "m_nSequence",18);
		SetEntPropFloat(view, Prop_Send, "m_flPlaybackRate",1.125);
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

public void Phlog_SecondaryAttack(int entity,int client,float angles[3])
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
			charge = GetEntPropFloat(client, Prop_Send, "m_flRageMeter");
			int primaryAmmo = GetEntProp(entity, Prop_Send, "m_iPrimaryAmmoType");
			int ammo = GetEntProp(client, Prop_Data, "m_iAmmo", _, primaryAmmo);
			int cost = 25;
			
			if (ammo >= cost)
			{
				int view = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
				if(!IsValidEdict(view))
					return;
				SetEntProp(view, Prop_Send, "m_nSequence",13);
				SetEntPropFloat(view, Prop_Send, "m_flPlaybackRate",1.0);
				SetEntProp(client, Prop_Data, "m_iAmmo", ammo-cost, _, primaryAmmo);
				GetClientEyePosition(client, player_pos);
				GetClientEyeAngles(client, angles1);
				float angle = angles[1]*0.01745329;
				float Xoffset = (80-FloatAbs(angles[0])) * Cosine(angle);
				float Yoffset = (80-FloatAbs(angles[0])) * Sine(angle);
				float Zoffset = 50.0 - angles[0];
				EmitAmbientSound("weapons/barret_arm_shot.wav",player_pos,client);
				CreateParticle(client,"arm_muzzleflash_electro",1.0,_,_,Xoffset,Yoffset,Zoffset,20.0);
				CreateParticle(client,"arm_muzzleflash_flare",1.0,_,_,Xoffset,Yoffset,Zoffset,20.0);
				int extraCharge = 0;
				
				for(idx = 1; idx < 2048; idx++)
				{
					if(IsValidEntity(idx))
					{
						GetEntityClassname(idx, class, sizeof(class));
						if((idx <= MaxClients) || (StrContains(class, "tf_projectile_") != -1  &&
						!StrEqual(class, "tf_projectile_energy_ring") && !StrEqual(class, "tf_projectile_mechanicalarmorb"))){
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
											if(GetClientTeam(idx)!=GetClientTeam(client))
												SDKHooks_TakeDamage(idx, entity, client, 10.0, DMG_SHOCK, entity, NULL_VECTOR, target_pos);
											else{
												if(TF2_IsPlayerInCondition(idx,TFCond_OnFire)){
													TF2_RemoveCondition(idx,TFCond_OnFire);
													extraCharge++;
												}
											}
										}
										else
										{
											int team = GetEntProp(idx, Prop_Send, "m_iTeamNum");
											if(team != GetClientTeam(client))
											{
												CreateParticle(idx,"arm_muzzleflash_electro",1.0);
												RemoveEntity(idx);
												extraCharge++;
											}
										}
									}
								}
							}
						}
					}
				}
				SetEntPropFloat(client, Prop_Send, "m_flRageMeter", charge+10.0*extraCharge);
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
			if(IsClientInGame(idx))
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
				SDKHooks_TakeDamage(client, melee, client, 100.0, DMG_BLAST, melee, blastVec, impact_pos);
				SDKHooks_TakeDamage(closest, melee, client, 500.0, DMG_BLAST, melee, blastVec, impact_pos);
				for(idx = 1; idx < MaxClients; idx++)
				{
					if(IsClientInGame(idx) && idx != closest)
					{
						if(IsPlayerAlive(idx) && GetClientTeam(idx) != GetClientTeam(client))
						{
							GetEntPropVector(idx, Prop_Send, "m_vecOrigin", target_pos);
							distance = GetVectorDistance(impact_pos, target_pos);
							if(distance < 110.0)
								SDKHooks_TakeDamage(idx, melee, client, 100.0+50.0*((125-distance)/125.0), DMG_BLAST, melee, blastVec, impact_pos);
						}
					}
				}
			}
			else
			{
				EmitAmbientSound("weapons/bottle_impact_hit_flesh1.wav",player_pos,client);
				SDKHooks_TakeDamage(closest, melee, client, 55.0, DMG_CLUB, melee, NULL_VECTOR, impact_pos);
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
			if(IsClientInGame(idx))
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
			SDKHooks_TakeDamage(closest, secondary, client, 65.0, DMG_CLUB, secondary, NULL_VECTOR, impact_pos);
		}
	}
	return Plugin_Continue;
}

public void NeonExplosion(DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	int victim = pack.ReadCell();
	float player_pos[3], target_pos[3], force_vec[3];
	float distance = 0.0;

	int melee = TF2Util_GetPlayerLoadoutEntity(client, TFWeaponSlot_Melee, true);
	GetClientEyePosition(victim,player_pos);
	
	for(int idx = 1; idx < MaxClients; idx++)
	{
		if(IsClientInGame(idx) && idx != victim)
		{
			if(IsPlayerAlive(idx) && (GetClientTeam(idx) != GetClientTeam(client) || idx == client))
			{
				GetClientEyePosition(idx,target_pos);
				distance = GetVectorDistance(player_pos, target_pos);
				if(distance < 110)
				{
					float damage = 75.0 + 25.0*((110-distance)/110);
					int damagetype = DMG_BLAST;
					if(idx==client)
						damage = 75.0;
					else if (TF2_IsPlayerInCondition(idx,TFCond_Gas) || TF2_IsPlayerInCondition(idx,TFCond_Milked) || TF2_IsPlayerInCondition(idx,TFCond_Jarated))
						damagetype |= DMG_CRIT;
					SDKHooks_TakeDamage(idx, client, client, damage, damagetype, melee, force_vec, player_pos);
				}
			}
		}
	}
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
	float damagePosition[3];

	if(IsPlayerAlive(victim))
	{
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", damagePosition);
		int secondary = TF2Util_GetPlayerLoadoutEntity(gasser, TFWeaponSlot_Secondary, true);
		SDKHooks_TakeDamage(victim, gasser, gasser, 20.0, DMG_SLASH, secondary, NULL_VECTOR, damagePosition);
	}
	SetEntPropFloat(gasser, Prop_Send, "m_flItemChargeMeter", meter, 1);
	CreateParticle(victim,"dragons_fury_effect",2.0);
	return Plugin_Continue;
}

Action FlagTouch(int flag, int other) //speed up returning flag
{
	if(IsValidClient(other))
	{
		int flagTeam = GetEntProp(flag, Prop_Send, "m_iTeamNum");
		int clientTeam = GetClientTeam(other);
		float time = GetEntPropFloat(flag, Prop_Send, "m_flResetTime");
		if(flagTeam == clientTeam && time > GetGameTime())
		{
			SetEntPropFloat(flag, Prop_Send, "m_flResetTime",time-0.045);
		}
	}
	return Plugin_Continue;
}

Action FlameTouch(int flame, int other) //lingering flamethrower flames
{
	float time = GetGameTime();
	int owner = GetEntPropEnt(flame, Prop_Send, "m_hAttacker");
	if(other==0 && g_lastFire[owner]+0.045<time)
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

		int team = GetEntProp(flame, Prop_Send, "m_iTeamNum");
		CreateParticle(0,"burninggibs",FIRE_TIME/1.25,_,_,pos[0],pos[1],pos[2],0.2,_,_,_,_,owner);
		if(team==2)
		{
			CreateParticle(0,"burningplayer_glow",FIRE_TIME,_,_,pos[0],pos[1],pos[2],_,false);
		}
		else if(team==3)
		{
			CreateParticle(0,"burningplayer_glow_blue",FIRE_TIME,_,_,pos[0],pos[1],pos[2],_,false);
		}
		g_lastFire[owner] = time;
	}
	return Plugin_Continue;
}

void laserSpawn(int iEnt)
{
	char class[64];
	int weapon;
	float maxs[3];
	float mins[3];
	GetEntityClassname(iEnt, class, sizeof(class));
	if (StrEqual(class, "tf_projectile_energy_ring"))
	{
		g_bisonHit[iEnt] = 0;
		weapon = GetEntPropEnt(iEnt, Prop_Send, "m_hLauncher");
		if (weapon > 0)
		{
			GetEntityClassname(weapon, class, sizeof(class));
			if (StrEqual(class, "tf_weapon_drg_pomson"))
				SetEntProp(iEnt, Prop_Send, "m_triggerBloat", 4);
			else if (StrEqual(class, "tf_weapon_raygun"))
				SetEntProp(iEnt, Prop_Send, "m_triggerBloat", 8);
			maxs[0] = 2.0; maxs[1] = 2.0; maxs[2] = 10.0;
			mins[0] = (0.0 - maxs[0]); mins[1] = (0.0 - maxs[1]); mins[2] = (0.0 - maxs[2]);
			SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", maxs);
			SetEntPropVector(iEnt, Prop_Send, "m_vecMins", mins);
			SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", (GetEntProp(iEnt, Prop_Send, "m_usSolidFlags") | 0x80));
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
		if (740 == wepIndex)
		{
			SetEntProp(entity, Prop_Data, "m_iHealth",0);
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
		ang[0] += GetRandomFloat(-1.4,1.4) - 1.5; ang[1] += GetRandomFloat(-1.4,1.4) + 0.25; //add spread
		offset[0] = (1.0 * Sine(DegToRad(ang[1])));
		offset[1] = (-1.0 * Cosine(DegToRad(ang[1])));
		offset[2] = -2.5;
		//inherit player velocity
		offset[0] += playervel[0]*0.1125;
		offset[1] += playervel[1]*0.1125;
		offset[2] += playervel[2]*0.1125;
		pos[0]+=offset[0]; pos[1]+=offset[1]; pos[2]+=offset[2];

		if(index==412)
		{
			if(kritzed) EmitAmbientSound("weapons/overdose_shoot_crit.wav",pos,iClient);
			else EmitAmbientSound("weapons/overdose_shoot.wav",pos,iClient);
		}
		else
		{
			if(kritzed) EmitAmbientSound("weapons/syringegun_shoot_crit.wav",pos,iClient);
			else EmitAmbientSound("weapons/syringegun_shoot.wav",pos,iClient);
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
			if (other >= 1 && other <= MaxClients)
			{
				int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

				TFTeam team = TF2_GetClientTeam(other);
				//set teammates crit heals to max with syringes
				if(other != owner && TF2_GetClientTeam(owner) == team)
				{
					// int dmg = GetEntProp(iClient, Prop_Data, "m_lastDamageAmount");
					float dmgTime = GetEntDataFloat(other,8832); //m_flLastDamageTime
					if(GetGameTime() < dmgTime+15.0)
					{
						SetEntDataFloat(other,8832,dmgTime-3.0,true); //reduce by 3 seconds on-hit
						EmitSoundToClient(owner,"weapons/syringegun_reload_air2.wav");
						EmitSoundToClient(other,"weapons/syringegun_reload_air2.wav");
						// if(wepIndex==36)
						// {
						// 	SetHudTextParams(0.1, -0.16, 0.1, 255, 255, 255, 255);
						// 	ShowHudText(owner,2,"+3 HP");
						// 	TF2Util_TakeHealth(owner,3.0);
						// }
					}
					else
					{
						if(!TF2_IsPlayerInCondition(other,TFCond_Cloaked)&&!TF2_IsPlayerInCondition(other,TFCond_CloakFlicker))
						{
							if(team == TFTeam_Blue)
								CreateParticle(other,"soldierbuff_blue_buffed",1.0,_,_,_,_,_,_,false,false);
							else if(team == TFTeam_Red)
								CreateParticle(other,"soldierbuff_red_buffed",1.0,_,_,_,_,_,_,false,false);
						}
						EmitSoundToClient(owner,"player/recharged.wav");
						EmitSoundToClient(other,"player/recharged.wav");
					}
				}
				return Plugin_Stop;
			}
			else if (other == 0)
			{
				CreateParticle(entity,"impact_metal",1.0,_,_,_,_,_,_,false);
				// SDKHook(entity, SDKHook_Touch, needleOnTouch);
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
	if (StrEqual(class, "tf_projectile_flare") && 740 == wepIndex)
	{
		if (other >= 1 && other <= MaxClients)
		{
			if(TF2_GetClientTeam(owner) != TF2_GetClientTeam(other))
				SetEntProp(entity, Prop_Data, "m_iHealth",1);
		}
		else if(other==0)
		{
			if(GetEntProp(entity, Prop_Data, "m_iHealth") == 0)
			{
				SDKHook(entity, SDKHook_Touch, flareOnTouch);
				return Plugin_Handled;
			}
		}
		return Plugin_Changed;
	}
	if (StrEqual(class, "tf_projectile_flare") && 595 == wepIndex)
	{
		if (other >= 1 && other <= MaxClients)
		{
			if(TF2_GetClientTeam(owner) != TF2_GetClientTeam(other) && TF2Util_GetPlayerBurnDuration(other)>0)
			{
				if(!isMiniKritzed(owner,other))
					TF2_AddCondition(other,TFCond_MarkedForDeathSilent,0.03);
			}
		}
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
				float vel[3],force[3];
				GetEntPropVector(entity, Prop_Data, "m_vecVelocity",vel);
				float velMag = GetVectorLength(vel)*1.5;
				vel[0]*=-1.0;vel[1]*=-1.0;vel[2]*=-1.0;
				//get direction between orb and player
				force[0]=targetPos[0]-flarePos[0];
				force[1]=targetPos[1]-flarePos[1];
				force[2]=targetPos[2]-flarePos[2];
				float mag = GetVectorLength(force);
				force[0]/=mag;force[1]/=mag;force[2]/=mag;
				//multiply direction and orb velocity for push force
				mag = velMag*(150-dist)/150;
				force[0]*=mag;force[1]*=mag;force[2]*=mag;
				//apply force from orb velocity and distance from orb
				TeleportEntity(owner,NULL_VECTOR,NULL_VECTOR,vel);
				TeleportEntity(owner,NULL_VECTOR,NULL_VECTOR,force);
				SDKHooks_TakeDamage(owner, owner, owner, damage, type, weapon, NULL_VECTOR, flarePos);
				TF2_AddCondition(owner,TFCond_BlastJumping,3.0);
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
			ScaleVector(vScaledNormal, 2.0);
			ScaleVector(vNormal, 150.0);
			
			float vBounceVec[3];
			SubtractVectors(vVelocity, vScaledNormal, vBounceVec);
			ScaleVector(vBounceVec, 0.05);
			vBounceVec[2] = 0.0;

			AddVectors(vNormal,vBounceVec,vScaledNormal);
				
			float vNewAngles[3];
			GetVectorAngles(vNormal, vNewAngles);
			
			TeleportEntity(entity, NULL_VECTOR, vNewAngles, vScaledNormal);
			SetEntProp(entity, Prop_Data, "m_iHealth",1);
			SDKUnhook(entity,SDKHook_Touch,flareOnTouch);
			CreateTimer(0.1,RotateFlare,entity,TIMER_REPEAT);
		}
	}
	return Plugin_Handled;
}

Action RotateFlare(Handle timer, int entity)
{
	if(IsValidEntity(entity))
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

Action KillOrb(Handle timer, int flare)
{
	if(IsValidEntity(flare))
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

void AirblastPush(int client)
{
	int primary = TF2Util_GetPlayerLoadoutEntity(client, TFWeaponSlot_Primary, true);
	int primaryIndex = -1;
	if(primary >= 0) primaryIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
	float meter = GetEntPropFloat(client, Prop_Send, "m_flItemChargeMeter", 0);
	if (primaryIndex==1178) meter = 100.0;
	meter *= PRESSURE_FORCE;
	float force[3],angles[3],vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity",vel);
	GetClientEyeAngles(client,angles);
	float angle1 = angles[1]*0.01745329;
	float angle2 = angles[0]*0.01745329;
	force[0] = Cosine(angle1) * Cosine(angle2);
	force[1] = Sine(angle1) * Cosine(angle2);
	force[2] = Sine(angle2);
	force[0]*=-1*meter;force[1]*=-1*meter;force[2]*=meter;
	// PrintToChat(client,"%.2f | %.2f %.2f %.2f",meter/4,force[0],force[1],force[2]);
	vel[0]+=force[0]; vel[1]+=force[1]; vel[2]+=force[2];

	TeleportEntity(client,_,_,vel);
	TF2_AddCondition(client,TFCond_BlastJumping,3.0);
}

// Action projSpawn(int entity){
// 	// int col = GetEntProp(entity, Prop_Send, "m_CollisionGroup");
// 	// int sol = GetEntProp(entity, Prop_Send, "m_usSolidFlags");
// 	// int sot = GetEntProp(entity, Prop_Send, "m_nSolidType");
// 	// float grav = GetEntPropFloat(entity, Prop_Data, "m_flGravity");
// 	// PrintToChatAll("%d %d %d %.2f",col,sol,sot,grav);
// 	// int mov1 = GetEntProp(entity, Prop_Data, "m_MoveType");
// 	// int mov2 = GetEntProp(entity, Prop_Data, "m_MoveCollide");
// 	// int mov3 = GetEntProp(entity, Prop_Send, "movetype");
// 	// int mov4 = GetEntProp(entity, Prop_Send, "movecollide");
// 	// float rad = GetEntPropFloat(entity, Prop_Data, "m_flRadius");
// 	// PrintToChatAll("%d %d %d %d %.2f",mov1,mov2,mov3,mov4,rad);

// 	char classname[64];
// 	GetEntityClassname(entity,classname,64);
// 	if((StrContains(classname,"arrow") != -1))
// 	{
// 		SetEntProp(entity, Prop_Send, "m_CollisionGroup",0);
// 		SetEntProp(entity, Prop_Data, "m_CollisionGroup",0);
// 		SetEntData(entity,560,0,_,true);
// 	}
// 	return Plugin_Changed;
// }

void orbSpawn(int entity)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	if (StrEqual(class, "tf_projectile_mechanicalarmorb"))
	{ //destroy short circuit orb much sooner
		CreateTimer(0.5,KillOrb,entity);
	}
}

void PipeSpawn(int grenade)
{
	g_Grenades[grenade] = 0;
}

Action PipeSet(int grenade)
{
	int weapon = GetEntPropEnt(grenade, Prop_Send, "m_hLauncher");
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	int wepIndex = -1;
	if (weapon != -1) wepIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	
	if(wepIndex == 1151)
	{
		if(GetEntProp(grenade, Prop_Send, "m_bTouched")==1)
		{
			if(g_Grenades[grenade] == 0)
			{
				for(int i=0;i<MaxClients;++i)
				{
					if(IsValidClient(i))
					{
						if(TF2_GetClientTeam(owner) != TF2_GetClientTeam(i) || owner == i)
						{
							if(getPlayerDistance(grenade,i)<IRON_DETECT)
							{
								SetEntProp(grenade, Prop_Send, "m_bTouched",2);
								float pos[3];
								GetEntPropVector(grenade, Prop_Send, "m_vecOrigin", pos);
								EmitAmbientSound("weapons/stickybomblauncher_det.wav",pos,grenade);
								g_Grenades[grenade] = 1;
								CreateTimer(0.33,KillNeighbor,grenade);
								break;
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Changed;
}

// Action PipeTouch(int grenade, int other)
// {
// 	int weapon = GetEntPropEnt(grenade, Prop_Send, "m_hLauncher");
// 	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
// 	int wepIndex = -1;
// 	if (weapon != -1) wepIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	
// 	// PrintToChatAll("%d %d %d",grenade,other,g_Grenades[grenade]);
// 	if(wepIndex == 1151)
// 	{
// 		if (IsValidClient(other) && GetEntProp(grenade, Prop_Send, "m_bTouched")==1 && g_Grenades[grenade] == 1)
// 		{
// 			if(TF2_GetClientTeam(owner) != TF2_GetClientTeam(other) || owner == other)
// 			{
// 				SetEntProp(grenade, Prop_Send, "m_bTouched",2);
// 				float pos[3];
// 				GetEntPropVector(grenade, Prop_Send, "m_vecOrigin", pos);
// 				EmitAmbientSound("weapons/stickybomblauncher_det.wav",pos,grenade);
// 				g_Grenades[grenade] = 2;
// 				CreateTimer(0.33,KillNeighbor,grenade);
// 			}
// 		}
// 	}
// 	return Plugin_Changed;
// }

public Action KillNeighbor(Handle timer, int neighbor)
{
	g_Grenades[neighbor] = 0;
	int weapon = GetEntPropEnt(neighbor, Prop_Send, "m_hLauncher");
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	float pos2[3],vicPos[3];
	GetEntPropVector(neighbor, Prop_Send, "m_vecOrigin", pos2);
	
	CreateParticle(neighbor,"ExplosionCore_MidAir",2.0);
	EmitAmbientSound("weapons/pipe_bomb1.wav",pos2,neighbor);
	for (int j = 1 ; j <= MaxClients ; j++)
	{
		if(IsClientInGame(j))
		{
			GetEntPropVector(j, Prop_Send, "m_vecOrigin", vicPos);
			float dist = GetVectorDistance(vicPos,pos2);
			if(dist<=105 && (TF2_GetClientTeam(owner) != TF2_GetClientTeam(j) || owner == j))
			{
				float damage = 60 - 30*(dist/105);
				int type = DMG_BLAST;
				if(owner == j) damage *= 0.75;
				else{
					int crit = GetEntProp(neighbor, Prop_Send, "m_bCritical");
					if(crit){
						type |= DMG_CRIT;
					}
				}
				SDKHooks_TakeDamage(j, owner, owner, damage, type, weapon, NULL_VECTOR, pos2);
			}
		}
	}
	AcceptEntityInput(neighbor,"Kill");
	return Plugin_Continue;
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

float getPlayerDistance(int clientA, int clientB)
{
	float clientAPos[3], clientBPos[3];
	GetEntPropVector(clientA, Prop_Send, "m_vecOrigin", clientAPos);
	GetEntPropVector(clientB, Prop_Send, "m_vecOrigin", clientBPos);
	return GetVectorDistance(clientAPos,clientBPos);
}

bool isKritzed(int client)
{
	return (TF2_IsPlayerInCondition(client,TFCond_Kritzkrieged) ||
	TF2_IsPlayerInCondition(client,TFCond_CritOnFirstBlood) ||
	TF2_IsPlayerInCondition(client,TFCond_CritOnWin) ||
	TF2_IsPlayerInCondition(client,TFCond_CritOnFlagCapture) ||
	TF2_IsPlayerInCondition(client,TFCond_CritOnKill) ||
	TF2_IsPlayerInCondition(client,TFCond_CritOnDamage) ||
	TF2_IsPlayerInCondition(client,TFCond_CritDemoCharge));
}

bool isMiniKritzed(int client,int victim=-1)
{
	bool result=false;
	if(victim!=-1)
	{
		if (TF2_IsPlayerInCondition(victim,TFCond_Jarated) || TF2_IsPlayerInCondition(victim,TFCond_MarkedForDeath) || TF2_IsPlayerInCondition(victim,TFCond_MarkedForDeathSilent))
			result = true;
	}
	if (TF2_IsPlayerInCondition(client,TFCond_CritMmmph) || TF2_IsPlayerInCondition(client,TFCond_MiniCritOnKill) || TF2_IsPlayerInCondition(client,TFCond_Buffed) || TF2_IsPlayerInCondition(client,TFCond_CritCola))
		result = true;
	return result;
}

stock int GetHealingTarget(int client)
{
	int index = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if( GetEntProp(index, Prop_Send, "m_bHealing") == 1 )
	{
		return GetEntPropEnt(index, Prop_Send, "m_hHealingTarget");
	}
	return -1;
}

stock bool IsValidClient(int client, bool replaycheck = true)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (!CanClientReceiveClassAttributes(client)) return false;
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