local config = require("config")
local log = require("log")
local Utils = require("utils")
local Manifest = require("manifest")
local Compile = require("compile")
local settings = require("settings")
local env = require("env")
local Constants = require("constants")
local Commands = require("overseer_commands")
local particle_utils = require("particle_utils")
local ui = require("ui")

--TODO after create config, overseer commands should be registered

local initialized = 0

local M = {}
-- TODO: add way to show user log file location
-- TODO: add way to quickly open log file, like LspLog command

M.PROJECT_DEVICE_OS = 1
M.PROJECT_LOCAL= 2

function M.hello()
  return "hello"
end

function M.get_device_os_ccjson_dir()
  if settings == nil then
    return nil
  end
  local cc_dir = Compile.get_cc_json_dir()
  if not vim.fn.isdirectory(cc_dir) then
    return nil
  end
  return cc_dir
end

-- TODO: check if it exists?
function M.get_query_driver()
  if settings == nil then
    return nil
  end
  return settings.get_query_driver()
end

-- TODO: Look into how to export these functions directly
function M.get_project_type(path)
  return particle_utils.get_project_type(path)
end


--TODO: Switching platform should try to do something to fix the compile_commands.json that is
--used by the device os. This can be done by checking if there exists a compile_commands json
--for the specific platform for the device os and relinking it so that it is active. Otherwise, it
--can prompt the user if it would like to compile the device os to create the compile commands.
-- Would also have to prompt on change in devie os. IDK about change in compiler? Could use custom
-- link names in the modules fokder than link in to the device os.
-- This can get messy with multiple projects using hte same device os but different platforms.
-- Maybe could merge the compile commands json file from device os and project
-- Or could have particle.nvim supplu the correct compile commands json as the query driver arg
-- to clangd!!
--TODO: Need to keep track of which compile-comamnds are linked if going with a linked approach, but
--not for a clangd supplied file via --compile-commands-dir=
-- TODO: add a menu for additional CCFLAGs
-- TODO: add way of determining whether compile-os with bear finished so that it can be restarted on boot
-- TODO: A Clean os is not required for all platforms, only for those for which there is a shared command.
-- Its possible to tell which have the same command via platform-ids.mk in deviceOs/build, but that doesn't
-- necessarily tell you if you need to clean
-- Could look at build/target folder?

-- TODO: Could restart LSP after compiling, technically it works fine, but the diagnostics aren't resolved until
-- restart

-- TODO: Take options for window
-- Configuration
-- Auto compile device os
-- logging
--

-- TODO: Setup mappings like is available in Overseer or Telescope
local function setMappings()
  vim.api.nvim_create_user_command('Particle', function()
    vim.cmd('lua require("particle").project()')
  end, {
      desc = 'Opens the Particle project menu',
    })
end

function M.setup(user_config)
  if initialized == 0 then
    initialized = 1
    config.setup(user_config)
    setMappings()
    Utils.ensure_directory(Constants.DataDir)
    Utils.ensure_directory(Constants.OSCCJsonDir)
    Utils.ensure_directory(Constants.ManifestDir)

    local err = Manifest.setup()
    if err ~= nil then
      log:error("Failed to load manifest, err=%s", err)
    end

    local project_root = particle_utils.LoadSettings()
    if project_root ~= nil then
      project_root = vim.fs.dirname(project_root)
    else
      project_root = particle_utils.find_project_root()
      log:info("No settings found for project %s", project_root)
      return
    end

    Commands.setup()
    -- local a = 1
    -- while a ~= 5000000000 do
    --   a = a + 1
    -- end
    --   -- Your startup code here
    --   print("Plugin startup complete.")
    -- end, 10000)  -- 5 seconds delay

    -- initialized = 2
    -- print("init complete")
  end
end

function M.project()
  M.setup()
  ui.CreateMainMenu()
end

log:info("Hello from particle.nvim")

return M
