local Menu = require("nui.menu")
local utils = require("utils")
local Manifest = require("manifest")
local Settings = require("settings")
local Installed = require("installed")
local Commands = require("overseer_commands")
-- local Commands = require("commands")

local settings = nil
local env = nil

local M = {}

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

--TODO: add indicator of selected items in menu
local function CreateMenu(title, lines, on_close, on_submit)
  local items = {}
  for _, item in ipairs(lines) do
    table.insert(items, Menu.item(item))
  end

  local menu = Menu({
    position = "50%",
    size = {
      width = 40,
      height = 10,
    },
    border = {
      style = "single",
      text = {
        top = title,
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Normal",
    },
  }, {
      lines = items,
      max_width = 20,
      keymap = {
        focus_next = { "j", "<Down>", "<Tab>" },
        focus_prev = { "k", "<Up>", "<S-Tab>" },
        close = { "q", "<Esc>", "<C-c>" },
        submit = { "<CR>", "<Space>" },
      },
      on_close = on_close,
      on_submit = on_submit,
    })
  menu:mount()
end

function CreateMainMenu(manifest)
  local lines = {}
  if settings == nil then
    lines = {Menu.item("Create config")}
  else
    lines = {
      Menu.item("Device OS: " .. settings["device_os"]),
      Menu.item("Platform: " .. settings["platform"]),
      Menu.item("Compiler: " .. settings["compiler"]),
      Menu.item("Build Script: " .. settings["scripts"])
    }
  end

  local on_close = function() end

  local on_submit = function(item)
    if item.text == "Create config" then
      Settings.save(Settings.default())
      LoadSettings()
      CreateMainMenu(manifest)
    elseif string.find(item.text, "Device OS:") then
      CreateDeviceOSMenu(manifest)
    elseif string.find(item.text, "Platform:") then
      CreatePlatformMenu(manifest)
    elseif string.find(item.text, "Compiler:") then
      CreateCompilerMenu(manifest)
    else
      CreateBuildScriptMenu(manifest)
    end
  end

  CreateMenu("Particle.nvim", lines, on_close, on_submit)
end

function CreateDeviceOSMenu(manifest)
  local lines = {}
  local list = Installed.getDeviceOSs()
  for _, os in ipairs(list) do
    table.insert(lines, Menu.item(os))
  end

  local on_close = function() CreateMainMenu(manifest) end

  local on_submit = function(item)
    settings["device_os"] = item.text
    Settings.save(settings)
    LoadSettings()
    CreateMainMenu(manifest)
  end

  CreateMenu("Particle.nvim - Device OS", lines, on_close, on_submit)
end

-- TODO: how to handle which device os to show and which platforms to show
-- Not all device oses are valid for a selected platform and vice versa,
---- Open up platform menu to get selection
function CreatePlatformMenu(manifest)
  -- Get the valid list of platforms for the current device os
  -- Search manifest["toolchains"] loop platforms where firmware == deviceOS@X.X.X
  -- Convert platforms from numbers to names
  -- Order us giidm vut consider replacing platform names with display neames as used in vscode

  local toolchain = Manifest.getToolchain(manifest, settings["device_os"])
  if toolchain == nil then
    print("Failed to find toolchain info for device os " .. settings["device_os"])
    return
  end

  local lines = {}
  local platformMap = Manifest.getPlatforms(manifest)
  for _, platformId in ipairs(toolchain["platforms"]) do
    table.insert(lines, Menu.item(platformMap[platformId]))
  end

  local on_close = function() CreateMainMenu(manifest) end

  local on_submit = function(item)
    settings["platform"] = item.text
    Settings.save(settings)
    LoadSettings()
    CreateMainMenu(manifest)
  end

  CreateMenu("Particle.nvim - Platform", lines, on_close, on_submit)
end

function CreateCompilerMenu(manifest)
  local lines = {}
  local list = Installed.getCompilers()
  for _, os in ipairs(list) do
    table.insert(lines, Menu.item(os))
  end

  local on_close = function() CreateMainMenu(manifest) end

  local on_submit = function(item)
    settings["compiler"] = item.text
    Settings.save(settings)
    LoadSettings()
    CreateMainMenu(manifest)
  end

  CreateMenu("Particle.nvim - Compiler", lines, on_close, on_submit)
end

function CreateBuildScriptMenu(manifest)
  local lines = {}
  local list = Installed.getBuildScripts()
  for _, os in ipairs(list) do
    table.insert(lines, Menu.item(os))
  end

  local on_close = function() CreateMainMenu(manifest) end

  local on_submit = function(item)
    settings["scripts"] = item.text
    Settings.save(settings)
    LoadSettings()
    CreateMainMenu(manifest)
  end

  CreateMenu("Particle.nvim - Build Script", lines, on_close, on_submit)
end

function LoadSettings()
  settings = nil
  if Settings.exists() then
    -- TODO: Validate all settings json fields are present/valid
    settings = Settings.load()
    if settings == nil then
      print("Failed to load settings")
    end
  else
    print("Settings dont exist")
  end

  env = nil
  local manifest = Manifest.setup()
  local platformMap = Manifest.getPlatforms(manifest)
  env = Settings.getParticleEnv(platformMap, settings)
  -- utils.printTable(env)
  -- print(envPATH)
end

local function setMappings()
  vim.keymap.set("n", "<leader>t", ":lua require'project'.project()<cr>",
    { nowait=false, noremap=true, silent=true, desc = "Launch Particle.nvim local project configuration" })
end

function M.project()
  setMappings()
  local manifest = Manifest.setup()
  LoadSettings()

  -- local compile_user = Commands.CompileUser(settings, env)
  -- utils.printTable(compile_user)
  -- utils.printTable({unpack(compile_user, 2)})
  CreateMainMenu(manifest)
  Commands.setup(settings, env)
end

return M
