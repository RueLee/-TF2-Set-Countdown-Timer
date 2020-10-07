# -TF2-Set-Countdown-Timer
This plugin allows player to set a countdown timer on someone.

* **Required plugin:**
  * [Updater](https://forums.alliedmods.net/showthread.php?t=169095)


**ConVars:**
```
sm_countdown_enabled | Default: 1
- Enable/Disable plugin.
```

**Commands:**
```
Access flag: g
sm_setcountdown <#userid|name> [seconds]
Alias: sm_settimer
- Calls a target to start a timer.
sm_stoptimer <#userid|name>
- Stops the timer while a player has countdown timer running.
```
Note: After you call a countdown on someone, you cannot call again until your target has reached the end of the time. If you decide to stop the timer, type `sm_stoptimer <#userid|name>`.
