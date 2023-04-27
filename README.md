# mac-setup
automated setup of a Mac with basic software

## Execute / Install
```
$ curl -fsSL https://raw.githubusercontent.com/pjungermann/mac-setup/master/mac-setup.sh -o mac-setup.sh
./mac-setup.sh {options}
```

Options:
* `[-b|--use-branch {branch}]` - Branch from this repository to use when selecting the default Brewfile.
* `[-f|--brewfile {source-brewfile}]` - Source Brewfile. By default, the one in this repository.
* `[-u|--update-brewfile]` - Whether the local Brewfile should be overwritten with the latest state of the source.
* `[--no-global]` - By default, we use the global location ~/.Brewfile as installation destination.
  This option disables this and uses a separate location.
* `[--no-upgrade]` - Applies the same option to the brew command.

## Installed Software
* Xcode Command Line Tools
* [Oh My Zsh](https://ohmyz.sh/) - shell
  * activate some standard plugins (see `plugins` in `~/.zshrc` as well as `~/.oh-my-zsh/plugins/`)
* [Homebrew](https://brew.sh/) - package manager
  * Any software required at the `Brewfile`.
    * Includes: [mas](https://github.com/mas-cli/mas) - CLI for the Mac App Store
* [asdf](https://asdf-vm.com/) - Manage multiple runtime versions with a single CLI tool.
  * plugins (incl. latest version):
    * gradle
    * groovy
    * java _(corretto)_
    * maven
    * nodejs
    * ruby
