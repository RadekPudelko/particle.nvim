local M = {}

M.DeviceOSDirectory = vim.fn.expand("~/.particle/toolchains/deviceOS")
M.CompilerDirectory = vim.fn.expand("~/.particle/toolchains/gcc-arm")
M.BuildScriptsDirectory = vim.fn.expand("~/.particle/toolchains/buildscripts")

M.SettingsFile = ".particle.nvim.json"
M.PropertiesFile = "project.properties"

M.DataDir = vim.fn.stdpath('data') .. "/particle"
M.OSCCJsonDir = M.DataDir .. "/cc/os"

M.VSCodeExtensionDir = vim.fn.expand("~/.vscode/extensions")

return M
