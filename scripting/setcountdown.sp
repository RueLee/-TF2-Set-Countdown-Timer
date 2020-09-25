#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <updater>

#undef REQUIRE_PLUGIN
#define PLUGIN_VERSION	"0.1.2"
#define ALARM_TRIGGER	"mvm/mvm_cpoint_klaxon.wav"
#define UPDATE_URL		"https://github.com/RueLee/-TF2-Set-Countdown-Timer/blob/master/updater.txt"

ConVar g_hcountdownEnabled;

Handle g_hTimerTick = null;
Handle g_hUpdatePanel = null;

int g_iSeconds;
int g_iMinutes;
int g_iHours;
int g_iTarget;

bool g_ballowCountdown;

public Plugin:myinfo = {
	name = "[TF2] Set Countdown Timer",
	author = "RueLee",
	description = "Allows player to set a countdown timer.",
	version = PLUGIN_VERSION,
	url = ""
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
	
	RegAdminCmd("sm_setcountdown", CmdSetCountdown, ADMFLAG_CHANGEMAP, "Set a target to start a timer.");
	RegAdminCmd("sm_settimer", CmdSetCountdown, ADMFLAG_CHANGEMAP, "Set a target to start a timer.");
	RegAdminCmd("sm_stoptimer", CmdStopTimer, ADMFLAG_CHANGEMAP, "Start a timer after when a target is declared.");
}

public OnPluginEnd() {
	ClearFormat();
}

public OnMapStart() {
	ClearFormat();
}

public OnMapEnd() {
	ClearFormat();
}

public void ClearFormat() {
	g_ballowCountdown = false;
	g_hTimerTick = null;
	g_hUpdatePanel = null;
}

public void OnLibraryAdded(const char[] sName) {
	if (StrEqual(sName, "updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

public Action CmdSetCountdown(int client, int args) {
	if (g_hcountdownEnabled.IntValue == 0) {
		ReplyToCommand(client, "[SM] Countdown Timer plugin is currently disabled!");
		return Plugin_Handled;
	}
	
	if (g_ballowCountdown) {
		ReplyToCommand(client, "[SM] Timer is already declared by someone. Please wait until the timer is finished.");
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
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tnIsM1;
	
	if ((target_count = ProcessTargetString(
			nameArg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tnIsM1)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	g_iTarget = FindTarget(client, nameArg, false, false);
	
	g_iSeconds = seconds % 60;
	g_iHours = seconds / 60;
	g_iMinutes = g_iHours % 60;
	g_iHours /= 60;
	
	g_ballowCountdown = true;
	g_hTimerTick = CreateTimer(1.0, Timer_Count, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	g_hUpdatePanel = CreateTimer(0.5, Timer_PanelCount, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	PrintToChat(client, "[SM] Set countdown on %s", target_name);
	PrintToChat(g_iTarget, "[SM] %N has declared a countdown timer for %d:%02d:%02d!", client, g_iHours, g_iMinutes, g_iSeconds);
	return Plugin_Handled;
}

public Action Timer_PanelCount(Handle hTimer, any cID) {
	char buffer[255];
	
	int client = GetClientOfUserId(cID);
	
	char targetname[MAX_NAME_LENGTH];
	FormatEx(targetname, sizeof(targetname), "Name: %N", g_iTarget);
	FormatEx(buffer, sizeof(buffer), "Timeleft: %d:%02d:%02d", g_iHours, g_iMinutes, g_iSeconds);
	
	Panel hpanel = new Panel();
	
	hpanel.SetTitle("===[Countdown Timer]===");
	hpanel.DrawText(" ");
	hpanel.DrawText(targetname);
	hpanel.DrawText(buffer);
	hpanel.DrawText(" ");
	hpanel.DrawItem("Exit", ITEMDRAW_CONTROL);
	hpanel.Send(client, RunTimer, 0);
	CloseHandle(hpanel);
	
	return Plugin_Continue;
}

public Action CmdStopTimer(int client, int args) {
	if (g_ballowCountdown) {
		ClearTimer(g_hTimerTick);
		ClearTimer(g_hUpdatePanel);
		g_ballowCountdown = false;
		PrintToChat(client, "[SM] Terminated countdown operation!");
		PrintToChat(g_iTarget, "[SM] %N has stopped the countdown!", client);
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
	//int client = GetClientOfUserId(cID);
	
	if (g_ballowCountdown) {
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
			ClearTimer(g_hTimerTick);
			ClearTimer(g_hUpdatePanel);
			g_ballowCountdown = false;
			CPrintToChat(g_iTarget, "{green}[SM] {fullred}Time is up!");
			EmitSoundToClient(g_iTarget, ALARM_TRIGGER, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.4);
		}
	}
	return Plugin_Continue;
}

stock void ClearTimer(Handle hTimer) {
	if (hTimer != null) {
		KillTimer(hTimer);
		hTimer = null;
	}
}
