#!/usr/bin/env bash
set -e

user_home="$(cd ~ && pwd)"
zshrc_file="${user_home}/.zshrc"

all_yes=false
if [[ "$1" = "-y" ]]
then
  all_yes=true
fi


user_confirms () {
  text=$1

  answer=""

  if ${all_yes}
  then
    answer="y"
  fi

  while [[ "$answer" != "y" ]] && [[ "$answer" != "n" ]]
  do
    read -r -p "${text} (y/n): " -n 1 answer
    echo
  done

  [[ "$answer" == "y" ]]
}

brew_installed () {
  formula="$1"

  brew list | grep -q -E "^${formula}$"
}

brew_cask_installed () {
  formula="$1"

  brew cask list | grep -q -E "^${formula}$"
}

brew_current_version () {
  formula="$1"

  # handle brew and brew cask
  # cask: redirection error output and filter error message header
  version="$(
    brew info "$formula" 2>&1 \
     | grep -e '/Cellar/' \
            -e '/Caskroom/' \
     | sed -E -e 's#.*/([^ ]+).*#\1#'
  )"

  echo "$version"
}

brew_latest_version () {
  formula="$1"

  # revision info is not available at the non-json output
  # and current version / version folder uses it as suffix for >0 cases
  #
  # revision == 0: {versions.stable}
  # revision  > 0: {versions.stable}_{revision}
  brew info --json "$formula" \
    | jq --raw-output '"\(.[0].versions.stable)\(.[0].revision | if . <= 0 then "" else "_\(.)" end)"'
}

is_outdated_brew () {
  formula="$1"

  # requires jq
  if ! brew_installed 'jq'
  then
    return # maybe. Not really expected though
  fi

  current="$(brew_current_version "$formula")"
  latest="$(brew_latest_version "$formula")"

  [[ "$current" != "$latest" ]]
}

is_outdated_brew_cask () {
  formula="$1"

  # --greedy: includes casks with version "latest" and "auto-update: true"
  # --quiet : suppress version information; only show the formula
  brew cask outdated --greedy --quiet | grep -q -E -e "^${formula}$"
}

with_brew () {
  formula="$1"
  force_upgrade=true
  force_install=true
  display_name=""

  ## parse arguments
  # arg 2
  if [[ "$2" = "false" ]]
  then
    force_upgrade=false

  elif [[ "$2" != "true" ]]
  then
    display_name="$2"
  fi
  # arg 3
  if [[ -z "$display_name" ]] && [[ "$3" = "false" ]]
  then
    force_install=false

  elif [[ -z "$display_name" ]] && [[ "$3" != "true" ]]
  then
    display_name="$3"
  fi
  # arg 4
  if [[ -z "$display_name" ]] && [[ -n "$4" ]]
  then
    display_name="$4"
  else
    display_name="$formula"
  fi

  ## execute install/upgrade
  if ! brew_installed "$formula"
  then # not installed, yet
    if ${force_install} || user_confirms "Install $display_name?"
    then
      brew install "$formula"
      echo "installed $formula"
    fi
  elif is_outdated_brew "$formula"
  then # already installed, but not latest. Upgrade?
    if ${force_upgrade} || user_confirms "Upgrade $display_name?"
    then
      brew upgrade "$formula" && echo "upgraded $formula" || echo "not upgraded"
    fi
  fi
}

with_brew_cask () {
  formula="$1"
  force_upgrade=true
  force_install=true
  display_name=""

  ## parse arguments
  # arg 2
  if [[ "$2" = "false" ]]
  then
    force_upgrade=false

  elif [[ "$2" != "true" ]]
  then
    display_name="$2"
  fi
  # arg 3
  if [[ -z "$display_name" ]] && [[ "$3" = "false" ]]
  then
    force_install=false

  elif [[ -z "$display_name" ]] && [[ "$3" != "true" ]]
  then
    display_name="$3"
  fi
  # arg 4
  if [[ -z "$display_name" ]] && [[ -n "$4" ]]
  then
    display_name="$4"
  else
    display_name="$formula"
  fi

  ## execute install/upgrade
  if ! brew_cask_installed "$formula"
  then # not installed, yet
    if ${force_install} || user_confirms "Install $display_name?"
    then
      # option "--force" will overwrite manual installed versions
      brew cask install --force "$formula"
      echo "installed $formula"
    fi
  elif is_outdated_brew_cask "$formula"
  then # already installed, but not latest. Upgrade?
    if ${force_upgrade} || user_confirms "Upgrade $display_name?"
    then
      brew cask upgrade "$formula" && echo "upgraded $formula" || echo "not upgraded"
    fi
  fi
}

mas_install () {
  app=$1

  app_id="$(mas search "$app" | grep -E -e "\s+\d+\s+${app}" | sed -E -e "s/[^0-9]*([0-9]+).*/\1/g")"
  if [[ -z "${app_id}" ]]
  then
    echo "did not find \"${app}\" at the Mac App Store -- skipped"
    return
  fi
  
  if mas list | grep -q -E "^${app_id} "
  then
    return
  fi
  
  if ! user_confirms "install ${app}?"
  then
    return
  fi
  
  while ! mas install "${app_id}"
  do
    read -rs \
         -p "Please login manually at the Mac App Store. Press any key to continue." \
         -n 1
    echo
  done
  echo "installed the latest version of ${app}"
}


# 1. install xcode Command Line Tools (CLT)
if xcode-select -p 2> /dev/null 
then
  echo "Xcode Command Line Tools (CLT) already installed"
else
  echo "Xcode Command Line Tools (CLT) not installed, yet"
  xcode-select --install
  while ! xcode-select -p 2>&1 /dev/null
  do
    read -rs \
         -p "Please complete the Xcode Command Line Tools installation. Press any key to continue." \
         -n 1
    echo
  done
  echo "installed Xcode Command Line Tools (CLT)"
fi

# 2. install "Oh My Zsh" - https://ohmyz.sh
# shellcheck disable=SC2230
if ! which -s zsh || [[ ! -d "${user_home}/.oh-my-zsh" ]]
then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
  echo "installed oh-my-zsh"
fi 
# change the default shell to zsh
current_shell="$(finger "${USER}" | grep Shell | sed -E -e 's/.*Shell: (.*)/\1/g')"
if [[ "${current_shell}" != "/bin/zsh" ]]
then
  chsh -s /bin/zsh
  echo "changed default shell to zsh"
fi

# 3. install package managers
# 3.1. install "Homebrew" (general Mac OS package manager)
# shellcheck disable=SC2230
if which -s brew
then
  brew update
else
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  echo "installed Homebrew with commands: 'brew' and 'brew cask'"
fi
with_brew 'jq'

# 3.2. install "mas" Mac App Store CLI
with_brew 'mas' false 'MAS (Mac App Store CLI)'
mas upgrade

# 3.3. install python and "pip" (python package manager), conda
# 3.3.1. (mini)conda (with own python and pip)
with_brew_cask 'miniconda' false false
conda init "$(basename "${SHELL}")"
# 3.3.2. latest python
with_brew 'python' false
## make unversioned commands point to the latest
# shellcheck disable=SC2016
zshrc_append='export PATH="/usr/local/opt/python/libexec/bin:${PATH}"'
# shellcheck disable=SC2143
if ! grep "${zshrc_append}" "${zshrc_file}"
then
  echo "${zshrc_append}" >> "${zshrc_file}"
fi
export PATH="/usr/local/opt/python/libexec/bin:${PATH}"

# 3.4. install "SDKMAN!" (SDK manager for SDKs like Java, Groovy, Kotlin, Maven, Gradle, ...)
if ! zsh -i -c 'which sdk &> /dev/null' || [[ ! -d "${user_home}/.sdkman" ]]
then
  curl -s "https://get.sdkman.io" | bash
  echo "installed SDKMAN!"
else
  zsh -i -c 'sdk update'
fi

# 4. install CLI tools
with_brew 'bfg'
with_brew 'cheat' true false
with_brew 'coreutils' false
with_brew 'htop'
with_brew 'nmap'
with_brew 'parallel'
with_brew 'sops'
with_brew 'speedtest-cli' false false
with_brew 'tldr' true false
with_brew 'watch'
with_brew 'wifi-password' false false
with_brew 'yq'

# 4.1. custom command "help" (if there is none yet) which runs tldr+cheat
help_command='/usr/local/bin/help'
# shellcheck disable=SC2230
if which tldr > /dev/null && which cheat > /dev/null && ! which help > /dev/null && [ ! -f "${help_command}" ]
then
  cat << "DOC" > "${help_command}"
#!/usr/bin/env bash

tldr ${@}
echo
cheat ${@}
DOC
  chmod +x "${help_command}"
  echo 'meta-command "help {command}" was added using both "tldr" and "cheat"'
fi


# 5. infrastructure tools
# 5.1. install fabric  TODO: drop?
if user_confirms "Install fabric?"
then
  pip install fabric --upgrade
  echo "installed fabric"
fi

# 5.2. install terraform
with_brew 'terraform' false false

# 5.3. install awscli
if user_confirms "install AWS CLI?"
then
  pip install awscli --upgrade
  echo "installed AWS CLI"
fi

# 5.4. install container service
with_brew_cask 'docker' false
with_brew 'container-diff'

# 5.5. install kubernetes-related tools
rm -f /usr/local/bin/kubectl
with_brew 'kubernetes-cli' false
with_brew 'kubernetes-helm' false false
with_brew_cask 'minikube' false false

# 6. install SDKs
zsh -i -c 'sdk install java $(sdk list java | grep zulu | head -n 1 | cut -d "|" -f 6 | sed -E -e "s#[^0-9]*(.*zulu).*#\1#g")'
zsh -i -c 'sdk install groovy'
zsh -i -c 'sdk install kotlin'
zsh -i -c 'sdk install maven'
zsh -i -c 'sdk install gradle'
echo "installed the latest SDKs for: Java, Groovy, Kotlin, Maven, Gradle"

# 7. install basic software
with_brew_cask 'tunnelblick' false false 'Tunnelblick (OpenVPN)'

# 8. install communication software
with_brew_cask 'skype' false false 'Skype'  # TODO: drop?
mas_install 'Slack'

# 9. install developer software
# 9.1. Terminal alternatives
with_brew_cask 'iterm2' false false 'iTerm2'

# 9.2. DB
with_brew_cask 'pgadmin4' false 'pgAdmin4'

# 9.3. IDEs etc.
with_brew_cask 'jetbrains-toolbox' false 'Jetbrains Toolbox'
with_brew_cask 'intellij-idea' false 'IntelliJ IDEA'
with_brew_cask 'visual-studio-code' false false 'VS Code'

# 9.4. APIs
with_brew_cask 'insomnia' false false 'Insomnia'
with_brew_cask 'postman' false false 'Postman'

# 10. browsers
with_brew_cask 'firefox' false false 'Firefox'
with_brew_cask 'google-chrome' false false 'Google Chrome'

# 11. Akamai CLI
with_brew 'akamai' false false 'Akamai CLI'

# 12. Airtame
with_brew_cask 'airtame' false false 'Airtame'

# 13. Cyberduck
with_brew_cask 'cyberduck' false false 'Cyberduck'

# 14. Balsamiq Mockup
with_brew_cask 'balsamiq-mockups' false false 'Balamiq Mockups'

# 15. Camunda Modeler
with_brew_cask 'camunda-modeler' false false 'Camunda Modeler'

# 16. Zeebe Modeler
with_brew_cask 'zeebe-modeler' false false 'Zeebe Modeler'

# 17. Dropbox
with_brew_cask 'dropbox' false false 'Dropbox'

# 18. Amphetamine
mas_install 'Amphetamine'

# 19. Window Management
with_brew_cask 'spectacle' false false 'Spectacle'

# 20. Music
with_brew_cask 'spotify' false false 'Spotify'

# 21. Oh My Zsh - Plugins
zsh_plugins="\
aws colored-man-pages command-not-found docker docker-compose git gradle helm history-substring-search \
iterm2 kubectl man minikube mvn"
sed -i "" \
    -E \
    -e "s#^plugins=\(.*\)#plugins=(${zsh_plugins})#" \
    ~/.zshrc


echo "finished with the machine setup"


# run zsh
zsh
