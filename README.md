
# particle.nvim

The unofficial Neovim plugin for Particle IO firmware development.

The purpose of Particle.nvim is to provide near plug-n-play functionality in Neovim for developing
Particle IO devices in the same way that Particle's Workbench extension does for VSCode.

The biggest challenge to firmware development on Particle device in Neovim for me was the LSP setp
for jump to definitions, hints and autocomplete. Coming from VSCode, which has an official
extension made by Particle, this stuff is all taken care of, so it was not obvious at first
how to set this up in Neovim.

Eventually, after learning about LSPs, clangd and bear, I was able to get better LSP functionality than what
was available via Intellisense in VSCode. My setup provides hints that bring the user to exact location of whatever
code I was looking at, regardless of if its in the application or device os.

Clangd is the main LSP for cpp development on Neovim, information about a project can be supplied via
compile_commands.json files, which contain compliation information about each file in the project.
Particle workbench in VSCode does something simillar by feeding Intellisense with a static compile_flags.txt.
This does not provide nearly as much detail to the clangd as a compile_flags.json would, as it is a static file
that does not capture all the detailthat comes with compiling the device os and user application, leading to slow
and inaccurate LSP hits and autocompletion.

Bear is a program used to create compile_commands.json files. It works by intercepting compile commands via
a wrapper. Originally, I used a custom Makefile to wrap all of the Particle compile and flash commands with bear.
Now, Particle.nvim integrates these commands into Neovim with the help of Overseer.nvim, which provides
a ui interface for running commands and seeing the output.


## Features

- Project configuration (selection of device os, platform, compiler and buildscript),
- Bear Integrated Particle Compile, Flash and Clean commands

Particle.nvim optionally supports dressing.nvim, which provides a nicer ui experience in Neovim.

Downloading new device os is currently not supported, so use Particle Workbench for that for now...

## Implemntation Notes

### Project Configuration

Project configuration is stored locally per project in a .particle.nvim.json file. This file is configured via the `:Particle` user command.

![Project Configuration](/pictures/project_configuration.png)

I tried to make the behavior of Particle.nvim as close as possible to Particle Workbench. To do this, Particle.nvim relies
on a file called `manifest.json`, which contains information about all of the available device oses available, valid platforms
and more. This file is available only as a part of the Particle Workbench. To keep an upto date version of this file,
Particle.nvim will check on startup if there is a new version of Particle Workbench and download/extract the new manifest
file.

New project configuration will look into where your Particle Workbench stores the `device os`, `compilers` and `buildscripts` and will use the first of each
for the default configuration, so these must already be installed to use Particle.nvim.

### Compile Commands JSON

Particle projects are usually split into the `device os` and `user application` components. Because of this there are 2
`compile_commands.json` files per project. The user portion is stored with the project, while the device os portion
is stored in the vim data path for Particle.nvim (~/.local/share/nvim/particle).

When browsing the user code, Particle.nvim can supply the user compile_commands.json to clangd. When you jump into the
device os portion or browse device os code, Particle.nvim can supply the compile_commands.json for the device os. Note,
this is done via LSP configuration in the user's config for clangd using the `compile-commands-dir` argument, which will be demonstrated below.

### Commands Available

Particle commands are provided via `Overseer.nvim` after a particle project configuration is created. The way these commands work
in Particle Workbench is to call the buildscript with the parameters for the project (device os, platform, application directory).
Particle.nvim takes the same approach, but makes a few changes to the commands so that compile_commands.json files can be created.

![Commands via Overseer](/pictures/commands.png)

- Compile User - Compile user application, wrapped with bear
- Flash User - Flash user application, wrapped with bear
- Clean User - Clean user application, deletes local compile_commands.json
- Compile OS - Compile device os, wrapped with bear, typically only done once per platform to create the compile_commands.json for the device os
- Clean OS - Cleans the device os, deletes the device os compile_commands.json
- Compile All - Compiles the device os and user application, wrapped with bear
- Flash All - Flashes the device os and user application, wrapped with bear
- Clean All - Cleans the device os and user application, deleting the device os and user compile_commands.json files.

These commands are available via `:OverseerRun` for projects setup via Particle.nvim.

The user commands will run the buildscript directly, while the OS commands were created based on what the buildscript does
when it compiles the device os portion (calls an internal makefile in the deivce os modules folder). The reason for this
extra command is so that compile_commands.json can be created for the device os to provide LSP services when browsing
device os code.

The all commands are a combination of the OS and user commands.

The command history, status and output can be seen via `:OverseerToggle`.

Additionally, notifications of when commands complete are available via Overseer's tie in with the `nvim-notify` plugin.

![Overseer Task View](/pictures/overseer.png)


### Typical workflow

1. Create a Particle project via the Particle cli or enters an existing project.
2. Enter the project with Neovim and launch the project configuration menu (:Particle)
3. Create the config for the project.
4. Clean and compile the device os, if it has not been done before.
5. Clean and compile the user application.
6. Run flash all once to load both the device os and user application.
7. Edit code, compile and flash user from here on out.

# Installation

## Neovim

Install with your plugin manager

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
          level = vim.log.levels.DEBUG,
        }
      }
    })
  end
```

Configuration is currently limited to setting the logging level.

## Clangd

I recommend installing clangd via `mason.nvim`.

## Bear

`Bear` is available on github and on most system package managers. At the time of this writing,
bear does not automatically provide the compiler wrappers necessary to intercept commands
for `arm-none-eabi` compilers. These wrappers are really just symbolic links to bear's wrapper
binary, so all we have to do to make bear work with the arm compiler is to make a few copies of
the links and rename them.

On my mac, this involves navigating to /opt/homebrew/Cellar/bear/3.1.3_17/lib/bear/wrapper.d and copying
1 of the links 4 times, renaming the copies to `arm-none-eabi-cpp`, `arm-none-eabi-g++,` `arm-none-eabi-gcc`,
and `arm-none-eabi-ld`. It doesn't matter which link you copy, as they all point to the same wrapper. This
allows bear to intercept the compile commands and create the compile_commands.json files.

Here's what my wrapper.d folder looks like for my bear install after I added the 4 links from above.

![Bear wrappers](/pictures/bear_wrappers.png)

## LSP Integration

Particle.nvim handles the compile_commands.json creation and needs to be integrated with your
LSP config to launch clangd with the propper commands in Particle projects. This is the most
difficult part of installation as it will vary from user to user depending on how their LSP
is configured. My configuration can be found in my repo called `init.lua`
in file https://github.com/RadekPudelko/init.lua/blob/master/lua/me/lazy/lsp.lua.

This configuration step is important to launch clangd with enough information to use the correct
compiler as the query driver and to use the correct compile_commands.json file for Particle projects.

Note that my configuration supplies all the releveant information for Particle projects, you may have
additional configuration for non-Particle cpp projects.

<details>
<summary>My Clangd Config using lspconfig</summary>

```lua
["clangd"] = function()
  local lspconfig = require("lspconfig")
  local particle = require("particle")
  particle.setup()

  lspconfig.clangd.setup({
    -- Base clangd command
    on_new_config = function(new_config, new_root_dir)
      local command = {
        "clangd",
        "--background-index",
        "--function-arg-placeholders=1",
        "--header-insertion=never",
        "--all-scopes-completion=1",
        -- "--completion-style=detailed",
      }
      -- Determine if the current buffer belongs to a Particle project
      -- Add the query driver and compile commands directory to the clangd command
      local type, root = particle.get_project_type(vim.api.nvim_buf_get_name(0))
      if type ~= nil then
        local query_driver = particle.get_query_driver()
        if query_driver ~= nil then
          table.insert(command, "--query-driver=" .. query_driver)
        else
          table.insert(command,"--query-driver=/Users/radek/.particle/toolchains/gcc-arm/10.2.1/bin/arm-none-eabi-gcc")
        end
        if type == particle.PROJECT_DEVICE_OS then
          local cc_dir = particle.get_device_os_ccjson_dir()
          table.insert(command, "--compile-commands-dir=" .. cc_dir)
        else
        end
      end
      new_config.cmd = command
    end,

    -- fname is full path of the buffer
    root_dir = function(fname)
    -- Check if Particle project and get its root
      local type, root = particle.get_project_type(fname)
      if type ~= nil then
        if root ~= nil then
          return root
        end
      end
      -- Not a Particle project, look for other indicators indicating the project root
      root = vim.fs.root(0, {'Makefile', '.git', 'compile_commands.json'})
      return root
    end,
    filetypes = { "c", "cpp", "ino"},
    on_attach = function(client, bufnr)
      vim.keymap.set("n", "<leader>c", [[:ClangdSwitchSourceHeader<CR>]], {buffer=bufnr})
    end,
  })
end
```
</details>


## Other Requirements

curl utility

Particle.nvim has been developed on a mac, I expect it should work on Linux, but
it is not setup to work on Windows, except maybe if you are using WSL.


# Additional Info

https://github.com/rizsotto/Bear

https://clangd.llvm.org/design/compile-commands

https://github.com/RadekPudelko/ParticleMakefile

https://github.com/stevearc/overseer.nvim

https://github.com/stevearc/dressing.nvim

https://github.com/rcarriga/nvim-notify?tab=readme-ov-file#viewing-history

https://github.com/RadekPudelko/init.lua

