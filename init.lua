local S = minetest.get_translator("modding_commands")
local ie = minetest.request_insecure_environment()

minetest.register_on_joinplayer(function(player)
	local player_name = player:get_player_name()
	if minetest.settings:get_bool('backup_warning', true) then
	local message = minetest.colorize("#00FFFF", "<Modding Commands> Please make backups of any files you plan to modify with any of the commands from the modding_commands mod. This mod is still experimental, but fully functional. Please keep all backups until you verify the modified files work properly. To disable this message please use the chat command backup_message. With param false.")
	minetest.chat_send_player(player_name, message)
	end
	if not ie then
		local disclamer = minetest.colorize("#FF4000", "This mod requires an insecure environment, please add it to secure.trusted_mods. If you don't trust it please examine the code.")
		minetest.chat_send_player(player_name, disclamer)
	end
end)

local DIR_DELIM = "/"

minetest.register_chatcommand("backup_warning_message", {
	params = "<false> <true>",
	description = "Enables or disables the create backup message",
	privs = {server = true},
	func = function(name, param)
		-- Convert param to lowercase to handle case insensitivity
		param = param:lower()
		
		if param == "false" then
			minetest.settings:set("backup_warning", "false")
			return true, "Backup warning message has been disabled."
		elseif param == "true" then
			minetest.settings:set("backup_warning", "true")
			return true, "Backup warning message has been enabled."
		else
			return false, "Invalid parameters. Usage: /backup_warning_message false or /backup_warning_message true"
		end
	end
})

-- The following script checks for invalid whitespace areas.
minetest.register_chatcommand("check_whitespace", {
	params = "<modname> <filename>",
	description = "Checks for improper indentation (leading/trailing spaces) in the specified mod and file, ignoring comments",
	privs = {server = true},
	func = function(name, param)
		local modname, filename = param:match("(%S+)%s+(%S+)")
		if not modname or not filename then
			return false, "Invalid parameters. Usage: /check_whitespace <modname> <filename>"
		end
		local modpath = minetest.get_modpath(modname)
		if not modpath then
			return false, "Mod not found: " .. modname
		end
		local filepath = modpath .. "/" .. filename
		local file = ie.io.open(filepath, "r")
		if not file then
			return false, "File not found: " .. filename
		end
		local lines = {}
		local line_num = 1
		local in_multiline_comment = false
		for line in file:lines() do
			local check_line = line
			if in_multiline_comment then
				if line:match(".*%]%]") then
						in_multiline_comment = false
				end
				line_num = line_num + 1
			elseif line:match(".*%[%[.*") then
				in_multiline_comment = true
				line_num = line_num + 1
			else
				check_line = check_line:gsub("%-%-.*", "")
				local indent = check_line:match("^ *")
				if indent:match(" $") then
					table.insert(lines, "Line " .. line_num .. ": Trailing space in indentation")
				end
				if line:match(".* +$") then
					table.insert(lines, "Line " .. line_num .. ": Trailing space at end of line")
				end
				line_num = line_num + 1
			end
	end
	file:close()
	if #lines == 0 then
		return true, "No improper indentation or trailing spaces found in " .. filename
	else
		local result = "Issues found in " .. filename .. ":\n"
		result = result .. table.concat(lines, "\n")
		return true, result
	end
end,
})

-- The following script can replace a specified word in all lua files of a specified mod.
minetest.register_chatcommand("bulk_replace", {
	params = "<modname> <oldword> <newword>",
	description = "Replace a word in all Lua files and mod.conf of a mod",
	privs = {server = true},
	func = function(name, param)
		local modname, oldword, newword = string.match(param, "^(%S+)%s+(%S+)%s+(%S+)$")
		if not modname or not oldword or not newword then
			return false, "Invalid usage. Correct usage: /bulk_replace <modname> <oldword> <newword>"
		end
		local modpath = minetest.get_modpath(modname)
		if not modpath then
			return false, "Mod " .. modname .. " not found."
		end
		local total_replacements = 0
		local function replace_in_file(filepath)
		local file = ie.io.open(filepath, "r")
		if not file then
			return false, "File " .. filepath .. " not found."
		end
		local content = file:read("*all")
		file:close()
		local new_content, replacements = content:gsub(oldword, newword)
		if replacements > 0 then
			file = ie.io.open(filepath, "w")
			if not file then
				return false, "Failed to open file " .. filepath .. " for writing."
			end
			file:write(new_content)
			file:close()
			minetest.chat_send_player(name, "Replaced " .. replacements .. " occurrences in file: " .. filepath)
			total_replacements = total_replacements + replacements
		else
			minetest.chat_send_player(name, "No occurrences of '" .. oldword .. "' found in file: " .. filepath)
		end
	end
	local confpath = modpath .. "/mod.conf"
	replace_in_file(confpath)
	local function search_and_replace_in_files(path)
		local file_list = minetest.get_dir_list(path, false)
		local dir_list = minetest.get_dir_list(path, true)
		for _, filename in ipairs(file_list) do
			local filepath = path .. "/" .. filename
			if filename:sub(-4) == ".lua" then
				replace_in_file(filepath)
			end
		end
		for _, dirname in ipairs(dir_list) do
			local dirpath = path .. "/" .. dirname
			search_and_replace_in_files(dirpath)
		end
	end
	search_and_replace_in_files(modpath)
	minetest.chat_send_player(name, "Word replacement completed in mod: " .. modname .. ". Total replacements: " .. total_replacements)
	return true, "Word replacement completed in mod: " .. modname .. ". Total replacements: " .. total_replacements
end,
})

-- The following script searches for all mods that have files containing a specified key word.
function searchMods(keyword)
	local mods = minetest.get_modnames()
	local matchingMods = {}
	for _, modname in ipairs(mods) do
		local modpath = minetest.get_modpath(modname)
		if modpath then
			local files = minetest.get_dir_list(modpath, false)
			if files then
				local modFiles = {}
				for _, file in ipairs(files) do
					if containsKeyword(modpath .. "/" .. file, keyword) then
						table.insert(modFiles, file)
					end
				end
				if next(modFiles) then
					matchingMods[modname] = modFiles
				end
			else
				minetest.log("warning", "Failed to retrieve files in mod: " .. modname)
			end
		else
			minetest.log("warning", "Failed to retrieve modpath for mod: " .. modname)
		end
	end
	return matchingMods
end
function containsKeyword(file, keyword)
	local f = ie.io.open(file, "r")
	if f then
		local content = f:read("*all")
		f:close()
		return content:find(keyword, 1, true) ~= nil
	else
		minetest.log("warning", "Failed to open file: " .. file)
		return false
	end
end
minetest.register_chatcommand("findmods", {
	params = "<keyword>",
	description = "Find mods containing a specified keyword",
	privs = {server = true},
	func = function(name, param)
		local matchingMods = searchMods(param)
		if next(matchingMods) then
			local message = "Mods containing the word '" .. param .. "':\n"
			for modname, files in pairs(matchingMods) do
				message = message .. modname .. ":\n" .. table.concat(files, ", ") .. "\n"
			end
			minetest.chat_send_player(name, message)
		else
			minetest.chat_send_player(name, "No mods found containing the word '" .. param .. "'.")
		end
	end,
})

-- The following script shows the description and dependencies of all enabled mods.
minetest.register_chatcommand("depmap", {
	description = "Maps the dependency tree of all enabled mods",
	privs = {server = true},
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end
		local mods = minetest.get_modnames()
		local function get_mod_info(modname)
			local path = minetest.get_modpath(modname)
			if not path then return nil end
				local mod_conf = path .. "/mod.conf"
				local depends_conf = path .. "/depends.txt"
				local mod_info = {
					name = modname,
					description = "No description available",
					depends = {},
					optional_depends = {}
				}
				local file = ie.io.open(mod_conf, "r")
				if file then
					for line in file:lines() do
						if line:match("^description%s*=") then
							mod_info.description = line:match("^description%s*=%s*(.*)")
						elseif line:match("^depends%s*=") then
							for dep in line:match("^depends%s*=%s*(.*)"):gmatch("([^,]+)") do
								table.insert(mod_info.depends, dep:match("^%s*(.-)%s*$"))
							end
						elseif line:match("^optional_depends%s*=") then
							for dep in line:match("^optional_depends%s*=%s*(.*)"):gmatch("([^,]+)") do
								table.insert(mod_info.optional_depends, dep:match("^%s*(.-)%s*$"))
							end
						end
					end
					file:close()
				end
				file = ie.io.open(depends_conf, "r")
				if file then
					for line in file:lines() do
						local dep = line:match("^([^%s#]+)")
						if dep and dep ~= "" then
							if line:find("?") then
								table.insert(mod_info.optional_depends, dep)
							else
								table.insert(mod_info.depends, dep)
							end
						end
					end
					file:close()
				end
				return mod_info
			end
			local mod_dependencies = {}
			for _, modname in ipairs(mods) do
				mod_dependencies[modname] = get_mod_info(modname)
			end
			local function format_mod_info(mod_info)
				if not mod_info then return "Unknown mod" end
					local str = "Mod: " .. mod_info.name .. "\n"
					str = str .. "Description: " .. mod_info.description .. "\n"
					str = str .. "Dependencies: " .. (next(mod_info.depends) and table.concat(mod_info.depends, ", ") or "None") .. "\n"
					str = str .. "Optional Dependencies: " .. (next(mod_info.optional_depends) and table.concat(mod_info.optional_depends, ", ") or "None") .. "\n"
					return str
				end
				local msg = ""
				for modname, info in pairs(mod_dependencies) do
					msg = msg .. format_mod_info(info) .. "\n"
				end
				minetest.chat_send_player(name, msg)
			return true
		end
})
-- The following script checks for errors in the code of a certain lua file. ie. nil values
minetest.register_chatcommand("checkcode", {
	params = "<mod_name> <file_name>",
	privs = {server = true},
	description = "Check code for errors in a specific mod file",
	func = function(name, param)
		local mod_name, file_name = param:match("(%S+)%s+(%S+)")
		if not mod_name or not file_name then
			return false, "Usage: /checkcode <mod_name> <file_name>"
		end
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Player not found"
		end
		if not minetest.get_modpath(mod_name) then
			return false, "Mod '" .. mod_name .. "' not found"
		end
		local file_path = minetest.get_modpath(mod_name) .. "/" .. file_name
		local file, err_msg = ie.io.open(file_path, "r")
		if not file then
			return false, "Error opening file: " .. err_msg
		end
		local code = file:read("*all")
		file:close()
		local success, error_msg = pcall(loadstring(code))
		if not success then
			minetest.chat_send_player(name, "Error in code: " .. error_msg)
		else
			minetest.chat_send_player(name, "Code has no errors")
		end
	end,
})

-- The following script looks through all mts files in a specified directory and reads them to see if they contain unknown nodes.

local function get_files_in_dir(path, extension)
    local files = {}
    local p = ie.io.popen('find "' .. path .. '" -type f -name "*' .. extension .. '"')
    for file in p:lines() do
        table.insert(files, file)
    end
    p:close()
    return files
end

local function read_mts_file(filename)
    local success, schem = pcall(minetest.read_schematic, filename, {})
    if not success then
        return nil, "Failed to read schematic: " .. filename
    end
    return schem
end

local function save_report(filename, report)
	local file, err = ie.io.open(filename, "w")
	if not file then
		return false, err
	end
	file:write(report)
	file:close()
	return true
end
local OUTPUT_CHAT = 1
local OUTPUT_FORMSPEC = 2
local OUTPUT_FILE = 3
local function parse_output_option(output)
	if output == "chat" then
		return OUTPUT_CHAT 
	elseif output == "formspec" then
		return OUTPUT_FORMSPEC
	elseif output == "file" then
		return OUTPUT_FILE
	else
		return nil
	end
end
minetest.register_chatcommand("check_nodes", {
	params = "<modname> [output: chat, formspec, file]",
	description = "Check for unregistered nodes in .mts files for the specified mod",
	privs = {server=true},
	func = function(name, param)
		local modname, output = param:match("(%S+)%s*(.*)")
		if not modname then
			return false, "Usage: /check_nodes <modname> [output: chat, formspec, file]"
		end
		if output == "" then
			return false, "Invalid output option. Choose from: chat, formspec, file"
		end
		local output_option = parse_output_option(output)
		if not output_option then
			return false, "Invalid output option. Choose from: chat, formspec, file"
		end
		local modpath = minetest.get_modpath(modname)
		if not modpath then
			return false, "Mod not found: " .. modname
		end
		local files = get_files_in_dir(modpath, ".mts")
		if #files == 0 then
			return false, "No .mts files found in the mod: " .. modname
		end
		local unregistered_nodes = {}
		local invalid_files = {}
		for _, file in ipairs(files) do
			local schem, err = read_mts_file(file)
			if not schem then
				minetest.log("error", err)
			else
			local has_invalid_nodes = false
				for _, node in ipairs(schem.data) do
					local nodename = node.name
					if not minetest.registered_nodes[nodename] then
						unregistered_nodes[nodename] = true
						has_invalid_nodes = true
					end
				end
				if has_invalid_nodes then
					table.insert(invalid_files, file)
				end
			end
		end
		table.sort(invalid_files)
		local sorted_unregistered_nodes = {}
		for nodename, _ in pairs(unregistered_nodes) do
			table.insert(sorted_unregistered_nodes, nodename)
		end
		table.sort(sorted_unregistered_nodes)
		local node_report = ""
		for _, nodename in ipairs(sorted_unregistered_nodes) do
			node_report = node_report .. "- " .. nodename .. "\n"
		end
		local file_report = ""
		for _, file_name in ipairs(invalid_files) do
			file_report = file_report .. "- " .. file_name .. "\n"
		end
		local result_msg
		if node_report == "" then
			result_msg = "All nodes in .mts files are registered."
		else
			result_msg = "Unregistered nodes found:\n" .. node_report
		end
		if file_report ~= "" then
			result_msg = result_msg .. "\n\nFiles with invalid nodes:\n" .. file_report
		end
		if output_option == OUTPUT_FORMSPEC then
			local formspec = "size[8,5]"
			formspec = formspec .. "textarea[0.5,0.5;7.5,4;;;" .. result_msg .. "]"
			minetest.show_formspec(name, "check_nodes_result", formspec)
		elseif output_option == OUTPUT_FILE then
			local filename = modpath .. "/report.txt"
			local save_result, save_error = save_report(filename, result_msg)
			if not save_result then
				return false, "Failed to save report to file: " .. save_error
			end
			minetest.chat_send_player(name, "Report saved to file: " .. filename)
		elseif output_option == OUTPUT_CHAT then
			minetest.chat_send_player(name, result_msg)
		end
		return
	end,
})

minetest.register_chatcommand("mts2lua_all", {
	description = "Convert all .mts schematic files in a mod directory to .lua files",
	privs = {server = true},
	params = "<modname> [comments]",
	func = function(name, param)
		local modname, comments_str = string.match(param, "^([^ ]+) *(.*)$")

		if not modname then
			return false, "No mod name specified."
		end

		local comments = comments_str == "comments"
		local modpath = minetest.get_modpath(modname) .. "/schematics"

		if not modpath then
			return false, "Mod not found: " .. modname
		end

		local schem_files = minetest.get_dir_list(modpath, false)
		local export_path = modpath-- .. DIR_DELIM .. "schematics"
		--minetest.mkdir(export_path) -- Ensure directory exists

		for _, file in ipairs(schem_files) do
			if file:sub(-4) == ".mts" then
				local schem_path = modpath .. DIR_DELIM .. file
				local schematic = minetest.read_schematic(schem_path, {})
				if schematic then
					local str = minetest.serialize_schematic(schematic, "lua", {lua_use_comments=comments})
					local lua_file = file:sub(1, -5) .. ".lua"
					local lua_path = export_path .. DIR_DELIM .. lua_file
					local output_file = ie.io.open(lua_path, "w")
					if output_file and str then
						output_file:write(str)
						output_file:flush()
						output_file:close()
						minetest.chat_send_player(name, "Converted " .. file .. " to " .. lua_file)
					else
						minetest.chat_send_player(name, "Failed to convert " .. file)
						minetest.log("error", "Failed to write Lua file: " .. lua_path)
					end
				else
					minetest.chat_send_player(name, "Failed to read schematic " .. file)
					minetest.log("error", "Failed to read schematic: " .. schem_path)
				end
			end
		end

		return true, "Conversion completed."
	end,
})




-- This command changes all lua schematic files in a specified directory into mts files and if specified replaces certain words in the process.
minetest.register_chatcommand("lua2mts_all", {
	description = "Convert all .lua schematic files in a mod directory to .mts files with optional word replacements",
	privs = {server = true},
	params = "<modname> [replacements]",
	func = function(name, param)
		local modname, replacements_str = string.match(param, "^([^ ]+) *(.*)$")

		if not modname then
			return false, "No mod name specified."
		end

		local modpath = minetest.get_modpath(modname)
		if not modpath then
			return false, "Mod not found: " .. modname
		end

		modpath = modpath .. "/schematics"

		local replacements = {}
		if replacements_str ~= "" then
			for replacement in replacements_str:gmatch("[^,]+") do
				local old, new = replacement:match("([^:]+):([^:]+)")
				if old and new then
					replacements[old] = new
				end
			end
		end

		local lua_files = minetest.get_dir_list(modpath, false)

		for _, file in ipairs(lua_files) do
			if file:sub(-4) == ".lua" then
				local lua_path = modpath .. DIR_DELIM .. file
				local input_file = ie.io.open(lua_path, "r")
				if input_file then
					local content = input_file:read("*all")
					input_file:close()

					-- Apply replacements
					for old, new in pairs(replacements) do
						content = content:gsub(old, new)
					end

					local schematic_func, err = loadstring(content)
				
					if not schematic_func then
						minetest.chat_send_player(name, "Failed to load Lua file " .. file .. ": " .. err)
						goto continue
					end

					local schematic_env = {}
					setfenv(schematic_func, schematic_env)
					
					local success, result = pcall(schematic_func)
					
					if not success then
						minetest.chat_send_player(name, "Error executing Lua file " .. file .. ": " .. result)
						goto continue
					end

					local schematic = schematic_env.schematic
					
					if schematic then
						local mts_file = file:sub(1, -5) .. ".mts"
						local mts_path = modpath .. DIR_DELIM .. ".." .. DIR_DELIM .. "schematics" .. DIR_DELIM .. mts_file

						-- Serialize schematic
						local schem_string = minetest.serialize_schematic(schematic, "mts", {})

						if schem_string then
							local output_file = ie.io.open(mts_path, "wb")
							if output_file then
								output_file:write(schem_string)
								output_file:close()
								minetest.chat_send_player(name, "Converted " .. file .. " to " .. mts_file)
							else
								minetest.chat_send_player(name, "Failed to write MTS file for " .. file)
							end
						else
							minetest.chat_send_player(name, "Failed to serialize schematic for " .. file)
						end
					else
						minetest.chat_send_player(name, "No schematic found in Lua file " .. file)
					end
				else
					minetest.chat_send_player(name, "Failed to read Lua file " .. file)
				end
			end
			::continue::
		end

		return true, "Conversion completed."
	end,
})


-- The following script registers all schematics in a certain directory
minetest.register_chatcommand("list_schematics", {
    params = "<modname>",
    privs = {server = true},
    description = "List all schematics in a certain mod's schematic folder",
    func = function(name, param)
        if param == "" then
            return false, "Please provide a mod name."
        end
        local modname = param
        local modpath = minetest.get_modpath(modname)
        if not modpath then
            return false, "Mod not found: " .. modname
        end
        local schematic_folder = modpath .. "/schematics"
        local file_list = minetest.get_dir_list(schematic_folder, false) or {}

        if #file_list == 0 then
            return true, "No schematics found in the mod: " .. modname .. ". Either the folder doesn't exist or it is empty. Try /list_schems instead"
        end
        local result = "Schematics in " .. modname .. ":\n"
        for _, file in ipairs(file_list) do
            result = result .. file .. "\n"
        end
        return true, result
    end,
})

-- The following script is an alternative to the one above incase a mod doesn't have a schematics folder, but rather a schems folder
minetest.register_chatcommand("list_schems", {
    params = "<modname>",
    privs = {server = true},
    description = "List all schematics in a certain mod's schem folder",
    func = function(name, param)
        if param == "" then
            return false, "Please provide a mod name."
        end
        local modname = param
        local modpath = minetest.get_modpath(modname)
        if not modpath then
            return false, "Mod not found: " .. modname
        end
        local schematic_folder = modpath .. "/schems"
        local file_list = minetest.get_dir_list(schematic_folder, false) or {}

        if #file_list == 0 then
            return true, "No schematics found in the mod: " .. modname .. ". Either the folder doesn't exist or it is empty. Try /list_schematics instead"
        end
        local result = "Schematics in " .. modname .. ":\n"
        for _, file in ipairs(file_list) do
            result = result .. file .. "\n"
        end
        return true, result
    end,
})

minetest.register_chatcommand("unused_textures", {
    params = "<modname>",
    description = "Find unused textures in a specified mod",
    privs = {server=true},
    func = function(name, param)
        if param == "" then
            return false, "You must specify a mod name."
        end
        local modname = param
        local modpath = minetest.get_modpath(modname)
        if not modpath then
            return false, "Mod '" .. modname .. "' not found."
        end
        local texture_path = modpath .. "/textures"
        local textures = {}

        local function list_files_in_directory(directory)
            return minetest.get_dir_list(directory, false)
        end

        local texture_files = list_files_in_directory(texture_path)
        for _, filename in ipairs(texture_files) do
            if filename:match("%.png$") then
                textures[filename] = true
            end
        end

        local function mark_texture_used(texture)
            for sub_texture in texture:gmatch("[^%^]+") do
                sub_texture = sub_texture:gsub("%s+", "") -- Remove any whitespace
                if textures[sub_texture] then
                    textures[sub_texture] = nil
                end
            end
        end

        local function strip_comments(lua_code)
            lua_code = lua_code:gsub("%-%-%[%[.-%]%]", "") -- Remove block comments
            lua_code = lua_code:gsub("%-%-.-\n", "\n") -- Remove line comments
            return lua_code
        end

        local function parse_lua_file(file_path)
            local file = io.open(file_path, "r")
            if not file then
                return
            end
            local lua_code = file:read("*all")
            file:close()
            lua_code = strip_comments(lua_code)
            for str in lua_code:gmatch('[%a%d_.]+%.png') do
                mark_texture_used(str)
            end
        end

        local function scan_files(directory)
            for _, filename in ipairs(list_files_in_directory(directory)) do
                local filepath = directory .. "/" .. filename
                if filename:match("%.lua$") then
                    parse_lua_file(filepath)
                end
            end
        end

        scan_files(modpath)

        -- Scan nodes
        for name, def in pairs(minetest.registered_nodes) do
            if type(def.tiles) == "table" then
                for _, texture in ipairs(def.tiles) do
                    if type(texture) == "string" then
                        mark_texture_used(texture)
                    end
                end
            elseif type(def.tiles) == "string" then
                mark_texture_used(def.tiles)
            end
            if type(def.overlay_tiles) == "table" then
                for _, texture in ipairs(def.overlay_tiles) do
                    if type(texture) == "string" then
                        mark_texture_used(texture)
                    end
                end
            elseif type(def.overlay_tiles) == "string" then
                mark_texture_used(def.overlay_tiles)
            end
        end

        -- Scan items
        for name, def in pairs(minetest.registered_items) do
            if type(def.inventory_image) == "string" then
                mark_texture_used(def.inventory_image)
            end
            if type(def.wield_image) == "string" then
                mark_texture_used(def.wield_image)
            end
            if type(def.tiles) == "table" then
                for _, texture in ipairs(def.tiles) do
                    if type(texture) == "string" then
                        mark_texture_used(texture)
                    end
                end
            elseif type(def.tiles) == "string" then
                mark_texture_used(def.tiles)
            end
        end

        -- Scan entities
        for name, def in pairs(minetest.registered_entities) do
            if type(def.textures) == "table" then
                for _, texture in ipairs(def.textures) do
                    if type(texture) == "string" then
                        mark_texture_used(texture)
                    end
                end
            elseif type(def.textures) == "string" then
                mark_texture_used(def.textures)
            end
        end

        -- Scan particles
        for _, def in pairs(minetest.registered_particles or {}) do
            if type(def.texture) == "string" then
                mark_texture_used(def.texture)
            end
            if type(def.texpool) == "table" then
                for _, texture in ipairs(def.texpool) do
                    if type(texture) == "string" then
                        mark_texture_used(texture)
                    end
                end
            elseif type(def.texpool) == "string" then
                mark_texture_used(def.texpool)
            end
        end

        -- Scan particlespawners
        for _, def in pairs(minetest.registered_particlespawners or {}) do
            if type(def.texture) == "string" then
                mark_texture_used(def.texture)
            end
            if type(def.texpool) == "table" then
                for _, texture in ipairs(def.texpool) do
                    if type(texture) == "string" then
                        mark_texture_used(texture)
                    end
                end
            elseif type(def.texpool) == "string" then
                mark_texture_used(def.texpool)
            end
        end

        local unused_textures = {}
        for texture, _ in pairs(textures) do
            table.insert(unused_textures, texture)
        end
        if #unused_textures == 0 then
            return true, "No unused textures found."
        else
            return true, "Unused textures:\n" .. table.concat(unused_textures, "\n")
        end
    end
})

-- Same as bulk_replace except it should work with all enabled mods
minetest.register_chatcommand("bulk_replace_all", {
	params = "<word_to_replace> <replacement_word>",
	description = "Replace specified words in all files of enabled mods and log changes",
	func = function(name, param)
		local word_to_replace, replacement_word = param:match("(%S+)%s+(%S+)")
		if not (word_to_replace and replacement_word) then
			minetest.chat_send_player(name, "Invalid parameters. Usage: /replace_words <word_to_replace> <replacement_word>")
			return
		end
		local enabled_mods = minetest.get_modnames()
		local files_modified = 0
		local words_replaced = 0
		local function replace_words_in_mods()
			for _, modname in ipairs(enabled_mods) do
				local modpath = minetest.get_modpath(modname)
				local function replace_words_in_directory(directory)
					local cmd = 'find "' .. directory .. '" -type f'
					local files = ie.io.popen(cmd):lines()
					for file in files do
						if file:match("%.lua$") or file:match("%.conf$") or file:match("%.md$") or file:match("%.txt$") then
							local content = ""
							local file_handle, err = ie.io.open(file, "r")
							if file_handle then
								content = file_handle:read("*a")
								file_handle:close()
								local replaced_content, count = content:gsub(word_to_replace, replacement_word)
								if count > 0 then
									words_replaced = words_replaced + count
									local file_handle, err = ie.io.open(file, "w")
									if file_handle then
										file_handle:write(replaced_content)
										file_handle:close()
										files_modified = files_modified + 1
									else
										minetest.chat_send_player(name, "Error writing to file: " .. file)
									end
								end
							else
								minetest.chat_send_player(name, "Error opening file: " .. file)
							end
						end
					end
				end
				replace_words_in_directory(modpath)
			end
		end
		replace_words_in_mods()
		minetest.chat_send_player(name, "Word replacement completed.")
		minetest.chat_send_player(name, "Number of files modified: " .. files_modified)
		minetest.chat_send_player(name, "Number of words replaced: " .. words_replaced)
	end,
})

if minetest.settings:get_bool('developer_options', true) then
local max_registry_limit = 32767
	
local function count_registered_items()
    local node_count = 0
    local craftitem_count = 0
    local tool_count = 0
    local other_count = 0
    
    for name, def in pairs(minetest.registered_items) do
        if def.type == "node" then
            node_count = node_count + 1
        elseif def.type == "craftitem" then
            craftitem_count = craftitem_count + 1
        elseif def.type == "tool" then
            tool_count = tool_count + 1
        else
            other_count = other_count + 1
        end
    end
    
    local total_count = node_count + craftitem_count + tool_count + other_count
    return total_count, node_count, craftitem_count, tool_count, other_count
end

minetest.register_on_joinplayer(function(player)
    local player_name = player:get_player_name()
    
    local total_count, node_count, craftitem_count, tool_count, other_count = count_registered_items()

    if total_count >= max_registry_limit then
        minetest.kick_player(player_name, "Server registry limit reached: " .. total_count .. " items registered.")
        error("Server registry limit reached: " .. total_count .. " items registered.")
    else
        minetest.chat_send_player(player_name, "Registry status:")
        minetest.chat_send_player(player_name, "Nodes: " .. node_count)
        minetest.chat_send_player(player_name, "Craftitems: " .. craftitem_count)
        minetest.chat_send_player(player_name, "Tools: " .. tool_count)
        minetest.chat_send_player(player_name, "Other items: " .. other_count)
        minetest.chat_send_player(player_name, "Total registered: " .. total_count .. " out of " .. max_registry_limit)
    end
end)
end
