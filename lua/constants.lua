local M = {}

M.DeviceOSDirectory = vim.fn.expand("~/.particle/toolchains/deviceOS")
M.CompilerDirectory = vim.fn.expand("~/.particle/toolchains/gcc-arm")
M.BuildScriptsDirectory = vim.fn.expand("~/.particle/toolchains/buildscripts")

M.SettingsFile = ".particle.nvim.json"
M.PropertiesFile = "project.properties"

M.DataDir = vim.fn.stdpath('data') .. "/particle"
M.OSCCJsonDir = M.DataDir .. "/cc/os"
M.ManifestDir = M.DataDir .. "/manifset"
M.ManifestFile = M.ManifestDir .. "/manifest.json"
M.ManifestVersionFile = M.ManifestDir .. "/manifest_version.txt"
M.WorkbenchDownloadFile = M.ManifestDir .. "/particle.tar.gz"
M.WorkbenchExtractDir= M.ManifestDir .. "/particle_extracted"

M.VSCodeExtensionDir = vim.fn.expand("~/.vscode/extensions")

return M
