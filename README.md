# Zr-Leader2-Anubis-Edition
 
### Improved version of zombiereloaded plugin with support for CS:GO and CS:S

* This plugin is an updated version of AntiTeal plugin, under a new author.

* Test & Compile, SouceMod 1.10.0-6492
* Sorry for my English.

* Author AntiTeal, Anubis Edition
* Version = 3.0-A, Anubis edition

### Decription:Zr-Leader2-Anubis-Edition

* Allows for an admin to select or for regular players to vote for a human to be the leader for the current round. 
* The leader gets special perks, like the ability to put defend here / follow me sprites above their head, 
place defend markers, toggle a rainbow beacon, custom chat, custom radio commands, and maybe more in the future.
* Now the leader can place 2 marks.
* Redesigned menu.
* Now if you type !voteleader without typing the name of the player, a player menu will open to vote.
* Translation file added, just edit.
* It is now possible to disable the definition in which admin typed !leader and became a leader automatically.

### Server ConVars

* sm_leader_version - Leader Version (3.0-A)
* sm_leader_allow_votes - Determines whether players can vote for leaders. (Default: "1")
* sm_leader_defend_vmt - The defend here .vmt file (Default: "materials/sg/sgdefend.vmt")
* vsm_leader_defend_vtf - The defend here .vtf file (Default: "materials/sg/sgdefend.vtf")
* sm_leader_follow_vmt - The follow me .vmt file (Default: "materials/sg/sgfollow.vtf")
* sm_leader_follow_vtf - The follow me .vtf file (Default: "materials/sg/sgfollow.vtf")
* sm_leader_admin_leader - Determines whether Admin can access menu leader, without voting. (Default: "1")

### Server Commands

* sm_leader - Access the leader menu OR Set a player to be leader (ADMFLAG_GENERIC)
* sm_currentleader - Shows the current leader.
* sm_voteleader - Votes for the specified player to be leader. Required votes is current player count / 10.
* sm_removeleader (ADMFLAG_GENERIC) - Removes the current leader.

# Add Commands

* sm_le - Access the leader menu OR Set a player to be leader (ADMFLAG_GENERIC)
* sm_cl - Shows the current leader.
* sm_vl - Votes for the specified player to be leader. Required votes is current player count / 10.
* sm_rl (ADMFLAG_GENERIC) - Removes the current leader.