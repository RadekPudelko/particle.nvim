# particle.nvim

The unofficial Neovim plugin for Particle IO firmware development.

The purpose of Particle.nvim is to provide near plug-n-play functionality in Neovim for developing
Particle IO devices in the same way that Particle's Workbench extension does for VSCode.

The biggest challenge to firmware development for Particle device in Neovim for me was the LSP setup
ability to jump to propper definitions, hints and autocomplete. Coming from VSCode, which has an official
extension made by Particle, it was not obvious at first how to set all of this up in Neovim.

Eventually, after learning about LSPs, clangd and bear, I was able to get better LSP functionality than what
was available via Particle Workbench in VSCode.

Clangd is the main LSP for cpp development on Neovim, information about a project can be supplied via
compile_commands.json files, which contain compliation information about each file in the project.
Particle workbench in VSCode does something simillar to provide Intellisense functionality by using a static compile_flags.txt,
which does not provide nearly as much detail to the clangd as it is a static file that does not capture all the detail
that comes with compiling the device os and user application, leading to slow and inaccurate LSP
hits and autocompletion.

Originally, I used a custom Makefile to wrap all of the Particle compile and flash commands so that bear could
intercept them. Now, Particle.nvim integrates these commands into Neovim with the help of Overseer.nvim, which provides
a ui interface for running commands and seeing the output.


## Features

- Project configuration (selection of device os, platform, compiler and buildscript),
- Bear Integrated Particle Compile, Flash and Clean commands

Particle.nvim optionally supports dressing.nvim, which provides a nicer ui experience in Neovim.

Downloading new device os is currently not supported, so use Particle Workbench for that for now...


# Installation

## Neovim

Install with your favorite plugin manager

```lua
-- Lazy.nvim
{
  "RadekPudelko/particle.nvim",
  config = function()
    local particle = require("particle")
    particle.setup({
      log = {
        {
          type = "echo",
          level = vim.log.levels.WARN,
        },
        {
          type = "file",
          filename = "particle.log",
          level = vim.log.levels.WARN,
        }
      }
    })
  end
```

Configuration is currently, limited to setting the logging level.

## LSP

There is some configuration required between the LSP and Particle.nvim to launch clangd with the
propper arguments for each Particle project. This is the most difficult part of configuration as
it will vary from user to user depending on how their LSP is configured. My configuration can be
found in a repo called init.lua in https://github.com/RadekPudelko/init.lua/blob/master/lua/me/lazy/lsp.lua.

This configuration step is important to launch clangd with enough information to use the correct
compiler as the query driver and to use the correct compile_commands.json file.

## Bear

Bear is available on github and on most system package managers. At the time of this writing,
bear does not automatically provide the compiler wrappers necessary to intercept commands
for arm-none-eabi compilers. These wrappers are really just symbolic links to bear's wrapper
binary, so all we have to do to make bear work with the arm compiler is to make a few copies of
the links and rename them.

On my mac, this involves navigating to /opt/homebrew/Cellar/bear/3.1.3_17/lib/bear/wrapper.d and copying
1 of the links 4 times, renaming the copies to arm-none-eabi-cpp, arm-none-eabi-g++, arm-none-eabi-gcc,
and arm-none-eabi-ld. It doesn't matter which link you copy, as they all point to the same wrapper. This
allows bear to intercept the compile commands and create the compile_commands.json files.

## Other Requirements

curl utility

This plugin has been developed on a mac, I expect it should work on Linux just fine, but
it is not setup to work on Windows, except maybe if you are using WSL.


# Additional Info

https://github.com/rizsotto/Bear

https://clangd.llvm.org/design/compile-commands

https://github.com/RadekPudelko/ParticleMakefile

https://github.com/stevearc/overseer.nvim

https://github.com/stevearc/dressing.nvim

https://github.com/RadekPudelko/init.lua
