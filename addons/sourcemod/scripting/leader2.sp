#pragma semicolon 1

#include <colors_csgo>
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <zombiereloaded>
#include <leader>

#define PLUGIN_VERSION "3.2"
#define MARKER_ENTITIES	20
#pragma newdecls required

int leaderMVP, leaderScore, currentSprite = -1, spriteEntities[MAXPLAYERS+1], MarkerEntities[MARKER_ENTITIES+1], leaderClient = -1, MarkerCount = 0;
int voteCount[MAXPLAYERS+1], voteRemoveCount[MAXPLAYERS+1], votedFor[MAXPLAYERS+1], votedremovedFor[MAXPLAYERS+1];

bool markerActive = false, beaconActive = false, allowVoting = false, adminleader = false, allowRLVoting = false, RoundEndRemoveL = false;

ConVar g_cVDefendVTF = null;
ConVar g_cVDefendVMT = null;
ConVar g_cVFollowVTF = null;
ConVar g_cVFollowVMT = null;
ConVar g_cMaxMarker = null;
ConVar g_cRdeReLeader = null;

ConVar g_cVAllowVoting = null;
ConVar g_cVAllowRLVoting = null;

ConVar g_cAdminLeader = null;

char DefendVMT[PLATFORM_MAX_PATH];
char DefendVTF[PLATFORM_MAX_PATH];
char FollowVMT[PLATFORM_MAX_PATH];
char FollowVTF[PLATFORM_MAX_PATH];
char clientNames[MAXPLAYERS+1][MAX_NAME_LENGTH];
char leaderTag[64];

int g_BeamSprite = -1;
int g_HaloSprite = -1;
int greyColor[4] = {128, 128, 128, 255};
int g_BeaconSerial[MAXPLAYERS+1] = { 0, ... };
int g_Serial_Gen = 0;
int g_iMaxMarker = 5;
int g_iRemoveMarker = 0;

public Plugin myinfo = {
	name = "Leader",
	author = "AntiTeal, Anubis Edition",
	description = "Allows for a human to be a leader, and give them special functions with it.",
	version = PLUGIN_VERSION,
	url = "https://antiteal.com"
};

public void OnPluginStart()
{
	LoadTranslations("leader2.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath);
	AddCommandListener(HookPlayerChat, "say");

	RegConsoleCmd("sm_leader", Leader);
	RegConsoleCmd("sm_le", Leader);
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
	g_cVAllowVoting = CreateConVar("sm_leader_allow_votes", "1", "Determines whether players can vote for leaders.");
	g_cVAllowRLVoting = CreateConVar("sm_leader_remove_leader_votes", "1", "Determines whether players can vote for remove leaders.");
	g_cAdminLeader = CreateConVar("sm_leader_admin_leader", "1", "Determines whether Admin can access menu leader, without voting.");
	g_cMaxMarker = CreateConVar("sm_leader_max_markers", "5", "Determines maximum number of markers. Max 20");
	g_cRdeReLeader = CreateConVar("sm_leader_roundend_rleader", "1", "Determine whether to remove the leader at the end of the round.");

	g_cVDefendVMT.AddChangeHook(ConVarChange);
	g_cVDefendVTF.AddChangeHook(ConVarChange);
	g_cVFollowVMT.AddChangeHook(ConVarChange);
	g_cVFollowVTF.AddChangeHook(ConVarChange);
	g_cVAllowVoting.AddChangeHook(ConVarChange);
	g_cVAllowRLVoting.AddChangeHook(ConVarChange);
	g_cAdminLeader.AddChangeHook(ConVarChange);
	g_cMaxMarker.AddChangeHook(ConVarChange);
	g_cRdeReLeader.AddChangeHook(ConVarChange);

	AutoExecConfig(true, "leader");

	g_cVDefendVTF.GetString(DefendVTF, sizeof(DefendVTF));
	g_cVDefendVMT.GetString(DefendVMT, sizeof(DefendVMT));
	g_cVFollowVTF.GetString(FollowVTF, sizeof(FollowVTF));
	g_cVFollowVMT.GetString(FollowVMT, sizeof(FollowVMT));

	AddFileToDownloadsTable(DefendVTF);
	AddFileToDownloadsTable(DefendVMT);
	AddFileToDownloadsTable(FollowVTF);
	AddFileToDownloadsTable(FollowVMT);

	PrecacheGeneric(DefendVTF, true);
	PrecacheGeneric(DefendVMT, true);
	PrecacheGeneric(FollowVTF, true);
	PrecacheGeneric(FollowVMT, true);

	allowVoting = g_cVAllowVoting.BoolValue;
	allowRLVoting = g_cVAllowRLVoting.BoolValue;
	adminleader = g_cAdminLeader.BoolValue;
	g_iMaxMarker = g_cMaxMarker.IntValue;
	RoundEndRemoveL = g_cRdeReLeader.BoolValue;

	RegPluginLibrary("leader");
}

public void ConVarChange(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	g_cVDefendVTF.GetString(DefendVTF, sizeof(DefendVTF));
	g_cVDefendVMT.GetString(DefendVMT, sizeof(DefendVMT));
	g_cVFollowVTF.GetString(FollowVTF, sizeof(FollowVTF));
	g_cVFollowVMT.GetString(FollowVMT, sizeof(FollowVMT));

	AddFileToDownloadsTable(DefendVTF);
	AddFileToDownloadsTable(DefendVMT);
	AddFileToDownloadsTable(FollowVTF);
	AddFileToDownloadsTable(FollowVMT);

	PrecacheGeneric(DefendVTF, true);
	PrecacheGeneric(DefendVMT, true);
	PrecacheGeneric(FollowVTF, true);
	PrecacheGeneric(FollowVMT, true);

	allowVoting = g_cVAllowVoting.BoolValue;
	allowRLVoting = g_cVAllowRLVoting.BoolValue;
	adminleader = g_cAdminLeader.BoolValue;
	g_iMaxMarker = g_cMaxMarker.IntValue;
	RoundEndRemoveL = g_cRdeReLeader.BoolValue;
}

public void OnMapStart()
{
	AddFileToDownloadsTable(DefendVTF);
	AddFileToDownloadsTable(DefendVMT);
	AddFileToDownloadsTable(FollowVTF);
	AddFileToDownloadsTable(FollowVMT);

	PrecacheGeneric(DefendVTF, true);
	PrecacheGeneric(DefendVMT, true);
	PrecacheGeneric(FollowVTF, true);
	PrecacheGeneric(FollowVMT, true);

	Handle gameConfig = LoadGameConfigFile("funcommands.games");
	if (gameConfig == null)
	{
		SetFailState("Unable to load game config funcommands.games");
		return;
	}

	char buffer[PLATFORM_MAX_PATH];
	if (GameConfGetKeyValue(gameConfig, "SpriteBeam", buffer, sizeof(buffer)) && buffer[0])
	{
		g_BeamSprite = PrecacheModel(buffer);
	}
	if (GameConfGetKeyValue(gameConfig, "SpriteHalo", buffer, sizeof(buffer)) && buffer[0])
	{
		g_HaloSprite = PrecacheModel(buffer);
	}
}

public void CreateBeacon(int client)
{
	g_BeaconSerial[client] = ++g_Serial_Gen;
	CreateTimer(1.0, Timer_Beacon, client | (g_Serial_Gen << 7), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void KillBeacon(int client)
{
	g_BeaconSerial[client] = 0;

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
	if (g_BeaconSerial[client] == 0)
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

	if (!IsClientInGame(client) || !IsPlayerAlive(client) || g_BeaconSerial[client] != serial)
	{
		KillBeacon(client);
		return Plugin_Stop;
	}

	float vec[3];
	GetClientAbsOrigin(client, vec);
	vec[2] += 10;

	TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 0.0, greyColor, 10, 0);
	TE_SendToAll();

	int rainbowColor[4];
	float i = GetGameTime();
	float Frequency = 2.5;
	rainbowColor[0] = RoundFloat(Sine(Frequency * i + 0.0) * 127.0 + 128.0);
	rainbowColor[1] = RoundFloat(Sine(Frequency * i + 2.0943951) * 127.0 + 128.0);
	rainbowColor[2] = RoundFloat(Sine(Frequency * i + 4.1887902) * 127.0 + 128.0);
	rainbowColor[3] = 255;

	TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, rainbowColor, 10, 0);

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
	if (spriteEntities[client] != -1 && IsValidEdict(spriteEntities[client]))
	{
		char m_szClassname[64];
		GetEdictClassname(spriteEntities[client], m_szClassname, sizeof(m_szClassname));
		if(strcmp("env_sprite", m_szClassname)==0)
		AcceptEntityInput(spriteEntities[client], "Kill");
	}
	spriteEntities[client] = -1;
}

public void RemoveAllMarker()
{
	if (MarkerCount >= 1)
	{
		for (int m = 1; m < MarkerCount+1; m++)
		{
			if (MarkerEntities[m] != -1 && IsValidEdict(MarkerEntities[m]))
			{
				char m_szClassname[64];
				GetEdictClassname(MarkerEntities[m], m_szClassname, sizeof(m_szClassname));
				if(strcmp("env_sprite", m_szClassname)==0)
				AcceptEntityInput(MarkerEntities[m], "Kill");
			}
			MarkerEntities[m] = -1;
		}
	}
	MarkerCount = 0;
	g_iRemoveMarker = 0;
}

public void RemoveMarker(int Marker)
{
	if (MarkerEntities[Marker] != -1 && IsValidEdict(MarkerEntities[Marker]))
	{
		char m_szClassname[64];
		GetEdictClassname(MarkerEntities[Marker], m_szClassname, sizeof(m_szClassname));
		if(strcmp("env_sprite", m_szClassname)==0)
		AcceptEntityInput(MarkerEntities[Marker], "Kill");
	}
	MarkerEntities[Marker] = -1;
}

public void SetLeader(int client)
{
	if(IsValidClient(leaderClient))
	{
		RemoveLeader(leaderClient);
		CPrintToChatAll("%t", "Leader has been removed!");
	}

	if(IsValidClient(client))
	{
		leaderClient = client;

		CS_GetClientClanTag(client, leaderTag, sizeof(leaderTag));
		//CS_SetClientClanTag(client, "[Leader]");

		leaderMVP = CS_GetMVPCount(client);
		CS_SetMVPCount(client, 99);

		leaderScore = CS_GetClientContributionScore(client);
		CS_SetClientContributionScore(client, 9999);

		currentSprite = -1;
	}

	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		votedFor[i] = -1;
		votedremovedFor[i] = -1;
		voteCount[i] = 0;
		voteRemoveCount[i] = 0;
	}
}

public void RemoveLeader(int client)
{
	//CS_SetClientClanTag(client, leaderTag);
	CS_SetMVPCount(client, leaderMVP);
	CS_SetClientContributionScore(client, leaderScore);

	RemoveSprite(client);
	RemoveAllMarker();

	if(beaconActive)
	{
		KillBeacon(client);
	}

	currentSprite = -1;
	leaderClient = -1;
	markerActive = false;
	beaconActive = false;
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
	if(IsValidClient(leaderClient))
	{
		CPrintToChat(client, "%t", "The current leader", leaderClient);
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
	if(IsValidClient(leaderClient))
	{
		CPrintToChatAll("%t", "Leader has been removed!");
		RemoveLeader(leaderClient);

		for (int i = 1; i <= MAXPLAYERS; i++)
		{
			votedFor[i] = -1;
			votedremovedFor[i] = -1;
			voteCount[i] = 0;
			voteRemoveCount[i] = 0;
		}
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(client, "%t", "No current leader");
		return Plugin_Handled;
	}
}

public Action Leader(int client, int args)
{
	if(ZR_IsClientZombie(client))
	{
		CReplyToCommand(client, "%t", "You are not a human");
		return Plugin_Handled;
	}

	if(CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, false))
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

			if(target == leaderClient)
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
		else if(args == 0 && adminleader)
		{
			if(client == leaderClient)
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
		else if(client == leaderClient)
		{
			LeaderMenu(client);
			return Plugin_Handled;
		}
		else
		{
			CReplyToCommand(client, "%t", "Usage sm_leader");
		}
	}
	if(client == leaderClient)
	{
		LeaderMenu(client);
	}
	return Plugin_Handled;
}

public void LeaderMenu(int client)
{
	Handle menu = CreateMenu(LeaderMenu_Handler);
	SetGlobalTransTarget(client);
	
	char m_title[100];
	char m_resign[64];
	char m_sprite[64];
	char m_marker[64];
	char m_beacon[64];
	char t_sprite[64];
	char t_marker[64];
	char t_beacon[64];

	switch (currentSprite)
	{
		case 0:
		Format(t_sprite, sizeof(t_sprite), "%t", "Defend");
		case 1:
		Format(t_sprite, sizeof(t_sprite), "%t", "Follow");
		default:
		Format(t_sprite, sizeof(t_sprite), "%t", "None");
	}

	if(markerActive)
	Format(t_marker, sizeof(t_marker), "%i", MarkerCount);
	if(!markerActive)
	Format(t_marker, sizeof(t_marker), "%t", "No");
	
	if(beaconActive)
	Format(t_beacon, sizeof(t_beacon), "%t", "Yes");
	else
	Format(t_beacon, sizeof(t_beacon), "%t", "No");

	Format(m_title, sizeof(m_title), "%t", "Leader Menu Title", t_sprite, t_marker, t_beacon);
	Format(m_resign, sizeof(m_resign), "%t", "Resign from Leader");
	Format(m_sprite, sizeof(m_sprite), "%t", "Sprite Menu");
	Format(m_marker, sizeof(m_marker), "%t", "Marker Menu");
	Format(m_beacon, sizeof(m_beacon), "%t", "Toggle Beacon");

	SetMenuTitle(menu, m_title);
	AddMenuItem(menu, "m_resign", m_resign);
	AddMenuItem(menu, "m_sprite", m_sprite);
	AddMenuItem(menu, "m_marker", m_marker);
	AddMenuItem(menu, "m_beacon", m_beacon);

	SetMenuExitButton(menu, true);

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int LeaderMenu_Handler(Handle menu, MenuAction action, int client, int position)
{
	if(leaderClient == client && IsValidClient(client))
	{
		if(action == MenuAction_Select)
		{
			char info[32];
			GetMenuItem(menu, position, info, sizeof(info));

			if(StrEqual(info, "m_resign"))
			{
				RemoveLeader(client);
				CPrintToChatAll("%t", "Resigned from being leader", client);
			}
			if(StrEqual(info, "m_sprite"))
			{
				SpriteMenu(client);
			}
			if(StrEqual(info, "m_marker"))
			{
				MarkerMenu(client);
			}
			if(StrEqual(info, "m_beacon"))
			{
				ToggleBeacon(client);
				LeaderMenu(client);
			}
		}
		else if(action == MenuAction_End)
		{
			CloseHandle(menu);
		}
	}

}

public void ToggleBeacon(int client)
{
	if(beaconActive)
	beaconActive = false;
	else
	beaconActive = true;

	PerformBeacon(client);
}

public void SpriteMenu(int client)
{
	Handle menu = CreateMenu(SpriteMenu_Handler);
	SetGlobalTransTarget(client);
	
	char m_title[100];
	char m_none[64];
	char m_defend[64];
	char m_follow[64];
	char m_BackButton[64];
	char t_sprite[64];
	char t_marker[64];
	char t_beacon[64];

	switch (currentSprite)
	{
		case 0:
		Format(t_sprite, sizeof(t_sprite), "%t", "Defend");
		case 1:
		Format(t_sprite, sizeof(t_sprite), "%t", "Follow");
		default:
		Format(t_sprite, sizeof(t_sprite), "%t", "None");
	}

	if(markerActive)
	Format(t_marker, sizeof(t_marker), "%i", MarkerCount);
	if(!markerActive)
	Format(t_marker, sizeof(t_marker), "%t", "No");
	
	if(beaconActive)
	Format(t_beacon, sizeof(t_beacon), "%t", "Yes");
	else
	Format(t_beacon, sizeof(t_beacon), "%t", "No");

	Format(m_title, sizeof(m_title), "%t", "Leader Menu Title Sprite", t_sprite, t_marker, t_beacon);
	Format(m_none, sizeof(m_none), "%t", "No Sprite");
	Format(m_defend, sizeof(m_defend), "%t", "Defend Here");
	Format(m_follow, sizeof(m_follow), "%t", "Follow Me");
	Format(m_BackButton, sizeof(m_BackButton), "%t", "Back");

	SetMenuTitle(menu, m_title);
	AddMenuItem(menu, "m_none", m_none);
	AddMenuItem(menu, "m_defend", m_defend);
	AddMenuItem(menu, "m_follow", m_follow);
	AddMenuItem(menu, " ", " ", ITEMDRAW_SPACER);
	AddMenuItem(menu, " ", " ", ITEMDRAW_NOTEXT);
	AddMenuItem(menu, "m_BackButton", m_BackButton);

	SetMenuExitButton(menu, true);

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int SpriteMenu_Handler(Handle menu, MenuAction action, int client, int position)
{
	if(leaderClient == client && IsValidClient(client))
	{
		if(action == MenuAction_Select)
		{
			char info[32];
			GetMenuItem(menu, position, info, sizeof(info));

			if(StrEqual(info, "m_none"))
			{
				RemoveSprite(client);
				CPrintToChat(client, "%t", "Sprite removed");
				currentSprite = -1;
				SpriteMenu(client);
			}
			if(StrEqual(info, "m_defend"))
			{
				RemoveSprite(client);
				spriteEntities[client] = AttachSprite(client, DefendVMT);
				CPrintToChat(client, "%t", "Sprite changed to Defend Here");
				currentSprite = 0;
				SpriteMenu(client);
			}
			if(StrEqual(info, "m_follow"))
			{
				RemoveSprite(client);
				spriteEntities[client] = AttachSprite(client, FollowVMT);
				CPrintToChat(client, "%t", "Sprite changed to Follow Me");
				currentSprite = 1;
				SpriteMenu(client);
			}
			if(StrEqual(info, "m_BackButton"))
			{
				LeaderMenu(client);
			}
		}
		else if(action == MenuAction_End)
		{
			CloseHandle(menu);
		}
	}
}

public void MarkerMenu(int client)
{
	Handle menu = CreateMenu(MarkerMenu_Handler);
	SetGlobalTransTarget(client);

	char m_title[100];
	char m_removemarker[64];
	char m_defendmarker[64];
	char m_BackButton[64];
	char t_sprite[64];
	char t_marker[64];
	char t_beacon[64];

	switch (currentSprite)
	{
		case 0:
		Format(t_sprite, sizeof(t_sprite), "%t", "Defend");
		case 1:
		Format(t_sprite, sizeof(t_sprite), "%t", "Follow");
		default:
		Format(t_sprite, sizeof(t_sprite), "%t", "None");
	}

	if(markerActive)
	Format(t_marker, sizeof(t_marker), "%i", MarkerCount);
	if(!markerActive)
	Format(t_marker, sizeof(t_marker), "%t", "No");
	
	if(beaconActive)
	Format(t_beacon, sizeof(t_beacon), "%t", "Yes");
	else
	Format(t_beacon, sizeof(t_beacon), "%t", "No");

	Format(m_title, sizeof(m_title), "%t", "Leader Menu Title Marker", t_sprite, t_marker, t_beacon);
	Format(m_defendmarker, sizeof(m_defendmarker), "%t", "Defend Marker");
	Format(m_removemarker, sizeof(m_removemarker), "%t", "Remove Marker");
	Format(m_BackButton, sizeof(m_BackButton), "%t", "Back");

	SetMenuTitle(menu, m_title);
	AddMenuItem(menu, "m_defendmarker", m_defendmarker);
	AddMenuItem(menu, "m_removemarker", m_removemarker);
	AddMenuItem(menu, " ", " ", ITEMDRAW_SPACER);
	AddMenuItem(menu, " ", " ", ITEMDRAW_NOTEXT);
	AddMenuItem(menu, " ", " ", ITEMDRAW_NOTEXT);
	AddMenuItem(menu, "m_BackButton", m_BackButton);

	SetMenuExitButton(menu, true);

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MarkerMenu_Handler(Handle menu, MenuAction action, int client, int position)
{
	if(leaderClient == client && IsValidClient(client))
	{
		if(action == MenuAction_Select)
		{
			char info[32];
			GetMenuItem(menu, position, info, sizeof(info));

			if(StrEqual(info, "m_defendmarker"))
			{
				if (MarkerCount >= g_iMaxMarker)
				{
					g_iRemoveMarker++;
					if (g_iRemoveMarker > g_iMaxMarker)
					{
						g_iRemoveMarker = 1;
					}
					RemoveMarker(g_iRemoveMarker);
					MarkerEntities[g_iRemoveMarker] = SpawnMarker(client, DefendVMT);
					CPrintToChat(client, "%t", "Defend Here marker placed" ,g_iRemoveMarker);
					MarkerMenu(client);
					
				}
				else
				{
					MarkerCount++;
					MarkerEntities[MarkerCount] = SpawnMarker(client, DefendVMT);
					CPrintToChat(client, "%t", "Defend Here marker placed" ,MarkerCount);
					markerActive = true;
					MarkerMenu(client);
				}
			}
			if(StrEqual(info, "m_removemarker"))
			{
				RemoveAllMarker();
				CPrintToChat(client, "%t", "Marker removed");
				markerActive = false;
				MarkerMenu(client);
			}
			if(StrEqual(info, "m_BackButton"))
			{
				LeaderMenu(client);
			}
		}
		else if(action == MenuAction_End)
		{
			CloseHandle(menu);
		}
	}
}
public void OnClientDisconnect(int client)
{
	if(client == leaderClient)
	{
		CPrintToChatAll("%t", "The leader has disconnected");
		RemoveLeader(client);
	}
	voteCount[client] = 0;
}

public Action Event_PlayerDeath(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(client == leaderClient)
	{
		CPrintToChatAll("%t", "The leader has died");
		RemoveLeader(client);
	}
}

public int ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	if(client == leaderClient)
	{
		CPrintToChatAll("%t", "The leader has been infected");
		RemoveLeader(client);
	}
}

public void OnMapEnd()
{
	if(IsValidClient(leaderClient))
	{
		RemoveLeader(leaderClient);
	}
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		votedFor[i] = -1;
		votedremovedFor[i] = -1;
		voteCount[i] = 0;
		voteRemoveCount[i] = 0;
	}
	leaderClient = -1;
	KillAllBeacons();
}

bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}

public Action Event_RoundEnd(Handle event, char[] name, bool dontBroadcast)
{
	if(IsValidClient(leaderClient) && RoundEndRemoveL)
	{
		RemoveLeader(leaderClient);
	}

	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		votedFor[i] = -1;
		votedremovedFor[i] = -1;
		voteCount[i] = 0;
		voteRemoveCount[i] = 0;
	}

	KillAllBeacons();
}

public Action HookPlayerChat(int client, char[] command, int args)
{
	if(IsValidClient(client) && leaderClient == client)
	{
		char LeaderText[256];
		GetCmdArgString(LeaderText, sizeof(LeaderText));
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
	return leaderClient;
}

public int Native_SetLeader(Handle plugin, int numParams)
{
	SetLeader(GetNativeCell(1));
}

public Action Command_VoteLeader(int client, int argc)
{
	if (!client) return Plugin_Handled;

	if(!allowVoting)
	{
		CReplyToCommand(client, "%t", "Voting for leader is disabled");
		return Plugin_Handled;
	}

	if(IsValidClient(leaderClient))
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
		Menu_VoteLeader(client);
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

	if(!allowRLVoting)
	{
		CReplyToCommand(client, "%t", "Voting to remove leader is disabled");
		return Plugin_Handled;
	}

	if(!IsValidClient(leaderClient))
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
		Menu_VoteRemoveLeader(client);
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

stock void Menu_VoteLeader(int client)
{
	Menu menu = CreateMenu(MenuHandler_VoteLeader);
	SetGlobalTransTarget(client);

	char m_title[100];
	char strClientID[12];
	char strClientName[64];
	int[] alphabetClients = new int[MaxClients+1];

	Format(m_title, sizeof(m_title), "%t\n ", "Leader Menu Vote Player");

	SetMenuTitle(menu, m_title);
	SetMenuExitButton(menu, true);

	for (int aClient = 1; aClient <= MaxClients; aClient++)
	{
		if (IsClientInGame(aClient) && !ZR_IsClientZombie(aClient) && IsValidClient(aClient))
		{
			alphabetClients[aClient] = aClient;
			GetClientName(alphabetClients[aClient], clientNames[alphabetClients[aClient]], sizeof(clientNames[]));
		}
	}

	SortCustom1D(alphabetClients, MaxClients, SortByPlayerName);

	for (int i = 0; i < MaxClients; i++)
	{
		if (alphabetClients[i]!=0) 
		{
			IntToString(GetClientUserId(alphabetClients[i]), strClientID, sizeof(strClientID));
			FormatEx(strClientName, sizeof(strClientName), "%N - %t", alphabetClients[i], "Players Menu", voteCount[i], GetClientCount(true)/10);
			AddMenuItem(menu, strClientID, strClientName);
		}
	}

	if (menu.ItemCount == 0) 
	{
		delete(menu);
	} else {
		menu.ExitBackButton = (menu.ItemCount > 7);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
}

public int MenuHandler_VoteLeader(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
		case MenuAction_Select:
		{
			char info[32], name[32];
			int userid, target;
		
			GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
			userid = StringToInt(info);

			if ((target = GetClientOfUserId(userid)) == 0)
			{
				PrintToChat(param1, "[SM] %s", "Player no longer available");
			}
			else
			{
				VoteLeader(param1, target);
			}
		}
	}
}

public Action VoteLeader(int client, int target)
{
	if(!allowVoting)
	{
		CReplyToCommand(client, "%t", "Voting for leader is disabled");
		return Plugin_Handled;
	}

	if(IsValidClient(leaderClient))
	{
		CReplyToCommand(client, "%t", "There is already a leader");
		return Plugin_Handled;
	}

	if(GetClientFromSerial(votedFor[client]) == target)
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

	if(GetClientFromSerial(votedFor[client]) != 0)
	{
		if(IsValidClient(GetClientFromSerial(votedFor[client]))) {
			voteCount[GetClientFromSerial(votedFor[client])]--;
		}
	}
	voteCount[target]++;
	votedFor[client] = GetClientSerial(target);
	CPrintToChatAll("%t", "Has voted for", client, target, voteCount[target], GetClientCount(true)/10);

	if(voteCount[target] >= GetClientCount(true)/10)
	{
		SetLeader(target);
		CPrintToChatAll("%t", "Has been voted to be the new leader", target);
		LeaderMenu(target);
	}

	return Plugin_Handled;
}

stock void Menu_VoteRemoveLeader(int client)
{
	Menu menu = CreateMenu(MenuHandler_VoteRemoveLeader);
	SetGlobalTransTarget(client);

	char m_title[100];
	char strClientID[12];
	char strClientName[64];

	Format(m_title, sizeof(m_title), "%t\n ", "Menu Vote Remove Leader");

	SetMenuTitle(menu, m_title);
	SetMenuExitButton(menu, true);

	if(IsValidClient(leaderClient))
	{
		IntToString(GetClientUserId(leaderClient), strClientID, sizeof(strClientID));
		FormatEx(strClientName, sizeof(strClientName), "%N - %t", leaderClient, "Players Menu", voteRemoveCount[leaderClient], GetClientCount(true)/10);
		AddMenuItem(menu, strClientID, strClientName);
	}

	if (menu.ItemCount == 0) 
	{
		delete(menu);
	} else {
		menu.ExitBackButton = (menu.ItemCount > 7);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
}

public int MenuHandler_VoteRemoveLeader(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
		case MenuAction_Select:
		{
			char info[32], name[32];
			int userid, target;
		
			GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
			userid = StringToInt(info);

			if ((target = GetClientOfUserId(userid)) == 0)
			{
				PrintToChat(param1, "[SM] %s", "Player no longer available");
			}
			else
			{
				VoteRemoveLeader(param1, target);
			}
		}
	}
}

public Action VoteRemoveLeader(int client, int target)
{
	if(!allowRLVoting)
	{
		CReplyToCommand(client, "%t", "Voting for leader is disabled");
		return Plugin_Handled;
	}

	if(!IsValidClient(leaderClient))
	{
		CReplyToCommand(client, "%t", "No current leader");
		return Plugin_Handled;
	}

	if(GetClientFromSerial(votedremovedFor[client]) == target)
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

	if(leaderClient != target)
	{
		CReplyToCommand(client, "%t", "This Player is not the current leader");
		return Plugin_Handled;
	}

	if(GetClientFromSerial(votedremovedFor[client]) != 0)
	{
		if(IsValidClient(GetClientFromSerial(votedremovedFor[client]))) {
			voteRemoveCount[GetClientFromSerial(votedremovedFor[client])]--;
		}
	}
	voteRemoveCount[target]++;
	votedremovedFor[client] = GetClientSerial(target);
	CPrintToChatAll("%t", "Has voted for Remove", client, target, voteRemoveCount[target], GetClientCount(true)/10);

	if(voteRemoveCount[target] >= GetClientCount(true)/10)
	{
		RemoveTheLeader(target, 0);
	}

	return Plugin_Handled;
}

stock int SortByPlayerName(int player1, int player2, const int[] array, Handle hndl)
{
	return strcmp(clientNames[player1], clientNames[player2], false);
}