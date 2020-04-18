# bg3_zombie_plugin
A SourceMod plugin for BG3 that simulates a zombie mod seen in other games.

Install instructions:
Requires Battle Grounds 3 game from Steam
Two files, zombie.cfg and bg3_zombie.smx
Drop cfg file into >your steam library</steamapps/common/Battle Grounds III/bg3/cfg
Drop smx file into >your steam library</steamapps/common/Battle Grounds III/bg3//addons/sourcemod/plugins
~done~ 


Presenting the one and only BG3 Zombie Mode Sourcemod Plugin!

Works on any map, and does most of the work for you.

Description:
Each round the plugin chooses one lucky guy to be the zombie (read: american), everyone else as survivors (read: british).
The zombie is a frontiersmen that cannot shoot. - They have a green hue
The survivors are grenadiers that suicide upon killing zombies in melee - except for the last survivor.
When a survivor dies, he becomes a zombie
When all survivors are dead, or the round time is up, the round resets and someone is chosen as a zombie again.

It needs:
1. SourceMod installed on server
2. FuncommandsX Sourcemod Plugin (Optional, for changing player colours, such as zombies to green)
3. Players (bots work too, although are prone to using melee, therefor killing themselves)

Run instructions:
execute the config on a map you wish to play.
/rc exec zombie.cfg

Big thanks to "MagickRabbit" and his "Semi-automatic Weapons" plugin for BG2 (only plugin I found, too), whose ammo trickery was used in this plugin.

Console commands:
sm_zstop - disables the plugin
sm_zroundtime <number> - changes the round time, in case map is too big or too small for current time (default is 600)
sm_zstart - starts the plugin - I recommend using exec config instead, since it changes class limits and round settings for the mod.

Possible Issues:
-Not tested enough
-Round times might not work sometimes. Changing roundtime through mp_roundtime is sometimes not detected by the plugin
-Round starts are a bit laggy with great amount of players
-Code is messy in places, and unoptimized in others
This would've been a lot easier (and less messy) if the game fired/let me hook round_start events or something similar. Using net_showevents, I could only see player_death, player_hurt, player_disconnect, and a few others.
