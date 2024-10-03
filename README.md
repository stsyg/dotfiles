# Sergiy's Dotfiles - Linux
A collection of scripts used for OS bootstrap with Dev tools. Initial idea and majority of the scripts have been cloned from Jessica Deen [dotfiles](https://github.com/jldeen/dotfiles) project.

## Linux configuration
There are a couple of approaches that you may consider to take with this repo.

### Clone and modify repo (recommended)

Run this if you wish to run from clone:

```sh
git clone https://github.com/stsyg/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
start.sh
```
### Run configuration from my repo (not recommended)
I would not recommend to use this approach. Not unless you accept all the modifications dotfiles are going to make to your system. Those are my modifications and you may not like them. Just saying.

Run the following to bootstrap Linux from scratch...
```
bash -c "$(wget -O- https://raw.githubusercontent.com/stsyg/dotfiles/linux/start.sh)"
```
