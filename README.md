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
sm_stoptimer
- Stops the timer while a target is already declared.
```
Note: If a player declared a countdown timer on someone, players will not call another one until the timer is finished or the player stopped the countdown.
