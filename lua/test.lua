local Menu = require("nui.menu")
local utils = require "utils"
local Manifest = require("manifest")

local ProjectSettingsFile = ".particle.nvim.json"
local DeviceOSDirectory = vim.fn.expand("~/.particle/toolchains/deviceOS")

local settings = nil

local function getInstalledDeviceOS(path)
  local osList = {}

  local handle = vim.loop.fs_scandir(path)
  if not handle then
    print("Failed to scan directory: " .. path)
    return osList
  end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then break end
    -- TODO: add another check to confirm its a device osList
    if type == "directory" and utils.isSemanticVersion(name) then
      table.insert(osList, name)
    end
  end
  -- TODO: sort by latest

  return osList
end

local function defaultProjectSettings()
  local settings = {
    ["device_os"] = "6.1.0",
    ["platform"] = "bsom"
  }
  return settings
end

local function loadProjectJson()
  local path = utils.findFile(ProjectSettingsFile)
  if not path then
    return nil, ProjectSettingsFile .. " not found"
  end

  local file = io.open(path, "r")
  if not file then
    return nil, "Unable to read " .. ProjectSettingsFile
  end

  local contents = file:read("*a")
  file:close()
  -- TODO: Set up some sort of test or checks here to make sure the file format is as
  -- we expect it to be
  local json = vim.json.decode(contents)
  return json, nil
end

local function saveProjectJson(settings)
  local json = vim.json.encode(settings)
  vim.fn.writefile({json}, ProjectSettingsFile)
end

local function isParticleProject()
  local path = utils.findFile("project.properties")
  return path ~= nil
end

local function checkForConfig()
  local path = utils.findFile(ProjectSettingsFile)
  return path ~= nil
end

local function getMaxKeyLen(dict)
  local max = 0
  for key, _ in pairs(dict) do
    if #key > max then
      max = #key
    end
  end
  return max
end

function CreateDeviceOSMenu()
  local lines = {}
  local installedOSList = getInstalledDeviceOS(DeviceOSDirectory)
  for _, os in ipairs(installedOSList) do
    table.insert(lines, Menu.item(os))
  end

  local menu = Menu({
    position = "50%",
    size = {
      width = 25,
      height = 5,
    },
    border = {
      style = "single",
      text = {
        top = "Particle.nvim - Device OS",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Normal",
    },
  }, {
      lines = lines,
      max_width = 20,
      keymap = {
        focus_next = { "j", "<Down>", "<Tab>" },
        focus_prev = { "k", "<Up>", "<S-Tab>" },
        close = { "q", "<Esc>", "<C-c>" },
        submit = { "<CR>", "<Space>" },
      },
      on_close = function()
        print("Menu Closed!")
        CreateMainMenu()
      end,
      on_submit = function(item)
        print("Device OS Submitted: ", item.text)
        settings["device_os"] = item.text
        saveProjectJson(settings)
        LoadSettings()
        CreateMainMenu()
      end,
    })
  menu:mount()
end

-- TODO: how to handle which device os to show and which platforms to show
-- Not all device oses are valid for a selected platform and vice versa,
---- Open up platform menu to get selection
function CreatePlatformMenu()
  -- Get the valid list of platforms for the current device os
  -- Search manifest["toolchains"] loop platforms where firmware == deviceOS@X.X.X
  -- Convert platforms from numbers to names
  -- Order us giidm vut consider replacing platform names with display neames as used in vscode

  local toolchain = Manifest.getToolchain(settings["device_os"])
  if toolchain == nil then
    print("Failed to find toolchain info for device os " .. settings["device_os"])
    return
  end

  local lines = {}
  local platformMap = Manifest.getPlatforms()
  -- print(platformMap)
  for _, platformId in ipairs(toolchain["platforms"]) do
    -- print("pid " .. platformId .. " " .. platformMap[platformId])
    table.insert(lines, Menu.item(platformMap[platformId]))
  end


  -- local lines = {Menu.item("bsom"), Menu.item("msom")}
  -- local installedOSList = getInstalledDeviceOS(DeviceOSDirectory)
  -- for _, osList in ipairs(installedOSList) do
  --   table.insert(lines, Menu.item(osList))
  -- end

  local menu = Menu({
    position = "50%",
    size = {
      width = 25,
      height = 5,
    },
    border = {
      style = "single",
      text = {
        top = "Particle.nvim - Platform",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Normal",
    },
  }, {
      lines = lines,
      max_width = 20,
      keymap = {
        focus_next = { "j", "<Down>", "<Tab>" },
        focus_prev = { "k", "<Up>", "<S-Tab>" },
        close = { "q", "<Esc>", "<C-c>" },
        submit = { "<CR>", "<Space>" },
      },
      on_close = function()
        print("Menu Closed!")
        CreateMainMenu()
      end,
      on_submit = function(item)
        print("Platform Submitted: ", item.text)
        settings["platform"] = item.text
        saveProjectJson(settings)
        LoadSettings()
        CreateMainMenu()
      end,
    })
  menu:mount()
end

function CreateMainMenu()
  local lines = {}
  if settings == nil then
    lines = {Menu.item("Create config")}
  else
    lines = {
      Menu.item("Device OS: " .. settings["device_os"]),
      Menu.item("Platform: " .. settings["platform"])
    }
  end

  local menu = Menu({
    position = "50%",
    size = {
      width = 25,
      height = 5,
    },
    border = {
      style = "single",
      text = {
        top = "Particle.nvim",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Normal",
    }},
    {
      lines = lines,
      max_width = 20,
      keymap = {
        focus_next = { "j", "<Down>", "<Tab>" },
        focus_prev = { "k", "<Up>", "<S-Tab>" },
        close = { "q", "<Esc>", "<C-c>" },
        submit = { "<CR>", "<Space>" },
        -- submit = { },
      },
      on_close = function()
        print("Menu Closed!")
      end,
      on_submit = function(item)
        if item.text == "Create config" then
          saveProjectJson(defaultProjectSettings())
          LoadSettings()
          CreateMainMenu()
        elseif string.find(item.text, "Device OS:") then
          print("Menu Submitted: ", item.text)
          CreateDeviceOSMenu()
        else
          print("Menu Submitted: ", item.text)
          CreatePlatformMenu()
        end
      end,
    })

  menu:mount()
end

function LoadSettings()
  settings = nil
  local err
  if checkForConfig() then
    -- TODO: Validate all settings json fields are present/valid
    settings, err = loadProjectJson()
    if err ~= nil then
      print(err)
    end
  end
end

-- local configExists = checkForConfig()
Manifest.setup()
LoadSettings()
CreateMainMenu()
-- mount the component
