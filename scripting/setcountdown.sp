#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <updater>

#undef REQUIRE_PLUGIN
#define PLUGIN_VERSION	"0.1.4"
#define ALARM_TRIGGER	"mvm/mvm_cpoint_klaxon.wav"
#define UPDATE_URL		"https://github.com/RueLee/-TF2-Set-Countdown-Timer/blob/master/updater.txt"

ConVar g_hcountdownEnabled;

Handle g_hTimerTick[MAXPLAYERS + 1];
Handle g_hUpdatePanel[MAXPLAYERS + 1];

int g_iSeconds;
int g_iMinutes;
int g_iHours;

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
	//g_hallowTarget = CreateConVar("sm_countdown_allowtarget", "1", "Enable/Disable client on declaring a countdown.", FCVAR_NOTIFY);
	
	LoadTranslations("common.phrases.txt");
	
	PrecacheSound(ALARM_TRIGGER, false);
	
	if (LibraryExists("updater")) {
        Updater_AddPlugin(UPDATE_URL);
    }
	
	
	for (int i = 0; i < MaxClients; i++) {
		delete g_hTimerTick[i];
		delete g_hUpdatePanel[i];
		g_bAllowTarget[i] = true;
	}
	
	RegAdminCmd("sm_setcountdown", CmdSetCountdown, ADMFLAG_CHANGEMAP, "Set a target to start a timer.");
	RegAdminCmd("sm_settimer", CmdSetCountdown, ADMFLAG_CHANGEMAP, "Set a target to start a timer.");
	RegAdminCmd("sm_stoptimer", CmdStopTimer, ADMFLAG_CHANGEMAP, "Stops the timer while a target is already declared.");
}

public OnMapEnd() {
	ClearFormat();
}

public void ClearFormat() {
	for (int i = 0; i < MaxClients; i++) {
		delete g_hTimerTick[i];
		delete g_hUpdatePanel[i];
		g_bAllowTarget[i] = true;
	}
}

public void OnLibraryAdded(const char[] sName) {
	if (StrEqual(sName, "updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

public OnClientDisconnect(int client) {
	delete g_hTimerTick[client];
	delete g_hUpdatePanel[client];
}

public Action CmdSetCountdown(int client, int args) {
	if (g_hcountdownEnabled.IntValue == 0) {
		ReplyToCommand(client, "[SM] Countdown Timer plugin is currently disabled!");
		return Plugin_Handled;
	}
	
	if (!g_bAllowTarget[client]) {
		ReplyToCommand(client, "[SM] You cannot call another player while the timer is running!");
		return Plugin_Handled;
	}
	
	if (args != 2) {
		ReplyToCommand(client, "[SM] Usage: sm_setcountdown <#userid|name> [seconds]");
		return Plugin_Handled;
	}
	
	char nameArg[32], secondsArg[8];
	GetCmdArg(1, nameArg, sizeof(nameArg));
	GetCmdArg(2, secondsArg, sizeof(secondsArg));
	
	int seconds = StringToInt(secondsArg);
	
	if (seconds < 1) {
		ReplyToCommand(client, "[SM] Please enter a value greater than 0.");
		return Plugin_Handled;
	}
	
	int iTarget = FindTarget(client, nameArg, false, false);
	
	if (iTarget == -1) {
		return Plugin_Handled;
	}
	
	if (!IsPlayerAlive(iTarget)) {
		ReplyToCommand(client, "[SM] Your target, %N, must be alive!", iTarget);
		return Plugin_Handled;
	}
	
	if (g_hTimerTick[iTarget] != null) {
		ReplyToCommand(client, "[SM] Countdown is already triggered to this player.");
		return Plugin_Handled;
	}
	
	g_iSeconds = seconds % 60;
	g_iHours = seconds / 60;
	g_iMinutes = g_iHours % 60;
	g_iHours /= 60;
	
	g_hTimerTick[iTarget] = CreateTimer(1.0, Timer_Count, GetClientUserId(iTarget), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	g_hUpdatePanel[iTarget] = CreateTimer(0.5, Timer_PanelCount, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	g_bAllowTarget[client] = false;
	
	CPrintToChat(client, "{orange}[SM] {default}Set countdown on {aqua}%N{default}.", iTarget);
	CPrintToChat(iTarget, "{orange}[SM] {aqua}%N {default}has declared a countdown timer for {gold}%d:%02d:%02d{default}!", client, g_iHours, g_iMinutes, g_iSeconds);
	return Plugin_Handled;
}

public Action Timer_PanelCount(Handle hTimer, any cID) {
	char buffer[100];
	char timeExpiration[100];
	
	int client = GetClientOfUserId(cID);
	
	//char targetname[MAX_NAME_LENGTH];
	//FormatEx(targetname, sizeof(targetname), "Name: %N", iTarget);
	FormatEx(buffer, sizeof(buffer), "Timeleft: %d:%02d:%02d", g_iHours, g_iMinutes, g_iSeconds);
	FormatEx(timeExpiration, sizeof(timeExpiration), "Time Expired: No");
	
	if (g_iHours == 0 && g_iMinutes == 0 && g_iSeconds == 0) {
		CloseHandle(g_hUpdatePanel[client]);
		g_hUpdatePanel[client] = null;
		g_bAllowTarget[client] = true;
		FormatEx(timeExpiration, sizeof(timeExpiration), "Time Expired: Yes");
	}
	
	Panel hpanel = new Panel();
	
	hpanel.SetTitle("===[Countdown Timer]===");
	hpanel.DrawText(" ");
	hpanel.DrawText("Admin View:");
	hpanel.DrawText(" ");
	hpanel.DrawText(buffer);
	hpanel.DrawText(timeExpiration);
	hpanel.DrawText(" ");
	hpanel.DrawItem("Exit", ITEMDRAW_CONTROL);
	hpanel.Send(client, RunTimer, 0);
	CloseHandle(hpanel);
	
	
	
	return Plugin_Continue;
}

public Action CmdStopTimer(int client, int args) {
	char arg[32];
	GetCmdArg(1, arg, sizeof(arg));
	
	int iTarget = FindTarget(client, arg, false, false);
	
	if (iTarget == -1) {
		return Plugin_Handled;
	}
	
	if (g_hTimerTick[iTarget] != null) {
		CloseHandle(g_hTimerTick[iTarget]);
		g_hTimerTick[iTarget] = null;
		CloseHandle(g_hUpdatePanel[client]);
		g_hUpdatePanel[client] = null;
		g_bAllowTarget[client] = true;
		PrintToChat(client, "[SM] Terminated countdown operation!");
		PrintToChat(iTarget, "[SM] %N has stopped the countdown!", client);
	}
	else {
		PrintToChat(client, "[SM] The countdown timer is not running!");
	}
	return Plugin_Handled;
}

public int RunTimer(Menu menu, MenuAction action, int client, int choice) {
	//g_hTimerTick = CreateTimer(-1.0, Timer_Count, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Count(Handle hTimer, any cID) {
	int client = GetClientOfUserId(cID);

	g_iSeconds--;
	if (g_iSeconds == -1) {
		if (g_iMinutes > -1) {
			g_iMinutes--;
			g_iSeconds = 59;
		}
		if (g_iMinutes == -1) {
			if (g_iHours > -1) {
				g_iHours--;
				g_iMinutes = 59;
			}
		}
	}
	if (g_iHours == 0 && g_iMinutes == 0 && g_iSeconds == 0) {
		CloseHandle(g_hTimerTick[client]);
		g_hTimerTick[client] = null;
		CPrintToChat(client, "{green}[SM] {fullred}Time is up!");
		EmitSoundToClient(client, ALARM_TRIGGER, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.4);
	}
	return Plugin_Continue;
}
