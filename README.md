# -TF2-Set-Countdown-Timer
Allows player to set a countdown timer.

**Required plugin:**

-updater.smx


**ConVars:**
```
sm_countdown_enabled | Default: 1
- Enable/Disable plugin.
```

**Commands:**
```
Access flag: g
sm_setcountdown <#userid|name> [seconds]
- Set a target to start a timer.
sm_stoptimer <#userid|name>
- Stops the timer while a target is already declared.
```
Note: After you call a countdown on someone, you cannot call again until your target has reached the end of the time. If you decide to stop the timer, type `sm_stoptimer <#userid|name>`.
