# Sergiy's Dotfiles
A collection of scripts used for OS bootstrap with Dev tools. 
Initial idea and majority of the scripts have been cloned from Jessica Deen [dotfiles](https://github.com/jldeen/dotfiles) project.

## macOS configuration
There are a couple of approaches that you may consider to take with this repo.

### Clone and modify repo (recommended)

Use this approach always. Never run any scripts you downloaded from Internet without understanding what they are going to do with your system.

Run this if you wish to run from clone:

```sh
git clone https://github.com/stsyg/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
script/bootstrap
```
This will symlink the appropriate files in `.dotfiles` to your home directory.
Everything is configured and tweaked within `~/.dotfiles`.

The main file you'll want to change right off the bat is `zsh/zshrc.symlink`, which sets up a few paths that'll be different on your particular machine. You also might want to configure `.tmux.conf` since I run a few scripts in the status bar.

`dot` is a simple script that installs some dependencies, sets sane macOS defaults, and so on. Tweak this script, and occasionally run `dot` from time to time to keep your environment fresh and up-to-date. You can find this script in `bin/`.

### Run configuration from my repo (not recommended)
I would not recommend to use this approach. Not unless you accept all the modifications dotfiles are going to make to your system. Those are my modifications and you may not like them. Just saying.

Run the following to bootstrap macOS from scratch...
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/stsyg/dotfiles/mac/configure.sh)"
```

### Backstory
These are mine dotfiles. You should modify yours to personalize your system.

If you're interested in the philosophy behind why projects like these are awesome, you might want to [read Holman's post on the subject](http://zachholman.com/2010/08/dotfiles-are-meant-to-be-forked/).

I liked Jessica's topic-centric approach she used for her dotfiles, so I used the same in my clone. The main idea is to have dedicated areas for tools I use and need to have configured, e.g. git, system libraries, and so on (check more below). I also followed Jessica's approach by splitting the code to the dedicated OS specific branches, e.g. Windows, Linux and MacOS, since those are my three environments.

## Topics

Here's more explanations about folders (topics) in the repo.

Everything's built around topic areas. If you're adding a new area to your forked dotfiles — say, "Java" — you can simply add a `java` directory and put files in there. Anything with an extension of `.zsh` will get automatically included into your shell. Anything with an extension of `.symlink` will get symlinked without extension into `$HOME` when you run `script/bootstrap`.

## What's inside

A lot of stuff. Check out the original repo I cloned from and see what components you may want to use: [Fork jldeen's](https://github.com/jldeen/dotfiles/fork), remove what you don't use, and build on what you do use.

## Components

There's a few special files in the hierarchy.

- **bin/**: Anything in `bin/` will get added to your `$PATH` and be made available everywhere.
- **Brewfile**: This is a list of applications for [Homebrew Cask](https://caskroom.github.io) to install: things like Chrome and 1Password and Adium and stuff. Might want to edit this file before running any initial setup.
- **topic/\*.zsh**: Any files ending in `.zsh` get loaded into your environment.
- **topic/path.zsh**: Any file named `path.zsh` is loaded first and is expected to setup `$PATH` or similar.
- **topic/completion.zsh**: Any file named `completion.zsh` is loaded last and is expected to setup autocomplete.
- **topic/install.sh**: Any file named `install.sh` is executed when you run `script/install`. To avoid being loaded automatically, its extension is `.sh`, not `.zsh`.
- **topic/\*.symlink**: Any file ending in `*.symlink` gets symlinked into your `$HOME`. This is so you can keep all of those versioned in your dotfiles but still keep those autoloaded files in your home directory. These get symlinked in when you run `script/bootstrap`.

## Bugs

I want this to work for everyone; that means when you clone it down it should work for you even though you may not have `rbenv` installed, for example. That said, I do use this as *my* dotfiles, so there's a good chance I may break something if I forget to make a check for a dependency.

If you're brand-new to the project and run into any blockers, please [open an issue](https://github.com/stsyg/dotfiles/issues) on this repository and I'd love to get it fixed for you!

## Thanks

Thanks to Jessica's excellent project that inspired me to start compiling and using my own dotfiles.
