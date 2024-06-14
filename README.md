## Downloads
[![ContentDB](https://content.minetest.net/packages/DragonWrangler/modding_commands/shields/downloads/)](https://content.minetest.net/packages/DragonWrangler/modding_commands/)

## License ##
-------------
#############

 - MIT
 
## Description ##
-----------------
#################

 - [This mod adds several commands to hopefully help with modding.]
 
## Command Explanations ##
--------------------------
##########################

 - [Bulk Replace]
 - Replaces a specified word in all lua files and the mod.conf of a specified mod.
 
 - [Check Nodes]
 - Checks for unknown nodes in all mts files of the specified directory. for logging you can choose between a chat message, a formspec, or a file.
 
 - [Check Whitespace]
 - Checks for unusual whitespace like spaces followed by tabs, or spaces following the end of the text. (Note. May not always be 100% accurate)
 
 - [Check Code]
 - Checks the code for errors (Note. Not particularly accurate. It mainly only checks for nil values, won't log an error if you mess up node registry)
 
 - [Delete Map Shutdown]
 - Does pretty much what it says. It deletes the map.sqlite and makes the world shutdown. (Note. [DO NOT USE IN MULTIPLAYER WORLDS!! THIS WILL WIPE OUT EVERYTHING THAT ISN'T PART OF THE MAP SEED! AND I MEAN EVERYTHING.])
 
 - [Dependency Map]
 - Once again does pretty much what it says. It lists the dependencies of each enabled mod. (Note. currently only in chat format. formspec and file coming soon.)
 
 - [Find Mods]
 - Finds all mods that have files containing the specified keyword.
 
 - [List Schematics]
 - lists all schematics in the specified mods Schematic folder.
 
 - [List Schems]
 - Same as above, but checks for a Schems folder instead.
 
 - [Lua2Mts All]
 - Converts all Lua schematic files in a specified directory into .mts files.
 
 - [Mts2Lua All]
 - Convert all Mts schematic files in a specified directory into .lua files.
 
 - [Rename Png]
 - Renames the specified png file.
 
 - [Rename Png All]
 - Replaces a specified word that is found in all png files in a specified mod.
 
 - [Both Below Are Outdated Use Bulk Replace Instead]
 
 - [Replace In File] 
 - replaces a word, in a mod. With the specified file.
 
 - [Replace In Modconf]
 - Same as above, but does the mod.conf
 
 - [Review Code]
 - Reviews your code looking for whitespace, unused, and undefined variables (Note. [Not Accurate.])
 
## Extras ##
------------
############

 - The following commands use os functions.
 
 - [delete_map_shutdown] 
 - os.remove
 - Used for deleting the map.sqlite.
 
 - [rename_png]
 - os.rename
 - Used for renaming the png files.
 
 - [rename_png_all]
 - os.rename
 - Used for renaming the png files.
 
 
