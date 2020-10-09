#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <updater>

#undef REQUIRE_PLUGIN
#define PLUGIN_VERSION	"0.1.8"
#define ALARM_TRIGGER	"mvm/mvm_cpoint_klaxon.wav"
#define UPDATE_URL		"https://github.com/RueLee/-TF2-Set-Countdown-Timer/blob/master/updater.txt"

ConVar g_hcountdownEnabled;
ConVar g_hcountdownAdminLog;

Handle g_hTimerTick[MAXPLAYERS + 1];
Handle g_hTargetTime[MAXPLAYERS + 1];

int g_iGetTarget[MAXPLAYERS + 1];
int g_iTotalSeconds[MAXPLAYERS + 1];
int g_iGetTargetTime[MAXPLAYERS + 1];

bool g_bAllowTarget[MAXPLAYERS + 1];

public Plugin:myinfo = {
	name = "[TF2] Set Countdown Timer",
	author = "RueLee",
	description = "Allows player to set a countdown timer.",
	version = PLUGIN_VERSION,
	url = "https://github.com/RueLee/-TF2-Set-Countdown-Timer"
}

public OnPluginStart() {
	CreateConVar("sm_setcountdown_version", PLUGIN_VERSION, "Plugin Version -- DO NOT MODIFY!", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	g_hcountdownEnabled = CreateConVar("sm_countdown_enabled", "1", "Enable/Disable plugin.", FCVAR_NOTIFY);
	g_hcountdownAdminLog = CreateConVar("sm_countdown_adminlog", "1", "Enable/Disable client on printing messages to all admins in the server.", FCVAR_NOTIFY);
	
	LoadTranslations("common.phrases.txt");
	
	PrecacheSound(ALARM_TRIGGER, false);
	
	if (LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
	
	ClearFormat();
	
	RegAdminCmd("sm_setcountdown", CmdSetCountdown, ADMFLAG_CHANGEMAP, "Calls a target to start a timer.");
	RegAdminCmd("sm_settimer", CmdSetCountdown, ADMFLAG_CHANGEMAP, "Calls a target to start a timer.");
	RegAdminCmd("sm_stoptimer", CmdStopTimer, ADMFLAG_CHANGEMAP, "Stops the timer while a target is already declared.");
	
	RegConsoleCmd("sm_timeleftcountdown", CmdTimeLeft, "Shows how much time left for that player.");
}

public OnMapEnd() {
	ClearFormat();
}

public void ClearFormat() {
	for (int i = 1; i <= MaxClients; i++) {
		delete g_hTimerTick[i];
		delete g_hTargetTime[i];
		g_bAllowTarget[i] = true;
		g_iTotalSeconds[i] = 0;
		g_iGetTargetTime[i] = 0;
	}
}

public void OnLibraryAdded(const char[] sName) {
	if (StrEqual(sName, "updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

public OnClientDisconnect(int client) {
	delete g_hTimerTick[client];
	delete g_hTargetTime[client];
}

public Action CmdSetCountdown(int client, int args) {
	if (g_hcountdownEnabled.IntValue == 0) {
		CReplyToCommand(client, "{orange}[SM] {default}Countdown Timer plugin is currently disabled!");
		return Plugin_Handled;
	}
	
	if (!g_bAllowTarget[client]) {
		CReplyToCommand(client, "{orange}[SM] {default}You cannot call another player while the timer is running!");
		return Plugin_Handled;
	}
	
	if (args != 2) {
		CReplyToCommand(client, "{orange}[SM] {default}Usage: sm_setcountdown <#userid|name> [seconds]");
		return Plugin_Handled;
	}
	
	char nameArg[32], secondsArg[8];
	GetCmdArg(1, nameArg, sizeof(nameArg));
	GetCmdArg(2, secondsArg, sizeof(secondsArg));
	
	g_iTotalSeconds[client] = StringToInt(secondsArg);
	
	if (g_iTotalSeconds[client] < 1) {
		CReplyToCommand(client, "{orange}[SM] {default}Please enter a value greater than 0.");
		return Plugin_Handled;
	}
	
	int iTarget = FindTarget(client, nameArg, false, false);
	
	if (iTarget == -1) {
		return Plugin_Handled;
	}
	
	if (!IsPlayerAlive(iTarget)) {
		CReplyToCommand(client, "{orange}[SM] {default}Your target, {aquamarine}%N{default}, must be alive!", iTarget);
		return Plugin_Handled;
	}
	
	if (g_hTimerTick[iTarget] != null) {
		CReplyToCommand(client, "{orange}[SM] {default}Countdown is already triggered to this player.");
		return Plugin_Handled;
	}
	
	g_iGetTarget[client] = iTarget;
	
	int sec, min, hr;
	
	sec = g_iTotalSeconds[client] % 60;
	hr = g_iTotalSeconds[client] / 60;
	min = hr % 60;
	hr /= 60;
	
	g_iGetTargetTime[iTarget] = g_iTotalSeconds[client];
	
	g_hTimerTick[iTarget] = CreateTimer(1.0, Timer_Count, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	g_hTargetTime[iTarget] = CreateTimer(1.0, Timer_Target, GetClientUserId(iTarget), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	g_bAllowTarget[client] = false;
	
	CPrintToChat(client, "{orange}[SM] {default}Set countdown on {aquamarine}%N{default}.", iTarget);
	CPrintToChat(iTarget, "{orange}[SM] {aquamarine}%N {default}has declared a countdown timer for {gold}%d:%02d:%02d{default}!", client, hr, min, sec);
	
	if (g_hcountdownAdminLog.IntValue >= 1) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				AdminId admin = GetUserAdmin(i);
				if (admin != INVALID_ADMIN_ID) {
					CPrintToChat(i, "{orange}[SM] {aquamarine}%N {default}has declared a countdown timer on {aquamarine}%N {default}for {gold}%d:%02d:%02d{default}!", client, iTarget, hr, min, sec);
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action CmdStopTimer(int client, int args) {
	if (g_hcountdownEnabled.IntValue == 0) {
		CReplyToCommand(client, "{orange}[SM] {default}Countdown Timer plugin is currently disabled!");
		return Plugin_Handled;
	}
	
	char arg[32];
	GetCmdArg(1, arg, sizeof(arg));
	
	int iTarget = FindTarget(client, arg, false, false);
	
	if (iTarget == -1) {
		return Plugin_Handled;
	}
	
	if (g_hTimerTick[iTarget] != null) {
		CloseHandle(g_hTimerTick[iTarget]);
		g_hTimerTick[iTarget] = null;
		CloseHandle(g_hTargetTime[iTarget]);
		g_hTargetTime[iTarget] = null;
		g_bAllowTarget[client] = true;
		CPrintToChat(client, "{orange}[SM] {default}Terminated countdown operation!");
		CPrintToChat(iTarget, "{orange}[SM] {aquamarine}%N {default}has stopped the countdown!", client);
		
		if (g_hcountdownAdminLog.IntValue >= 1) {
			for (int i = 1; i <= MaxClients; i++) {
				if (IsClientInGame(i)) {
					AdminId admin = GetUserAdmin(i);
					if (admin != INVALID_ADMIN_ID) {
						CPrintToChat(i, "{orange}[SM] {aquamarine}%N {default}has stopped the countdown on {aquamarine}%N{default}!", client, iTarget);
					}
				}
			}
		}
	}
	else {
		CPrintToChat(client, "{orange}[SM] {default}The countdown timer is not running on this player!");
	}
	return Plugin_Handled;
}

public Action CmdTimeLeft(int client, int args) {
	if (g_hcountdownEnabled.IntValue == 0) {
		CReplyToCommand(client, "{orange}[SM] {default}Countdown Timer plugin is currently disabled!");
		return Plugin_Handled;
	}
	
	int sec, min, hr;
	
	sec = g_iGetTargetTime[client] % 60;
	hr = g_iGetTargetTime[client] / 60;
	min = hr % 60;
	hr /= 60;
	
	if (g_hTimerTick[client] != null) {
		CPrintToChat(client, "{orange}[SM] {default}You have {gold}%d:%02d:%02d{default} left!", hr, min, sec);
	}
	else {
		CPrintToChat(client, "{orange}[SM] {default}Your countdown timer is not running by someone.");
	}
	return Plugin_Handled;
}

public Action Timer_Count(Handle hTimer, any cID) {
	int client = GetClientOfUserId(cID);
	
	int sec, min, hr;
	
	sec = g_iTotalSeconds[client] % 60;
	hr = g_iTotalSeconds[client] / 60;
	min = hr % 60;
	hr /= 60;
	
	g_iTotalSeconds[client]--;
	
	char buffer[100], timeExpiration[100], targetname[MAX_NAME_LENGTH];
	
	FormatEx(targetname, sizeof(targetname), "Name: %N", g_iGetTarget[client]);
	FormatEx(buffer, sizeof(buffer), "Timeleft: %d:%02d:%02d", hr, min, sec);
	FormatEx(timeExpiration, sizeof(timeExpiration), "Time Expired: No");
	
	Panel hpanel = new Panel();
	
	hpanel.SetTitle("===[Countdown Timer]===");
	hpanel.DrawText(" ");
	hpanel.DrawText("Admin View:");
	hpanel.DrawText(" ");
	hpanel.DrawText(targetname);
	hpanel.DrawText(buffer);
	hpanel.DrawText(timeExpiration);
	hpanel.DrawText(" ");
	hpanel.DrawItem("Exit", ITEMDRAW_CONTROL);
	hpanel.Send(client, RunTimer, 0);
	CloseHandle(hpanel);
	
	if (hr == 0 && min == 0 && sec == 0) {
		FormatEx(timeExpiration, sizeof(timeExpiration), "Time Expired: Yes");
		g_bAllowTarget[client] = true;
		CPrintToChat(client, "{orange}[SM] {fullred}Time is up!");
		EmitSoundToClient(client, ALARM_TRIGGER, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.4);
	}
	return Plugin_Continue;
}

public Action Timer_Target(Handle hTimer, any cID) {
	int client = GetClientOfUserId(cID);
	int sec, min, hr;
	
	sec = g_iGetTargetTime[client] % 60;
	hr = g_iGetTargetTime[client] / 60;
	min = hr % 60;
	hr /= 60;
	
	g_iGetTargetTime[client]--;
	
	if (hr == 0 && min == 0 && sec == 0) {
		CloseHandle(g_hTimerTick[client]);
		g_hTimerTick[client] = null;
		CloseHandle(g_hTargetTime[client]);
		g_hTargetTime[client] = null;
		CPrintToChat(client, "{orange}[SM] {fullred}Time is up!");
		EmitSoundToClient(client, ALARM_TRIGGER, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.4);
	}
	
	return Plugin_Continue;
}

public int RunTimer(Menu menu, MenuAction action, int client, int choice) {
	//Nothing here will be run.
}