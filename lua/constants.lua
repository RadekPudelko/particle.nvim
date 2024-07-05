local M = {}

M.DeviceOSDirectory = vim.fn.expand("~/.particle/toolchains/deviceOS")
M.CompilerDirectory = vim.fn.expand("~/.particle/toolchains/gcc-arm")
M.BuildScriptsDirectory = vim.fn.expand("~/.particle/toolchains/buildscripts")

M.SettingsFile = ".particle.nvim.json"
M.PropertiesFile = "project.properties"

return M
