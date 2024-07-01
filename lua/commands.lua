local M = {}

local function create_make_command(make_target, settings, env)
  local parts = {}
  table.insert(parts, "make -f " .. env["buildscript_path"] .. " -s " .. make_target)
  table.insert(parts, "PARTICLE_CLI_PATH=" .. env["particle_path"])
  table.insert(parts, "DEVICE_OS_PATH=" .. env["device_os_path"])
  table.insert(parts, "APPDIR=" .. env["appdir"])
  table.insert(parts, "PLATFORM=" .. settings["platform"])
  table.insert(parts, "PLATFORM_ID=" .. env["platform_id"])
  return table.concat(parts, " ")
end

local function create_bear_command(make_target, settings, env)
  return "bear -- " .. create_make_command(make_target, settings, env)
end

local function create_bear_append_command(make_target, settings, env)
  return "bear --append -- " .. create_make_command(make_target, settings, env)
end

function M.compile_user(settings, env)
  return create_bear_append_command("compile-user", settings, env)
end
function M.flash_user(settings, env)
  return create_make_command("flash-user", settings, env)
end
function M.clean_user(settings, env)
  return create_make_command("clean-user", settings, env) .. " && rm -f compile_commands.json"
end

-- TODO:These all commands are incomplete
-- function M.compile_all(settings, env)
--   return create_bear_command("compile_all", settings, env)
-- end
-- function M.flash_all(settings, env)
--   return create_make_command("flash_all", settings, env)
-- end
-- function M.clean_all(settings, env)
--   return create_make_command("clean_all", settings, env)
-- end

-- function M.compile_debug(settings, env)
--   return create_bear_append_command("compile_debug", settings, env)
-- end
-- function M.flash_debug(settings, env)
--   return create_make_command("flash_debug", settings, env)
-- end
-- function M.clean_debug(settings, env)
--   return create_make_command("clean_debug", settings, env)
-- end

return M
