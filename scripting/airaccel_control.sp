#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_NAME "Air Accel Control"
#define PLUGIN_AUTHOR "JoinedSenses (Credit to KiD Fearless and Shavit)"
#define PLUGIN_DESCRIPTION "Allows players to choose their own air acceleration value"
#define PLUGIN_VERSION "0.1.0"
#define PLUGIN_URL "https://alliedmods.net"

/**
 * Hooks players and replicates sv_airaccelerate to a client
 */

ConVar g_cvarAirAccelerate; // sv_airaccelerate
int g_defaultFlags; // Default cvar flags

bool g_enabled[MAXPLAYERS + 1]; // Client enablements
int g_value[MAXPLAYERS + 1]; // Client accel values
int g_default; // The default accel value

bool g_simulating; // Indicates the plugin is modifying the convar, not an outside source.

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

public void OnPluginStart()
{
	CreateConVar(
		"sm_airaccelcontrol_version",
		PLUGIN_VERSION,
		PLUGIN_DESCRIPTION,
		FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD
	).SetString(PLUGIN_VERSION);

	g_cvarAirAccelerate = FindConVar("sv_airaccelerate");
	g_default = g_cvarAirAccelerate.IntValue;
	g_cvarAirAccelerate.AddChangeHook(cvarChanged_Accel);

	g_defaultFlags = g_cvarAirAccelerate.Flags;
	g_cvarAirAccelerate.Flags &= ~(FCVAR_NOTIFY|FCVAR_REPLICATED);

	for (int i = 1; i <= MaxClients; ++i)
	{ // initialize to default value
		g_value[i] = g_default;
	}

// 	RegAdminCmd("sm_accel", cmdAcceleration, ADMFLAG_GENERIC);
	RegConsoleCmd("sm_accel", cmdAcceleration);
}

public void cvarChanged_Accel(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_simulating)
	{ // Do nothing if this plugin is modifying value for a client
		return;
	}

	g_default = StringToInt(newValue);

	for (int i = 1; i <= MaxClients; ++i)
	{ // check / update client values
		if (!g_enabled[i])
		{ // if not enabled, then just update default
			g_value[i] = g_default;
		}
		else if (g_value[i] == g_default)
		{ // otherwise, if enabled and if new value matches default, then unhook the player
			g_enabled[i] = false;

			SDKUnhook(i, SDKHook_PreThink, sdkhookPreThink);
			SDKUnhook(i, SDKHook_PostThink, sdkhookPostThink);

			g_cvarAirAccelerate.ReplicateToClient(i, newValue);
		}
	}
}

public Action cmdAcceleration(int client, int args)
{
	if (!client)
	{ // go away, rcon
		return Plugin_Handled;
	}

	if (!args)
	{ // if no args
		if (g_enabled[client])
		{ // if enabled, disable and unhook
			g_enabled[client] = false;

			SDKUnhook(client, SDKHook_PreThink, sdkhookPreThink);
			SDKUnhook(client, SDKHook_PostThink, sdkhookPostThink);

			g_value[client] = g_default;

			char defaultVal[16];
			IntToString(g_default, defaultVal, sizeof defaultVal);
			g_cvarAirAccelerate.ReplicateToClient(client, defaultVal);

			ReplyToCommand(client, "Custom acceleration disabled and set to %i", g_default);
		}
		else
		{ // otherwise, give them the usage
			ReplyToCommand(client, "Usage: sm_accel <value>");
		}

		return Plugin_Handled;
	}

	char arg[16];
	GetCmdArg(1, arg, sizeof arg);

	int value = StringToInt(arg);
	if (value < 1)
	{
		ReplyToCommand(client, "Invalid value (%i). Must be a positive integer.", value);
		return Plugin_Handled;
	}

	if (value == g_default)
	{ // if their arg is default value
		g_value[client] = value;

		if (g_enabled[client])
		{ // if enabled, disable and unhook
			g_enabled[client] = false;

			SDKUnhook(client, SDKHook_PreThink, sdkhookPreThink);
			SDKUnhook(client, SDKHook_PostThink, sdkhookPostThink);

			g_cvarAirAccelerate.ReplicateToClient(client, arg);

			ReplyToCommand(client, "Acceleration set to %i (Matches server value)", value);
		}
		else
		{
			ReplyToCommand(client, "Value unchanged from server value.");
		}
	}
	else 
	{ // if value doesnt match default value
		if (value == g_value[client])
		{ // check if changed
			ReplyToCommand(client, "Value unchanged.");
			return Plugin_Handled;
		}

		g_value[client] = value;

		if (!g_enabled[client])
		{ // if not enabled, enable and hook.
			g_enabled[client] = true;

			SDKHook(client, SDKHook_PreThink, sdkhookPreThink);
			SDKHook(client, SDKHook_PostThink, sdkhookPostThink);
		}

		g_cvarAirAccelerate.ReplicateToClient(client, arg);

		ReplyToCommand(client, "Acceleration set to %i", value);
	}

	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	if (g_enabled[client])
	{
		g_enabled[client] = false;
		g_value[client] = g_default;

		// I dont think these are needed, but whatever.
		SDKUnhook(client, SDKHook_PreThink, sdkhookPreThink);
		SDKUnhook(client, SDKHook_PostThink, sdkhookPostThink);
	}
}

public void sdkhookPreThink(int client)
{
	if (IsClientInGame(client))
	{
		g_simulating = true;
		g_cvarAirAccelerate.IntValue = g_value[client];
		g_simulating = false;
	}
}

public void sdkhookPostThink(int client)
{
	g_simulating = true;
	g_cvarAirAccelerate.IntValue = g_default;
	g_simulating = false;
}

public void OnPluginEnd()
{
	g_cvarAirAccelerate.Flags = g_defaultFlags;

	char defaultVal[16];
	IntToString(g_default, defaultVal, sizeof defaultVal);

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (g_enabled[i] && IsClientInGame(i))
		{
			g_cvarAirAccelerate.ReplicateToClient(i, defaultVal);

			PrintToChat(i, "Accel plugin ending. Setting values to default");
		}
	}
}