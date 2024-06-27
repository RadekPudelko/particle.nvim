local Menu = require("nui.menu")
local utils = require "utils"
local Manifest = require("manifest")
local Settings = require("settings")
local Installed = require("installed")

local settings = nil

--TODO: add indicator of selected items in menu

function CreateCompilerMenu()
  local lines = {}

  local list = Installed.getCompilers()
  for _, os in ipairs(list) do
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
        top = "Particle.nvim - Compiler",
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
        CreateMainMenu()
      end,
      on_submit = function(item)
        settings["compiler"] = item.text
        Settings.save(settings)
        LoadSettings()
        CreateMainMenu()
      end,
    })
  menu:mount()
end

function CreateDeviceOSMenu()
  local lines = {}
  local list = Installed.getAllDeviceOS()
  for _, os in ipairs(list) do
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
        Settings.save(settings)
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
  for _, platformId in ipairs(toolchain["platforms"]) do
    table.insert(lines, Menu.item(platformMap[platformId]))
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
        Settings.save(settings)
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
      Menu.item("Platform: " .. settings["platform"]),
      Menu.item("Compiler: " .. settings["compiler"])
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
      end,
      on_submit = function(item)
        if item.text == "Create config" then
          Settings.save(Settings.default())
          LoadSettings()
          CreateMainMenu()
        elseif string.find(item.text, "Device OS:") then
          CreateDeviceOSMenu()
        elseif string.find(item.text, "Platform:") then
          CreatePlatformMenu()
        else
          CreateCompilerMenu()
        end
      end,
    })

  menu:mount()
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
end

-- local configExists = Settings.exists()
Manifest.setup()
LoadSettings()
CreateMainMenu()
-- mount the component
