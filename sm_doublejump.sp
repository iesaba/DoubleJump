/*
 * Double Jump
 *
 * Description:
 *  Allows players to double-jump
 *  Original idea: NcB_Sav
 *
 * Convars:
 *  sm_doublejump_enabled [bool] : Enables or disable double-jumping. Default: 1
 *  sm_doublejump_boost [amount] : Amount to boost the player. Default: 250
 *  sm_doublejump_max [jumps]    : Maximum number of re-jumps while airborne. Default: 1
 *
 * Changelog:
 *  v1.0.2
 *   クライアント毎に使用可能 by k725.
 *  v1.0.1
 *   Minor code optimization.
 *  v1.0.0
 *   Initial release.
 *
 * Known issues:
 *  Doesn't register all mouse-wheel triggered +jumps
 *
 * Todo:
 *  Employ upcoming OnClientCommand function to remove excess OnGameFrame-age.
 *
 * Contact:
 *  Paegus: paegus@gmail.com
 *  SourceMod: http://www.sourcemod.net
 *  Hidden:Source: http://www.hidden-source.com
 *  NcB_Sav: http://forums.alliedmods.net/showthread.php?t=99228
 */
#pragma semicolon 1
#define PLUGIN_VERSION "1.0.2"

#include <sdktools>
#include <cstrike>


public Plugin:myinfo = {
	name		= "Double Jump",
	author		= "Paegus (& k725)",
	description	= "Allows double-jumping.",
	version		= PLUGIN_VERSION,
	url			= ""
};

new Handle:g_cvJumpBoost  = INVALID_HANDLE,
	Handle:g_cvJumpEnable = INVALID_HANDLE,
	Handle:g_cvJumpMax    = INVALID_HANDLE,
	Float:g_flBoost       = 250.0,
	bool:g_bDoubleJump    = true,
	g_fLastButtons[MAXPLAYERS+1],
	g_fLastFlags[MAXPLAYERS+1],
	g_iJumps[MAXPLAYERS+1],
	g_iJumpMax,
	g_iAllowPlayer[MAXPLAYERS+1];

public OnPluginStart() {
	CreateConVar("sm_doublejump_version", PLUGIN_VERSION, "Double Jump Version", FCVAR_PLUGIN|FCVAR_NOTIFY);

	g_cvJumpEnable = CreateConVar("sm_doublejump_enabled", "1", "Enables double-jumping.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_cvJumpBoost  = CreateConVar("sm_doublejump_boost", "250.0", "The amount of vertical boost to apply to double jumps.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_cvJumpMax    = CreateConVar("sm_doublejump_max", "1", "The maximum number of re-jumps allowed while already jumping.", FCVAR_PLUGIN|FCVAR_NOTIFY);

	HookConVarChange(g_cvJumpBoost, convar_ChangeBoost);
	HookConVarChange(g_cvJumpEnable, convar_ChangeEnable);
	HookConVarChange(g_cvJumpMax, convar_ChangeMax);

	g_bDoubleJump = GetConVarBool(g_cvJumpEnable);
	g_flBoost     = GetConVarFloat(g_cvJumpBoost);
	g_iJumpMax    = GetConVarInt(g_cvJumpMax);

	AddCommandListener(Command_Say, "say");
	HookEvent("round_end", Event_RoundEnd);
}

public convar_ChangeBoost(Handle:convar, const String:oldVal[], const String:newVal[]) {
	g_flBoost = StringToFloat(newVal);
}

public convar_ChangeEnable(Handle:convar, const String:oldVal[], const String:newVal[]) {
	if (StringToInt(newVal) >= 1)
	{
		g_bDoubleJump = true;
	}
	else
	{
		g_bDoubleJump = false;
	}
}

public convar_ChangeMax(Handle:convar, const String:oldVal[], const String:newVal[]) {
	g_iJumpMax = StringToInt(newVal);
}

public Action:Command_Say(client, const String:command[], argc)
{
	if (g_bDoubleJump)
	{
		decl String:speech[64];
		new  startidx = 0;
		decl clientHealth;

		if (GetCmdArgString(speech, sizeof(speech)) < 1)
		{
			return Plugin_Continue;
		}

		if (speech[strlen(speech) - 1] == '"')
		{
			speech[strlen(speech) - 1] = '\0';
			startidx = 1;
		}

		if (strcmp(speech[startidx], "/double", false) == 0)
		{
			if (IsValidClient(client))
			{
				if (IsPlayerAlive(client))
				{
					if (GetClientTeam(client) == CS_TEAM_CT)
					{
						if (g_iAllowPlayer[client] != client)
						{
							clientHealth = GetClientHealth(client);

							if (clientHealth <= 50)
							{
								PrintCenterText(client, "Health is too small.\n体力が少なすぎます。");
								return Plugin_Handled;
							}
							else
							{
								g_iAllowPlayer[client] = client;
								SlapPlayer(client, clientHealth - 1, false);
								return Plugin_Handled;
							}
						}
						else
						{
							PrintCenterText(client, "It is already enabled.\n既に有効になっています。");
							return Plugin_Handled;
						}
					}
					else
					{
						PrintCenterText(client, "It is only allow in CT.\nCTのみ許可されています。");
						return Plugin_Handled;
					}
				}
				else
				{
					PrintCenterText(client, "It is only living player.\n生きているプレイヤーのみ許可されています。");
					return Plugin_Handled;
				}
			}
		}
	}

	return Plugin_Continue;
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bDoubleJump)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			g_iAllowPlayer[i] = 0;
		}
	}
}

public OnGameFrame() {
	if (g_bDoubleJump)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsPlayerAlive(i) && g_iAllowPlayer[i] == i)
			{
				DoubleJump(i);
			}
		}
	}
}

stock DoubleJump(const any:client) {
	new fCurFlags   = GetEntityFlags(client),
		fCurButtons = GetClientButtons(client);

	if (g_fLastFlags[client] & FL_ONGROUND)
	{
		if (!(fCurFlags & FL_ONGROUND) && !(g_fLastButtons[client] & IN_JUMP) && fCurButtons & IN_JUMP)
		{
			OriginalJump(client);
		}
	}
	else if (fCurFlags & FL_ONGROUND)
	{
		Landed(client);
	}
	else if (!(g_fLastButtons[client] & IN_JUMP) && fCurButtons & IN_JUMP)
	{
		ReJump(client);
	}

	g_fLastFlags[client]   = fCurFlags;
	g_fLastButtons[client] = fCurButtons;
}

stock OriginalJump(const any:client) {
	g_iJumps[client]++;
}

stock Landed(const any:client) {
	g_iJumps[client] = 0;
}

stock ReJump(const any:client) {
	if (1 <= g_iJumps[client] <= g_iJumpMax)
	{
		g_iJumps[client]++;
		decl Float:vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);

		vVel[2] = g_flBoost;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	}
}

stock bool:IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	if (IsFakeClient(client)) return false;
	return true;
}
