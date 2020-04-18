#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

#define PLUGIN_VERSION "1.0.1"

//constants
#define SPEC_TEAM 1
#define AMER_TEAM 2
#define BRIT_TEAM 3

char BannedWeapon[64];

new clip;
Handle Timer;
Handle AmmoTimer;
Handle RestartTimer;
Handle RoundTimer;
float RoundTime;
float CurrentRoundTime;
bool IsLastBrit;
bool PluginEnabled;

public Plugin:myinfo = 
{
	name = "BG3 Zombie Mode Plugin",
	author = "ChrisK112",
	description = "A plugin that handles the execution of a zombie mode on a server. Requires sm_colorize to be available.",
	version = PLUGIN_VERSION,
	url = "https://chrisk112.github.io/portfolio/#/"
};

public OnPluginStart()
{
	//set initial values
	BannedWeapon = "hanger";
	RoundTime = 600.0;
	CurrentRoundTime = 0.0;
	IsLastBrit = false;
	PluginEnabled = false;


	RegAdminCmd("sm_zstart", Start_Zombie, ADMFLAG_ROOT, "Starts the zombie mode cycle - should run zombie.cfg instead!");
	RegAdminCmd("sm_zstop", Stop_Zombie, ADMFLAG_ROOT, "Stops the zombie mode.");
	RegAdminCmd("sm_zroundtime", CallChangeRoundTime, ADMFLAG_ROOT, "Change the time each round takes.");
	//RegAdminCmd("sm_zamount", ChangeZombieAmount, ADMFLAG_ROOT, "Change the number of zombies that get spawned on round start. def = 1"); saved for future. 
	
	// Create the rest of the cvar's
	CreateConVar("sm_zombie_version", PLUGIN_VERSION, "Zombie mode version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

}


//unhook stuff on map end
public void OnMapEnd()
{
	RemoveCommandListener(RoundTimeChange,"mp_roundtime");
	UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	UnhookEvent("player_spawn", SpawnEvent, EventHookMode_Post);
	delete RoundTimer;
	delete Timer;
	delete RestartTimer;
	delete AmmoTimer;
	PluginEnabled = false;
}

//not much needed here really, just making sure plugin doesnt carry over to next map
public void OnMapStart()
{
	OnMapEnd();
}


// on player death
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	char pname[64];
	char aname[64];
	char weapon[64];
	int client = event.GetInt("userid");
	int att = event.GetInt("attacker");
	new clientp = GetClientOfUserId(client);
	new attp = GetClientOfUserId(att);
	new teamp = GetClientTeam(clientp);
	
	GetClientName(clientp, pname, sizeof(pname));
	GetClientName(attp, aname, sizeof(aname));
	

	if(IsClientValid(clientp))
	{		
		

		if(attp != clientp) //not suicide or first spawn - first spawn has team at 0
		{
			
			if(teamp == AMER_TEAM)
			{
				//if its the last brit, then american deaths dont matter. - He can use melee weapons
				if(LastBrit())
				{
					return Plugin_Continue;
				}
				event.GetString("weapon", weapon, sizeof(weapon));
				//is it a banned weapon?
				if(strcmp(weapon, BannedWeapon) == 0)
				{

					ServerCommand("amer \"%s\"", aname);	
					//change to green
					ServerCommand("sm_colorize \"%s\" green", aname);
					
					//if somehow the last two brits die at same time, and the first (LastBrit()) doesnt return false
					if(LastBrit())
					{
						char msg[64] = "Zombies Win!";
						ServerCommand("msay \"%s\"", msg);
						//destroy Timer, restart round
						delete Timer;
						RestartRound();
					}
					
				}
			}
			
			if(teamp == BRIT_TEAM)
			{
				//check if that was the last brit on team. If so, game will end round, so start zombie mode again
				if(LastBrit())
				{
					char msg[64] = "Zombies Win!";
					ServerCommand("msay \"%s\"", msg);
					//destroy Timer, restart round
					delete Timer;
					RestartRound();
				}
				
			
				//change to american
				ServerCommand("amer \"%s\"", pname);
				
				//change to green
				ServerCommand("sm_colorize \"%s\" green", pname);
			}
		
			
		}
		

	}
	return Plugin_Handled;
		
} 

//player spawn
public Action SpawnEvent(Handle:event,const String:name[],bool:dontBroadcast)
{

	char pname[64];
	new client_id = GetEventInt(event, "userid");
	new client = GetClientOfUserId(client_id);
	new team = GetClientTeam(client);
	GetClientName(client, pname, sizeof(pname));
	
	if(team == BRIT_TEAM)
	{
		//change to normal
		ServerCommand("sm_colorize \"%s\" normal", pname);
	}
	
	return Plugin_Handled;
	
}

//change round time called by sm_ command sm_zroundtime
public Action CallChangeRoundTime(client, args)
{
	if(PluginEnabled)
	{
		char arg[16];
		GetCmdArg(1, arg, sizeof(arg)); //get argument
		float newTime = StringToFloat(arg);
		ChangeRoundTime(newTime);
		
		//change in-game round time too
		int time = RoundToZero(RoundTime);
		ServerCommand("mp_roundtime %d", time);		
	}
	
}

public void ChangeRoundTime(float time)
{
	float newTime = time;
	if(newTime > 0.0)
	{
		RoundTime = newTime;	
		float diff = newTime - CurrentRoundTime;
		if(diff < 0)
		{
			diff = 0.0;
		}
		
		//use difference to set timer to remaining time
		delete Timer;
		Timer = CreateTimer(diff, TimerRunOut);

	}
}

//called on round time being changed via mp_roundtime x
public Action RoundTimeChange(client, const String:command[], argc)
{
	PrintToChatAll("Round time change detected.");
	
	char arg[16];
	GetCmdArg(1, arg, sizeof(arg)); //get argument
	//need to check if this gets any args, and which ones
	float newTime = StringToFloat(arg);
	
	ChangeRoundTime(newTime);
	return Plugin_Continue;
	
}




/*********************** START PLUGIN *********************/
//called on first startup by config file
public Action Start_Zombie(client, args)
{

	//set enabled bool
	PluginEnabled = true;

	
	//Hook events
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_spawn", SpawnEvent, EventHookMode_Post);
	//events round_win or round_end or teamplay_round... etc not visible or dont exist or dont get fired
	
	//Hook commands to change plugin values to match them
	 AddCommandListener(RoundTimeChange,"mp_roundtime");
	
	//Get the clip variable from CBaseCombatWeapon class.
    clip = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
	
	
	//create reapting timer to take away amer clips
	AmmoTimer = CreateTimer(1.0, StripClip, _, TIMER_REPEAT);
	
	//create temp timer
	Timer = CreateTimer(RoundTime + 10.0, TimerRunOut);
	
	//Create a Timer that keeps track of current round time
	RoundTimer = CreateTimer(0 + 10.0, UpdateTime, _, TIMER_REPEAT);
	
	Zombie_Start(Timer);
	
	//first Timer to include 10 second start time - as in config
	delete Timer;
	Timer = CreateTimer(RoundTime + 10.0, TimerRunOut);
	

	return Plugin_Handled;
	
		
}

/*********************** STOP PLUGIN *********************/
public Action Stop_Zombie(client, args)
{
	OnMapEnd();
}

/*********************** SETUP TEAMS *********************/
public Action Zombie_Setup(const char[] zombie_name)
{
	PrintToChatAll("Zombie Mode Started"); 
	ServerCommand("amer @all");
	ServerCommand("brit @all");
	ServerCommand("amer \"%s\"", zombie_name);
	ServerCommand("slay @all");
	ServerCommand("spawn @all");
	ServerCommand("sm_colorize \"%s\" green", zombie_name);
	return Plugin_Handled;
		
}

/*********************** ROUND START CYCLE *********************/
public Action Zombie_Start(Handle timer)
{
	//delete previous Timer(s)
	delete Timer;
	delete RestartTimer;
	
	//reset round time
	CurrentRoundTime = 0.0;
	
	//setup Timer
	Timer = CreateTimer(RoundTime, TimerRunOut);
	
	//choose zombie
	char zombie_name[64];
	new zombie_id = GetRandomPlayer();
	GetClientName(zombie_id, zombie_name, sizeof(zombie_name));
	
	Zombie_Setup(zombie_name);
	
	PrintToChatAll("%s was chosen to be the zombie!", zombie_name); 
} 

/*********************** VALID PLAYER *********************/
stock bool:IsClientValid(i)
{
	if(i > 0 && i <= MaxClients && IsClientInGame(i))
	{
		return true;
	}
	
	return false;
}

/*********************** RANDOM PLAYER *********************/
stock int GetRandomPlayer() 
{
    int[] clients = new int[MaxClients];
    int clientCount;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            clients[clientCount++] = i;
        }
    }
    return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
} 

/*********************** LAST BRIT DEAD? *********************/
//Note this will count the Brit that DIED PLUS whoever is left on team
//Might change to check if the player is DEAD too.
stock bool:LastBrit()
{
	int brits = 0;
    for(int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
			new team = GetClientTeam(i);
            if(team == BRIT_TEAM)
			{
				brits++;
				//not > 1 since we want to check if 1 brit is left alive still.
				if(brits > 2)
				{
					return false;
				}
			}
			
        }
    }
	//1 if last, 0 if he got switched to amer already.
	if(brits == 1 || brits == 0) 
	{
		return true;
	}
	
	//check to see if there is 1 more brit alive
	if(brits == 2)
	{
		IsLastBrit = true;
	}
	
	return false;

}

//loop through clients and change dead brits to amer
stock CheckForDeadBrits()
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
			new team = GetClientTeam(i);
            if(team == BRIT_TEAM)
			{
				if(IsPlayerAlive(i)){}
				else 
				{
					char name[64];
					GetClientName(i, name, sizeof(name));
					ServerCommand("amer \"%s\"", name);
					ServerCommand("sm_colorize \"%s\" green", name);
				}
				
			}
			
        }
    }

}

/*********************** REMOVING AMER ABILITY TO FIRE *********************/
public Action StripClip(Handle timer)
{
    for (new i = 1; i <= MaxClients; i++)	
    {	
		new client = i;

		//Check if the client is able to receive his bullet.
		if (IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client))		
		{
			new team = GetClientTeam(client);
			
			if(team == AMER_TEAM)
			{
				new activeweapon = FindSendPropInfo("CAI_BaseNPC", "m_hActiveWeapon");
				new CurrentWeapon = GetEntDataEnt2(client, activeweapon);
				if(IsValidEntity(CurrentWeapon))	
				{
					SetEntData(CurrentWeapon, clip, 0, 4, true);
				}
			}

		}                          
    }
	
	//while we're here, lets check if there are any dead brits, and change them to american
	CheckForDeadBrits();

}

/*********************** TIME HANDLING *********************/
public Action UpdateTime(Handle timer)
{
	CurrentRoundTime = CurrentRoundTime + 1.0;
}

/*********************** END OF ROUND STUFF *********************/
//if it aint built, build it yerself!
public Action TimerRunOut(Handle timer)
{
	//destroy Timer
	delete Timer;
	char msg[64] = "Survivors Win!";
	ServerCommand("msay \"%s\"", msg);
	
	//restart
	RestartRound();
}

stock void RestartRound()
{
	IsLastBrit = false;
	//small delay, then start again.
	RestartTimer = CreateTimer(1.0, Zombie_Start);
	ServerCommand("slay @all");
	ServerCommand("sv_restartround 3");
	

}
