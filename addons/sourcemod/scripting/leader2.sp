/*
 * =============================================================================
 * File:		  Leader
 * Type:		  Base
 * Description:   Plugin's base file.
 *
 * Copyright (C)   Anubis Edition. All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 */

#pragma semicolon 1

#include <csgocolors_fix>
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <zombiereloaded>
#include <leader>
#include <basecomm>

#define MARKER_ENTITIES	20
#pragma newdecls required

#define PLUGIN_NAME           "Leader"
#define PLUGIN_AUTHOR         "Anubis, modified by Oz_Lin"
#define PLUGIN_DESCRIPTION    "Allows for a human to be a leader, and give them special functions with it."
#define PLUGIN_VERSION        "3.2"
#define PLUGIN_URL            "https://github.com/Stewart-Anubis"

#define LENGTH_MAX_LINE	1024
#define LENGTH_MED_LINE	512
#define LENGTH_MIN_LINE	256
#define LENGTH_MAX_TEXT	128
#define LENGTH_MED_TEXT	64
#define LENGTH_MIN_TEXT	32

ConVar g_cVDefendVTF = null;
ConVar g_cVDefendVMT = null;
ConVar g_cVFollowVTF = null;
ConVar g_cVFollowVMT = null;
ConVar g_cVSpawnVTF = null;
ConVar g_cVSpawnVMT = null;
ConVar g_cMaxMarker = null;
ConVar g_cRdeReLeader = null;
ConVar g_cVAllowVoting = null;
ConVar g_cVAllowRLVoting = null;
ConVar g_cAdminLeader = null;
ConVar g_cTimerRemoveMute = null;

Handle g_hmp_maxmoney = INVALID_HANDLE;
Handle g_hsv_disable_radar = INVALID_HANDLE;

char g_sDefendVMT[PLATFORM_MAX_PATH];
char g_sDefendVTF[PLATFORM_MAX_PATH];
char g_sFollowVMT[PLATFORM_MAX_PATH];
char g_sFollowVTF[PLATFORM_MAX_PATH];
char g_sSpawnVMT[PLATFORM_MAX_PATH];
char g_sSpawnVTF[PLATFORM_MAX_PATH];
char g_sClientNames[MAXPLAYERS+1][MAX_NAME_LENGTH];
char g_sLeaderTag[LENGTH_MED_TEXT];
char g_sValue_mp_maxmoney[10];
char g_sValue_sv_disable_radar[10];

int g_iLeaderMVP;
int g_iLeaderScore;
int g_iCurrentSprite = -1;
int g_iSpriteEntities[MAXPLAYERS+1];
int g_iMarkerEntities[MARKER_ENTITIES+1];
int g_iLeaderClient = -1;
int g_iMarkerCount = 0;
int g_iVoteCount[MAXPLAYERS+1];
int g_iVoteRemoveCount[MAXPLAYERS+1];
int g_iVotedFor[MAXPLAYERS+1];
int g_iVotedRemovedFor[MAXPLAYERS+1];
int g_iBeamSprite = -1;
int g_iHaloSprite = -1;
int g_iGreyColor[4] = {128, 128, 128, 255};
int g_iBeaconSerial[MAXPLAYERS+1] = { 0, ... };
int g_iSerial_Gen = 0;
int g_iMaxMarker = 5;
int g_iRemoveMarker = 0;

float g_fTimerRemoveMute = 15.0;

bool g_bMarkerActive = false;
bool g_bBeaconActive = false;
bool g_bAllowVoting = false;
bool g_bAdminLeader = false;
bool g_bAllowRLVoting = false;
bool g_bRoundEndRemoveL = false;
bool g_bMuteStatus = false;
bool g_bMuteClient[MAXPLAYERS+1] = {false, ...};

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	LoadTranslations("leader2.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath);

	RegConsoleCmd("sm_leader", Command_Leader);
	RegConsoleCmd("sm_lmute", Command_Mute);
	RegConsoleCmd("sm_le", Command_Leader);
	RegConsoleCmd("sm_currentleader", CurrentLeader);
	RegConsoleCmd("sm_cl", CurrentLeader);
	RegConsoleCmd("sm_voteleader", Command_VoteLeader, "Usage: sm_voteleader <player>");
	RegConsoleCmd("sm_vl", Command_VoteLeader, "Usage: sm_vl <player>");
	RegConsoleCmd("sm_voteremoveleader", Command_VoteRemoveLeader, "Usage: sm_voteremoveleader <player>");
	RegConsoleCmd("sm_vrl", Command_VoteRemoveLeader, "Usage: sm_vrl <player>");
	RegAdminCmd("sm_removeleader", RemoveTheLeader, ADMFLAG_GENERIC);
	RegAdminCmd("sm_rl", RemoveTheLeader, ADMFLAG_GENERIC);

	g_cVDefendVMT = CreateConVar("sm_leader_defend_vmt", "materials/sg/sgdefend.vmt", "The defend here .vmt file");
	g_cVDefendVTF = CreateConVar("sm_leader_defend_vtf", "materials/sg/sgdefend.vtf", "The defend here .vtf file");
	g_cVFollowVMT = CreateConVar("sm_leader_follow_vmt", "materials/sg/sgfollow.vmt", "The follow me .vmt file");
	g_cVFollowVTF = CreateConVar("sm_leader_follow_vtf", "materials/sg/sgfollow.vtf", "The follow me .vtf file");
	g_cVSpawnVMT = CreateConVar("sm_leader_spawn_vmt", "materials/sg/sgspawn.vmt", "The zombie spawn .vmt file");
	g_cVSpawnVTF = CreateConVar("sm_leader_spawn_vtf", "materials/sg/sgspawn.vtf", "The zombie spawn .vtf file");
	g_cVAllowVoting = CreateConVar("sm_leader_allow_votes", "1", "Determines whether players can vote for leaders.");
	g_cVAllowRLVoting = CreateConVar("sm_leader_remove_leader_votes", "1", "Determines whether players can vote for remove leaders.");
	g_cAdminLeader = CreateConVar("sm_leader_admin_leader", "1", "Determines whether Admin can access menu leader, without voting.");
	g_cMaxMarker = CreateConVar("sm_leader_max_markers", "5", "Determines maximum number of markers. Max 20");
	g_cRdeReLeader = CreateConVar("sm_leader_roundend_rleader", "1", "Determine whether to remove the leader at the end of the round.");
	g_cTimerRemoveMute = CreateConVar("sm_leader_timer_removemute", "15.0", "Determine how long the players were speechless after applying the Mute All (Avoid cheating leader).");

	g_cVDefendVMT.AddChangeHook(ConVarChange);
	g_cVDefendVTF.AddChangeHook(ConVarChange);
	g_cVFollowVMT.AddChangeHook(ConVarChange);
	g_cVFollowVTF.AddChangeHook(ConVarChange);
	g_cVSpawnVMT.AddChangeHook(ConVarChange);
	g_cVSpawnVTF.AddChangeHook(ConVarChange);
	g_cVAllowVoting.AddChangeHook(ConVarChange);
	g_cVAllowRLVoting.AddChangeHook(ConVarChange);
	g_cAdminLeader.AddChangeHook(ConVarChange);
	g_cMaxMarker.AddChangeHook(ConVarChange);
	g_cRdeReLeader.AddChangeHook(ConVarChange);
	g_cTimerRemoveMute.AddChangeHook(ConVarChange);

	AutoExecConfig(true, "leader");

	g_cVDefendVTF.GetString(g_sDefendVTF, sizeof(g_sDefendVTF));
	g_cVDefendVMT.GetString(g_sDefendVMT, sizeof(g_sDefendVMT));
	g_cVFollowVTF.GetString(g_sFollowVTF, sizeof(g_sFollowVTF));
	g_cVFollowVMT.GetString(g_sFollowVMT, sizeof(g_sFollowVMT));
	g_cVSpawnVTF.GetString(g_sSpawnVTF, sizeof(g_sSpawnVTF));
	g_cVSpawnVMT.GetString(g_sSpawnVMT, sizeof(g_sSpawnVMT));

	AddFileToDownloadsTable(g_sDefendVTF);
	AddFileToDownloadsTable(g_sDefendVMT);
	AddFileToDownloadsTable(g_sFollowVTF);
	AddFileToDownloadsTable(g_sFollowVMT);
	AddFileToDownloadsTable(g_sSpawnVTF);
	AddFileToDownloadsTable(g_sSpawnVMT);

	PrecacheGeneric(g_sDefendVTF, true);
	PrecacheGeneric(g_sDefendVMT, true);
	PrecacheGeneric(g_sFollowVTF, true);
	PrecacheGeneric(g_sFollowVMT, true);
	PrecacheGeneric(g_sSpawnVTF, true);
	PrecacheGeneric(g_sSpawnVMT, true);

	g_bAllowVoting = g_cVAllowVoting.BoolValue;
	g_bAllowRLVoting = g_cVAllowRLVoting.BoolValue;
	g_bAdminLeader = g_cAdminLeader.BoolValue;
	g_iMaxMarker = g_cMaxMarker.IntValue;
	g_bRoundEndRemoveL = g_cRdeReLeader.BoolValue;
	g_fTimerRemoveMute = g_cTimerRemoveMute.FloatValue;

	g_hmp_maxmoney = FindConVar("mp_maxmoney");
	GetConVarString(g_hmp_maxmoney, g_sValue_mp_maxmoney, sizeof(g_sValue_mp_maxmoney));
	g_hsv_disable_radar = FindConVar("sv_disable_radar");
	GetConVarString(g_hsv_disable_radar, g_sValue_sv_disable_radar, sizeof(g_sValue_sv_disable_radar));

	RegPluginLibrary("leader");
}

public void ConVarChange(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	g_cVDefendVTF.GetString(g_sDefendVTF, sizeof(g_sDefendVTF));
	g_cVDefendVMT.GetString(g_sDefendVMT, sizeof(g_sDefendVMT));
	g_cVFollowVTF.GetString(g_sFollowVTF, sizeof(g_sFollowVTF));
	g_cVFollowVMT.GetString(g_sFollowVMT, sizeof(g_sFollowVMT));
	g_cVSpawnVTF.GetString(g_sSpawnVTF, sizeof(g_sSpawnVTF));
	g_cVSpawnVMT.GetString(g_sSpawnVMT, sizeof(g_sSpawnVMT));

	AddFileToDownloadsTable(g_sDefendVTF);
	AddFileToDownloadsTable(g_sDefendVMT);
	AddFileToDownloadsTable(g_sFollowVTF);
	AddFileToDownloadsTable(g_sFollowVMT);
	AddFileToDownloadsTable(g_sSpawnVTF);
	AddFileToDownloadsTable(g_sSpawnVMT);

	PrecacheGeneric(g_sDefendVTF, true);
	PrecacheGeneric(g_sDefendVMT, true);
	PrecacheGeneric(g_sFollowVTF, true);
	PrecacheGeneric(g_sFollowVMT, true);
	PrecacheGeneric(g_sSpawnVTF, true);
	PrecacheGeneric(g_sSpawnVMT, true);

	g_bAllowVoting = g_cVAllowVoting.BoolValue;
	g_bAllowRLVoting = g_cVAllowRLVoting.BoolValue;
	g_bAdminLeader = g_cAdminLeader.BoolValue;
	g_iMaxMarker = g_cMaxMarker.IntValue;
	g_bRoundEndRemoveL = g_cRdeReLeader.BoolValue;
	g_fTimerRemoveMute = g_cTimerRemoveMute.FloatValue;
}

public void OnMapStart()
{
	AddFileToDownloadsTable(g_sDefendVTF);
	AddFileToDownloadsTable(g_sDefendVMT);
	AddFileToDownloadsTable(g_sFollowVTF);
	AddFileToDownloadsTable(g_sFollowVMT);
	AddFileToDownloadsTable(g_sSpawnVTF);
	AddFileToDownloadsTable(g_sSpawnVMT);

	PrecacheGeneric(g_sDefendVTF, true);
	PrecacheGeneric(g_sDefendVMT, true);
	PrecacheGeneric(g_sFollowVTF, true);
	PrecacheGeneric(g_sFollowVMT, true);
	PrecacheGeneric(g_sSpawnVTF, true);
	PrecacheGeneric(g_sSpawnVMT, true);

	Handle gameConfig = LoadGameConfigFile("funcommands.games");
	if (gameConfig == null)
	{
		SetFailState("Unable to load game config funcommands.games");
		return;
	}

	char buffer[PLATFORM_MAX_PATH];
	if (GameConfGetKeyValue(gameConfig, "SpriteBeam", buffer, sizeof(buffer)) && buffer[0])
	{
		g_iBeamSprite = PrecacheModel(buffer);
	}
	if (GameConfGetKeyValue(gameConfig, "SpriteHalo", buffer, sizeof(buffer)) && buffer[0])
	{
		g_iHaloSprite = PrecacheModel(buffer);
	}
}

public void OnClientPutInServer(int client)
{
	if (IsValidClient(client) && g_bMuteStatus)
	{
		g_bMuteClient[client] = BaseComm_SetClientMute(client, true);
	}
}

public void CreateBeacon(int client)
{
	g_iBeaconSerial[client] = ++g_iSerial_Gen;
	CreateTimer(1.0, Timer_Beacon, client | (g_iSerial_Gen << 7), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void KillBeacon(int client)
{
	g_iBeaconSerial[client] = 0;

	if (IsClientInGame(client))
	{
		SetEntityRenderColor(client, 255, 255, 255, 255);
	}
}

public void KillAllBeacons()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		KillBeacon(i);
	}
}

public void PerformBeacon(int client)
{
	if (g_iBeaconSerial[client] == 0)
	{
		CreateBeacon(client);
		LogAction(client, client, "\"%L\" set a beacon on himself", client);
	}
	else
	{
		KillBeacon(client);
		LogAction(client, client, "\"%L\" removed a beacon on himself", client);
	}
}

public Action Timer_Beacon(Handle timer, any value)
{
	int client = value & 0x7f;
	int serial = value >> 7;

	if (!IsClientInGame(client) || !IsPlayerAlive(client) || g_iBeaconSerial[client] != serial)
	{
		KillBeacon(client);
		return Plugin_Stop;
	}

	float vec[3];
	GetClientAbsOrigin(client, vec);
	vec[2] += 10;

	TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_iBeamSprite, g_iHaloSprite, 0, 15, 0.5, 5.0, 0.0, g_iGreyColor, 10, 0);
	TE_SendToAll();

	int rainbowColor[4];
	float i = GetGameTime();
	float Frequency = 2.5;
	rainbowColor[0] = RoundFloat(Sine(Frequency * i + 0.0) * 127.0 + 128.0);
	rainbowColor[1] = RoundFloat(Sine(Frequency * i + 2.0943951) * 127.0 + 128.0);
	rainbowColor[2] = RoundFloat(Sine(Frequency * i + 4.1887902) * 127.0 + 128.0);
	rainbowColor[3] = 255;

	TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 0.6, 10.0, 0.5, rainbowColor, 10, 0);

	TE_SendToAll();

	GetClientEyePosition(client, vec);

	return Plugin_Continue;
}

public int AttachSprite(int client, char[] sprite) //https://forums.alliedmods.net/showpost.php?p=1880207&postcount=5
{
	if(!IsPlayerAlive(client))
	{
		return -1;
	}

	char iTarget[16], sTargetname[64];
	GetEntPropString(client, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	Format(iTarget, sizeof(iTarget), "Client%d", client);
	DispatchKeyValue(client, "targetname", iTarget);

	float Origin[3];
	GetClientEyePosition(client, Origin);
	Origin[2] += 45.0;

	int Ent = CreateEntityByName("env_sprite");
	if(!Ent) return -1;

	DispatchKeyValue(Ent, "model", sprite);
	DispatchKeyValue(Ent, "classname", "env_sprite");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.1");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchSpawn(Ent);
	TeleportEntity(Ent, Origin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString(iTarget);
	AcceptEntityInput(Ent, "SetParent", Ent, Ent, 0);

	DispatchKeyValue(client, "targetname", sTargetname);

	return Ent;
}

public void RemoveSprite(int client)
{
	if (g_iSpriteEntities[client] != -1 && IsValidEdict(g_iSpriteEntities[client]))
	{
		char m_szClassname[64];
		GetEdictClassname(g_iSpriteEntities[client], m_szClassname, sizeof(m_szClassname));
		if(strcmp("env_sprite", m_szClassname)==0)
		AcceptEntityInput(g_iSpriteEntities[client], "Kill");
	}
	g_iSpriteEntities[client] = -1;
}

public void RemoveAllMarker()
{
	if (g_iMarkerCount >= 1)
	{
		for (int m = 1; m < g_iMarkerCount+1; m++)
		{
			if (g_iMarkerEntities[m] != -1 && IsValidEdict(g_iMarkerEntities[m]))
			{
				char m_szClassname[64];
				GetEdictClassname(g_iMarkerEntities[m], m_szClassname, sizeof(m_szClassname));
				if(strcmp("env_sprite", m_szClassname)==0)
				AcceptEntityInput(g_iMarkerEntities[m], "Kill");
			}
			g_iMarkerEntities[m] = -1;
		}
	}
	g_iMarkerCount = 0;
	g_iRemoveMarker = 0;
}

public void RemoveMarker(int Marker)
{
	if (g_iMarkerEntities[Marker] != -1 && IsValidEdict(g_iMarkerEntities[Marker]))
	{
		char m_szClassname[64];
		GetEdictClassname(g_iMarkerEntities[Marker], m_szClassname, sizeof(m_szClassname));
		if(strcmp("env_sprite", m_szClassname)==0)
		AcceptEntityInput(g_iMarkerEntities[Marker], "Kill");
	}
	g_iMarkerEntities[Marker] = -1;
}

public void SetLeader(int client)
{
	if(IsValidClient(g_iLeaderClient))
	{
		RemoveLeader(g_iLeaderClient);
		CPrintToChatAll("%t", "Leader has been removed!");
	}

	if(IsValidClient(client))
	{
		g_iLeaderClient = client;

		CS_GetClientClanTag(client, g_sLeaderTag, sizeof(g_sLeaderTag));
		//CS_SetClientClanTag(client, "[Leader]");

		g_iLeaderMVP = CS_GetMVPCount(client);
		CS_SetMVPCount(client, 99);

		g_iLeaderScore = CS_GetClientContributionScore(client);
		CS_SetClientContributionScore(client, 9999);

		g_iCurrentSprite = -1;
	}

	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		g_iVotedFor[i] = -1;
		g_iVotedRemovedFor[i] = -1;
		g_iVoteCount[i] = 0;
		g_iVoteRemoveCount[i] = 0;
	}
}

public void RemoveLeader(int client)
{
	//CS_SetClientClanTag(client, g_sLeaderTag);
	CS_SetMVPCount(client, g_iLeaderMVP);
	CS_SetClientContributionScore(client, g_iLeaderScore);

	RemoveSprite(client);
	RemoveAllMarker();

	if(g_bBeaconActive)
	{
		KillBeacon(client);
	}

	g_iCurrentSprite = -1;
	g_iLeaderClient = -1;
	g_bMarkerActive = false;
	g_bBeaconActive = false;
}

public int SpawnMarker(int client, char[] sprite)
{
	if(!IsPlayerAlive(client))
	{
		return -1;
	}

	float Origin[3];
	GetClientEyePosition(client, Origin);
	Origin[2] += 25.0;

	int Ent = CreateEntityByName("env_sprite");
	if(!Ent) return -1;

	DispatchKeyValue(Ent, "model", sprite);
	DispatchKeyValue(Ent, "classname", "env_sprite");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.1");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchSpawn(Ent);
	TeleportEntity(Ent, Origin, NULL_VECTOR, NULL_VECTOR);

	return Ent;
}

public Action CurrentLeader(int client, int args)
{
	if(IsValidClient(g_iLeaderClient))
	{
		CPrintToChat(client, "%t", "The current leader", g_iLeaderClient);
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(client, "%t", "No current leader");
		return Plugin_Handled;
	}
}

public Action RemoveTheLeader(int client, int args)
{
	if(IsValidClient(g_iLeaderClient))
	{
		CPrintToChatAll("%t", "Leader has been removed!");
		RemoveLeader(g_iLeaderClient);

		for (int i = 1; i <= MAXPLAYERS; i++)
		{
			g_iVotedFor[i] = -1;
			g_iVotedRemovedFor[i] = -1;
			g_iVoteCount[i] = 0;
			g_iVoteRemoveCount[i] = 0;
		}
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(client, "%t", "No current leader");
		return Plugin_Handled;
	}
}

public Action Command_Leader(int client, int args)
{
	if(ZR_IsClientZombie(client))
	{
		CReplyToCommand(client, "%t", "You are not a human");
		return Plugin_Handled;
	}
	else if(IsValidGenericAdmin(client) && g_bAdminLeader)
	{
		if(args == 1)
		{
			char arg1[65];
			GetCmdArg(1, arg1, sizeof(arg1));
			int target = FindTarget(client, arg1, false, false);
			if (target == -1)
			{
				return Plugin_Handled;
			}

			if(target == g_iLeaderClient)
			{
				LeaderMenu(target);
			}
			else
			{
				if(IsPlayerAlive(target))
				{
					SetLeader(target);
					CPrintToChatAll("%t", "The new leader", target);
					CPrintToChat(target, "%t", "You are now the leader");
					LeaderMenu(target);
				}
				else
				{
					CReplyToCommand(client, "%t", "The target has to be alive");
				}
			}
		}
		else if(args == 0)
		{
			if(client == g_iLeaderClient)
			{
				LeaderMenu(client);
				return Plugin_Handled;
			}
			if(IsPlayerAlive(client))
			{
				SetLeader(client);
				CPrintToChatAll("%t", "The new leader", client);
				CPrintToChat(client, "%t", "You are now the leader");
				LeaderMenu(client);
			}
			else
			{
				CReplyToCommand(client, "%t", "The target has to be alive");
			}
		}
		else if(client == g_iLeaderClient)
		{
			LeaderMenu(client);
			return Plugin_Handled;
		}
		else
		{
			CReplyToCommand(client, "%t", "Usage sm_leader");
		}
	}
	else if(client == g_iLeaderClient)
	{
		LeaderMenu(client);
	}
	else
	{
		PrintToChat(client, "%t", "No Access");
	}
	return Plugin_Handled;
}

void LeaderMenu(int client, bool b_sprite = false, bool b_marker = false)
{
	if(!IsValidClient(client))
	{
		return;
	}

	Menu m_LeaderMenu = new Menu(LeaderMenu_Handler);
	SetGlobalTransTarget(client);
	SendConVarValue(client, g_hmp_maxmoney, "0");
	SendConVarValue(client, g_hsv_disable_radar, "1");

	char s_Title[LENGTH_MAX_TEXT];
	char s_Resign[LENGTH_MED_TEXT];
	char s_Sprite[LENGTH_MED_TEXT];
	char s_Marker[LENGTH_MED_TEXT];
	char s_Beacon[LENGTH_MED_TEXT];
	char s_Muteall[LENGTH_MED_TEXT];
	char s_TSprite[LENGTH_MED_TEXT];
	char s_TMarker[LENGTH_MED_TEXT];
	char s_TBeacon[LENGTH_MED_TEXT];
	char s_TBMute[LENGTH_MED_TEXT];

	switch (g_iCurrentSprite)
	{
		case 0:
		Format(s_TSprite, sizeof(s_TSprite), "%t", "Defend");
		case 1:
		Format(s_TSprite, sizeof(s_TSprite), "%t", "Follow");
		default:
		Format(s_TSprite, sizeof(s_TSprite), "%t", "None");
	}

	if(g_bMarkerActive) Format(s_TMarker, sizeof(s_TMarker), "%i", g_iMarkerCount);
	else Format(s_TMarker, sizeof(s_TMarker), "%t", "No");
	
	if(g_bBeaconActive) Format(s_TBeacon, sizeof(s_TBeacon), "%t", "Yes");
	else Format(s_TBeacon, sizeof(s_TBeacon), "%t", "No");

	if (g_bMuteStatus) Format(s_TBMute, sizeof(s_TBMute), "%t", "Yes");
	else Format(s_TBMute, sizeof(s_TBMute), "%t", "No");

	if (!b_sprite && b_marker) // Menu MarkerMenu
	{
		char s_RemoveMarker[LENGTH_MED_TEXT];
		char s_DefendMarker[LENGTH_MED_TEXT];
		char s_SpawnMarker[LENGTH_MED_TEXT];

		Format(s_Title, sizeof(s_Title), "%t", "Leader Menu Title Marker", s_TSprite, s_TMarker, s_TBeacon, s_TBMute);
		Format(s_DefendMarker, sizeof(s_DefendMarker), "%t", "Defend Marker");
		Format(s_SpawnMarker, sizeof(s_SpawnMarker), "%t", "Spawn Marker");
		Format(s_RemoveMarker, sizeof(s_RemoveMarker), "%t", "Remove Marker");

		m_LeaderMenu.SetTitle(s_Title);
		m_LeaderMenu.AddItem("m_defendmarker", s_DefendMarker);
		m_LeaderMenu.AddItem("m_spawnmarker", s_SpawnMarker);
		m_LeaderMenu.AddItem("m_removemarker", s_RemoveMarker);
		m_LeaderMenu.AddItem("", "", ITEMDRAW_NOTEXT);
		m_LeaderMenu.AddItem("", "", ITEMDRAW_NOTEXT);
		m_LeaderMenu.AddItem("", "", ITEMDRAW_NOTEXT);

		m_LeaderMenu.ExitBackButton = true;
	}
	else if (b_sprite && !b_marker) // SpriteMenu
	{
		char s_None[LENGTH_MED_TEXT];
		char s_Defend[LENGTH_MED_TEXT];
		char s_Follow[LENGTH_MED_TEXT];

		Format(s_Title, sizeof(s_Title), "%t", "Leader Menu Title Sprite", s_TSprite, s_TMarker, s_TBeacon, s_TBMute);
		Format(s_None, sizeof(s_None), "%t", "No Sprite");
		Format(s_Defend, sizeof(s_Defend), "%t", "Defend Here");
		Format(s_Follow, sizeof(s_Follow), "%t", "Follow Me");

		m_LeaderMenu.SetTitle(s_Title);
		m_LeaderMenu.AddItem("m_none", s_None);
		m_LeaderMenu.AddItem("m_defend", s_Defend);
		m_LeaderMenu.AddItem("m_follow", s_Follow);
		m_LeaderMenu.AddItem("", "", ITEMDRAW_NOTEXT);
		m_LeaderMenu.AddItem("", "", ITEMDRAW_NOTEXT);
		m_LeaderMenu.AddItem("", "", ITEMDRAW_NOTEXT);

		m_LeaderMenu.ExitBackButton = true;
	}
	else // Menu Leader
	{
		Format(s_Title, sizeof(s_Title), "%t", "Leader Menu Title", s_TSprite, s_TMarker, s_TBeacon, s_TBMute);
		Format(s_Resign, sizeof(s_Resign), "%t", "Resign from Leader");
		Format(s_Sprite, sizeof(s_Sprite), "%t", "Sprite Menu");
		Format(s_Marker, sizeof(s_Marker), "%t", "Marker Menu");
		Format(s_Beacon, sizeof(s_Beacon), "%t", "Toggle Beacon");
		Format(s_Muteall, sizeof(s_Muteall), "%t", "Toggle Mute");

		m_LeaderMenu.SetTitle(s_Title);
		m_LeaderMenu.AddItem("m_resign", s_Resign);
		m_LeaderMenu.AddItem("m_sprite", s_Sprite);
		m_LeaderMenu.AddItem("m_marker", s_Marker);
		m_LeaderMenu.AddItem("m_beacon", s_Beacon);
		m_LeaderMenu.AddItem("m_muteall", s_Muteall);
		m_LeaderMenu.AddItem("", "", ITEMDRAW_NOTEXT);

		m_LeaderMenu.ExitButton = true;
	}

	m_LeaderMenu.Display(client, MENU_TIME_FOREVER);
}

public int LeaderMenu_Handler(Handle m_LeaderMenu, MenuAction action, int client, int itemNum)
{
	if(action == MenuAction_End)
	{
		delete m_LeaderMenu;
	}

	if(g_iLeaderClient == client && IsValidClient(client))
	{
		if(action == MenuAction_Select)
		{
			char info[32];
			GetMenuItem(m_LeaderMenu, itemNum, info, sizeof(info));

			// Menu Leader
			if(StrEqual(info, "m_resign"))
			{
				RemoveLeader(client);
				CPrintToChatAll("%t", "Resigned from being leader", client);
				action = MenuAction_Cancel;
			}
			if(StrEqual(info, "m_sprite"))
			{
				LeaderMenu(client, true);
			}
			if(StrEqual(info, "m_marker"))
			{
				LeaderMenu(client, false, true);
			}
			if(StrEqual(info, "m_beacon"))
			{
				ToggleBeacon(client);
				LeaderMenu(client);
			}
			if(StrEqual(info, "m_muteall"))
			{
				ToggleMute(client);
				LeaderMenu(client);
			}
			// SpriteMenu
			if(StrEqual(info, "m_none"))
			{
				RemoveSprite(client);
				CPrintToChat(client, "%t", "Sprite removed");
				g_iCurrentSprite = -1;
				LeaderMenu(client, true);
			}
			if(StrEqual(info, "m_defend"))
			{
				RemoveSprite(client);
				g_iSpriteEntities[client] = AttachSprite(client, g_sDefendVMT);
				CPrintToChat(client, "%t", "Sprite changed to Defend Here");
				g_iCurrentSprite = 0;
				LeaderMenu(client, true);
			}
			if(StrEqual(info, "m_follow"))
			{
				RemoveSprite(client);
				g_iSpriteEntities[client] = AttachSprite(client, g_sFollowVMT);
				CPrintToChat(client, "%t", "Sprite changed to Follow Me");
				g_iCurrentSprite = 1;
				LeaderMenu(client, true);
			}
			// Menu MarkerMenu
			if(StrEqual(info, "m_defendmarker"))
			{
				if (g_iMarkerCount >= g_iMaxMarker)
				{
					g_iRemoveMarker++;
					if (g_iRemoveMarker > g_iMaxMarker)
					{
						g_iRemoveMarker = 1;
					}
					RemoveMarker(g_iRemoveMarker);
					g_iMarkerEntities[g_iRemoveMarker] = SpawnMarker(client, g_sDefendVMT);
					CPrintToChat(client, "%t", "Defend Here marker placed" ,g_iRemoveMarker);
					LeaderMenu(client, false, true);
					
				}
				else
				{
					g_iMarkerCount++;
					g_iMarkerEntities[g_iMarkerCount] = SpawnMarker(client, g_sDefendVMT);
					CPrintToChat(client, "%t", "Defend Here marker placed" ,g_iMarkerCount);
					g_bMarkerActive = true;
					LeaderMenu(client, false, true);
				}
			}
			if(StrEqual(info, "m_spawnmarker"))
			{
				if (g_iMarkerCount >= g_iMaxMarker)
				{
					g_iRemoveMarker++;
					if (g_iRemoveMarker > g_iMaxMarker)
					{
						g_iRemoveMarker = 1;
					}
					RemoveMarker(g_iRemoveMarker);
					g_iMarkerEntities[g_iRemoveMarker] = SpawnMarker(client, g_sSpawnVMT);
					CPrintToChat(client, "%t", "Zombie Spawn marker placed" ,g_iRemoveMarker);
					LeaderMenu(client, false, true);

				}
				else
				{
					g_iMarkerCount++;
					g_iMarkerEntities[g_iMarkerCount] = SpawnMarker(client, g_sSpawnVMT);
					CPrintToChat(client, "%t", "Zombie Spawn marker placed" ,g_iMarkerCount);
					g_bMarkerActive = true;
					LeaderMenu(client, false, true);
				}
			}
			if(StrEqual(info, "m_removemarker"))
			{
				RemoveAllMarker();
				CPrintToChat(client, "%t", "Marker removed");
				g_bMarkerActive = false;
				LeaderMenu(client, false, true);
			}
		}

		if (itemNum == MenuCancel_ExitBack)
		{
			LeaderMenu(client);
		}
	}
	else if(g_iLeaderClient != client && IsValidClient(client))
	{
		
		if (itemNum == MenuCancel_ExitBack || action == MenuAction_Select || action == MenuAction_Cancel)
		{
			if (IsValidClient(client))
			{
				SendConVarValue(client, g_hmp_maxmoney, g_sValue_mp_maxmoney);
				SendConVarValue(client, g_hsv_disable_radar, g_sValue_sv_disable_radar);
			}			
		}
		else action = MenuAction_Cancel;
		
	}
	if (action == MenuAction_Cancel && itemNum != MenuCancel_ExitBack)
	{
		if (IsValidClient(client))
		{
			SendConVarValue(client, g_hmp_maxmoney, g_sValue_mp_maxmoney);
			SendConVarValue(client, g_hsv_disable_radar, g_sValue_sv_disable_radar);
		}
	}
	return 0;
}

public void ToggleBeacon(int client)
{
	if(g_bBeaconActive)
	g_bBeaconActive = false;
	else
	g_bBeaconActive = true;

	PerformBeacon(client);
}

public void OnClientDisconnect(int client)
{
	if (!IsValidClient(client)) return;

	if(client == g_iLeaderClient)
	{
		CPrintToChatAll("%t", "The leader has disconnected");
		RemoveLeader(client);
		RemoveMute();
	}
	else if (g_bMuteClient[client])
	{
		g_bMuteClient[client] = BaseComm_SetClientMute(client, false);
	}

	g_iVoteCount[client] = 0;
}

public Action Event_PlayerDeath(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(client == g_iLeaderClient)
	{
		CPrintToChatAll("%t", "The leader has died");
		RemoveLeader(client);
	}
}

public int ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	if(client == g_iLeaderClient)
	{
		CPrintToChatAll("%t", "The leader has been infected");
		RemoveLeader(client);
	}
}

public void OnMapEnd()
{
	if(IsValidClient(g_iLeaderClient))
	{
		RemoveLeader(g_iLeaderClient);
	}
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		g_iVotedFor[i] = -1;
		g_iVotedRemovedFor[i] = -1;
		g_iVoteCount[i] = 0;
		g_iVoteRemoveCount[i] = 0;
	}
	RemoveMute();
	g_iLeaderClient = -1;
	KillAllBeacons();
}

public Action Event_RoundEnd(Handle event, char[] name, bool dontBroadcast)
{
	if(IsValidClient(g_iLeaderClient) && g_bRoundEndRemoveL)
	{
		RemoveLeader(g_iLeaderClient);
	}

	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		g_iVotedFor[i] = -1;
		g_iVotedRemovedFor[i] = -1;
		g_iVoteCount[i] = 0;
		g_iVoteRemoveCount[i] = 0;
	}

	KillAllBeacons();
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if(client >= 1 && IsValidClient(client) && g_iLeaderClient == client)
	{
		char LeaderText[256];
		Format(LeaderText, sizeof(LeaderText), sArgs);
		StripQuotes(LeaderText);
		if(LeaderText[0] == '/' || LeaderText[0] == '@' || strlen(LeaderText) == 0 || IsChatTrigger())
		{
			return Plugin_Handled;
		}
		if(IsClientInGame(client) && IsPlayerAlive(client))
		{
			CPrintToChatAll("%t", "Leader Chat", client, LeaderText);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Leader_CurrentLeader", Native_CurrentLeader);
	CreateNative("Leader_SetLeader", Native_SetLeader);
	return APLRes_Success;
}

public int Native_CurrentLeader(Handle plugin, int numParams)
{
	return g_iLeaderClient;
}

public int Native_SetLeader(Handle plugin, int numParams)
{
	SetLeader(GetNativeCell(1));
}

public Action Command_VoteLeader(int client, int argc)
{
	if (!client) return Plugin_Handled;

	if(!g_bAllowVoting)
	{
		CReplyToCommand(client, "%t", "Voting for leader is disabled");
		return Plugin_Handled;
	}

	if(IsValidClient(g_iLeaderClient))
	{
		CReplyToCommand(client, "%t", "There is already a leader");
		return Plugin_Handled;
	}

	if(ZR_IsClientZombie(client))
	{
		CReplyToCommand(client, "%t", "You are not a human only humans vote");
		return Plugin_Handled;
	}

	if(argc < 1)
	{
		Menu_VoteLeader_Remove(client);
		return Plugin_Handled;
	}

	else
	{
		char arg[64];
		GetCmdArg(1, arg, sizeof(arg));
		int target = FindTarget(client, arg, true, false);
		if (target == -1)
		{
			return Plugin_Handled;
		}
		VoteLeader(client, target);
	}
	return Plugin_Handled;
}

public Action Command_VoteRemoveLeader(int client, int argc)
{
	if (!client) return Plugin_Handled;

	if(!g_bAllowRLVoting)
	{
		CReplyToCommand(client, "%t", "Voting to remove leader is disabled");
		return Plugin_Handled;
	}

	if(!IsValidClient(g_iLeaderClient))
	{
		CReplyToCommand(client, "%t", "No current leader");
		return Plugin_Handled;
	}

	if(ZR_IsClientZombie(client))
	{
		CReplyToCommand(client, "%t", "You are not a human only humans vote");
		return Plugin_Handled;
	}

	if(argc < 1)
	{
		Menu_VoteLeader_Remove(client, true);
		return Plugin_Handled;
	}

	else
	{
		char arg[64];
		GetCmdArg(1, arg, sizeof(arg));
		int target = FindTarget(client, arg, true, false);
		if (target == -1)
		{
			return Plugin_Handled;
		}
		VoteRemoveLeader(client, target);
	}
	return Plugin_Handled;
}

void Menu_VoteLeader_Remove(int client, bool b_RemoveLeader = false)
{
	if(!IsValidClient(client))
	{
		return;
	}

	Menu VoteLeaderRemove = new Menu(MenuHandler_VoteLeaderRemove);
	SetGlobalTransTarget(client);
	SendConVarValue(client, g_hmp_maxmoney, "0");
	SendConVarValue(client, g_hsv_disable_radar, "1");

	char m_title[LENGTH_MAX_TEXT];
	char strClientID[LENGTH_MIN_TEXT];
	char strClientName[LENGTH_MED_TEXT];

	if (b_RemoveLeader)
	{

		Format(m_title, sizeof(m_title), "%t\n ", "Menu Vote Remove Leader");

		VoteLeaderRemove.SetTitle(m_title);
		VoteLeaderRemove.ExitButton = true;

		if(IsValidClient(g_iLeaderClient))
		{
			IntToString(GetClientUserId(g_iLeaderClient), strClientID, sizeof(strClientID));
			FormatEx(strClientName, sizeof(strClientName), "%N - %t", g_iLeaderClient, "Players Menu", g_iVoteRemoveCount[g_iLeaderClient], GetClientCount(true)/10);
			VoteLeaderRemove.AddItem(strClientID, strClientName);
		}
	}
	else
	{
		int[] alphabetClients = new int[MaxClients+1];

		Format(m_title, sizeof(m_title), "%t\n ", "Leader Menu Vote Player");

		VoteLeaderRemove.SetTitle(m_title);
		VoteLeaderRemove.ExitButton = true;

		for (int aClient = 1; aClient <= MaxClients; aClient++)
		{
			if (IsClientInGame(aClient) && !ZR_IsClientZombie(aClient) && IsValidClient(aClient))
			{
				alphabetClients[aClient] = aClient;
				GetClientName(alphabetClients[aClient], g_sClientNames[alphabetClients[aClient]], sizeof(g_sClientNames[]));
			}
		}

		SortCustom1D(alphabetClients, MaxClients, SortByPlayerName);

		for (int i = 0; i < MaxClients; i++)
		{
			if (alphabetClients[i]!=0) 
			{
				IntToString(GetClientUserId(alphabetClients[i]), strClientID, sizeof(strClientID));
				FormatEx(strClientName, sizeof(strClientName), "%N - %t", alphabetClients[i], "Players Menu", g_iVoteCount[i], GetClientCount(true)/10);
				VoteLeaderRemove.AddItem(strClientID, strClientName);
			}
		}
	}
	if (VoteLeaderRemove.ItemCount == 0) 
	{
		delete(VoteLeaderRemove);
	}
	else
	{
		VoteLeaderRemove.ExitBackButton = (VoteLeaderRemove.ItemCount > 7);
		DisplayMenu(VoteLeaderRemove, client, MENU_TIME_FOREVER);
	}
}

public int MenuHandler_VoteLeaderRemove(Menu VoteLeaderRemove, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_End)
	{
		delete VoteLeaderRemove;
	}

	if (action == MenuAction_Select)
	{
		char info[32], name[32];
		int userid, target;
		
		GetMenuItem(VoteLeaderRemove, itemNum, info, sizeof(info), _, name, sizeof(name));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(client, "[SM] %s", "Player no longer available");
		}
		else
		{
			if(IsValidClient(g_iLeaderClient)) VoteRemoveLeader(client, target);
			else VoteLeader(client, target);
		}
	}

	if (action == MenuAction_Cancel && itemNum != MenuCancel_ExitBack)
	{
		if (IsValidClient(client))
		{
			SendConVarValue(client, g_hmp_maxmoney, g_sValue_mp_maxmoney);
			SendConVarValue(client, g_hsv_disable_radar, g_sValue_sv_disable_radar);
		}
	}
	return 0;
}

public Action VoteLeader(int client, int target)
{
	if(!g_bAllowVoting)
	{
		CReplyToCommand(client, "%t", "Voting for leader is disabled");
		return Plugin_Handled;
	}

	if(IsValidClient(g_iLeaderClient))
	{
		CReplyToCommand(client, "%t", "There is already a leader");
		return Plugin_Handled;
	}

	if(GetClientFromSerial(g_iVotedFor[client]) == target)
	{
		CReplyToCommand(client, "%t", "You ve already voted for this person");
		return Plugin_Handled;
	}

	if(ZR_IsClientZombie(target))
	{
		CReplyToCommand(client, "%t", "You have to vote for a human");
		return Plugin_Handled;
	}

	if(ZR_IsClientZombie(client))
	{
		CReplyToCommand(client, "%t", "You are not a human only humans vote");
		return Plugin_Handled;
	}

	if(GetClientFromSerial(g_iVotedFor[client]) != 0)
	{
		if(IsValidClient(GetClientFromSerial(g_iVotedFor[client]))) {
			g_iVoteCount[GetClientFromSerial(g_iVotedFor[client])]--;
		}
	}
	g_iVoteCount[target]++;
	g_iVotedFor[client] = GetClientSerial(target);
	CPrintToChatAll("%t", "Has voted for", client, target, g_iVoteCount[target], GetClientCount(true)/10);

	if(g_iVoteCount[target] >= GetClientCount(true)/10)
	{
		SetLeader(target);
		CPrintToChatAll("%t", "Has been voted to be the new leader", target);
		LeaderMenu(target);
	}

	return Plugin_Handled;
}

public Action VoteRemoveLeader(int client, int target)
{
	if(!g_bAllowRLVoting)
	{
		CReplyToCommand(client, "%t", "Voting for leader is disabled");
		return Plugin_Handled;
	}

	if(!IsValidClient(g_iLeaderClient))
	{
		CReplyToCommand(client, "%t", "No current leader");
		return Plugin_Handled;
	}

	if(GetClientFromSerial(g_iVotedRemovedFor[client]) == target)
	{
		CReplyToCommand(client, "%t", "You ve already voted for this person");
		return Plugin_Handled;
	}

	if(ZR_IsClientZombie(target))
	{
		CReplyToCommand(client, "%t", "You have to vote for a human");
		return Plugin_Handled;
	}

	if(ZR_IsClientZombie(client))
	{
		CReplyToCommand(client, "%t", "You are not a human only humans vote");
		return Plugin_Handled;
	}

	if(g_iLeaderClient != target)
	{
		CReplyToCommand(client, "%t", "This Player is not the current leader");
		return Plugin_Handled;
	}

	if(GetClientFromSerial(g_iVotedRemovedFor[client]) != 0)
	{
		if(IsValidClient(GetClientFromSerial(g_iVotedRemovedFor[client]))) {
			g_iVoteRemoveCount[GetClientFromSerial(g_iVotedRemovedFor[client])]--;
		}
	}
	g_iVoteRemoveCount[target]++;
	g_iVotedRemovedFor[client] = GetClientSerial(target);
	CPrintToChatAll("%t", "Has voted for Remove", client, target, g_iVoteRemoveCount[target], GetClientCount(true)/10);

	if(g_iVoteRemoveCount[target] >= GetClientCount(true)/10)
	{
		RemoveTheLeader(target, 0);
	}

	return Plugin_Handled;
}

stock int SortByPlayerName(int player1, int player2, const int[] array, Handle hndl)
{
	return strcmp(g_sClientNames[player1], g_sClientNames[player2], false);
}

public Action Command_Mute(int client, int args)
{
	if(client == g_iLeaderClient)
	{
		if(g_bMuteStatus)
		{
			RemoveMute();
		}
		else
		{
			AddMute(client);
		}
	}
	else
	{
		PrintToChat(client, "%t", "No Access");
	}
	return Plugin_Handled;
}

public void ToggleMute(int client)
{
	if(g_bMuteStatus) RemoveMute();
	else AddMute(client);
}

stock void AddMute(int client)
{
	if (!g_bMuteStatus)
	{
		g_bMuteStatus = true;
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (i != client && IsValidClient(i) && !g_bMuteClient[i] && !IsValidGenericAdmin(i))
			{
				g_bMuteClient[i] = BaseComm_SetClientMute(i, true);
			}
		}
	}
	CreateTimer(g_fTimerRemoveMute, TimerRemoveMute, TIMER_DATA_HNDL_CLOSE|TIMER_FLAG_NO_MAPCHANGE);
	CPrintToChatAll("%t", "Mute All");
}

public Action TimerRemoveMute(Handle sTime)
{
	if(g_bMuteStatus) RemoveMute();
}

stock void RemoveMute()
{
	if (g_bMuteStatus)
	{
		g_bMuteStatus = false;
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsValidClient(i) && g_bMuteClient[i])
			{
				g_bMuteClient[i] = BaseComm_SetClientMute(i, false);
			}
		}
	}
	CPrintToChatAll("%t", "Remove Mute All");
}

public bool IsValidGenericAdmin(int client) 
{ 
	return CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, false);
}

stock bool IsValidClient(int client, bool bzrAllowBots = false, bool bzrAllowDead = true)
{
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bzrAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bzrAllowDead && !IsPlayerAlive(client)))
		return false;
	return true;
}

