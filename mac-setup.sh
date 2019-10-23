#!/bin/bash
set -e

user_home="$(cd ~ && pwd)"
zshrc_file="${user_home}/.zshrc"

all_yes=false
if [[ "$1" = "-y" ]]
then
  all_yes=true
fi


function user_confirms() {
  text=$1

  answer=""

  if ${all_yes}
  then
    answer="y"
  fi

  while [[ "$answer" != "y" ]] && [[ "$answer" != "n" ]]
  do
    echo -n "${text} (y/n): "
    read answer
  done

  if [[ "$answer" == "y" ]]
  then
    true
  else
    false
  fi
}

function brew_installed() {
  formula="$1"

  if [[ -n "$(brew list | grep -E "^${formula}$")" ]]
  then
    true
  else
    false
  fi
}

function brew_cask_installed() {
  formula="$1"

  if [[ -n "$(brew cask list | grep -E "^${formula}$")" ]]
  then
    true
  else
    false
  fi
}

function brew_current_version() {
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

function brew_latest_version() {
  formula="$1"

  # revision info is not available at the non-json output
  # and current version / version folder uses it as suffix for >0 cases
  #
  # revision == 0: {versions.stable}
  # revision  > 0: {versions.stable}_{revision}
  brew info --json "$formula" \
    | jq --raw-output '"\(.[0].versions.stable)\(.[0].revision | if . <= 0 then "" else "_\(.)" end)"'
}

function is_outdated_brew() {
  formula="$1"

  # requires jq
  if ! brew_installed 'jq'
  then
    true # maybe. Not really expected though
  else
      current="$(brew_current_version "$formula")"
      latest="$(brew_latest_version "$formula")"

      if [[ "$current" != "$latest" ]]
      then
        true
      else
        false
      fi
  fi
}

function is_outdated_brew_cask() {
  formula="$1"

  # --greedy: includes casks with version "latest" and "auto-update: true"
  # --quiet : suppress version information; only show the formula
  if [[ -n "$(brew cask outdated --greedy --quiet | grep -E -e "^${formula}$")" ]]
  then
    true
  else
    false
  fi
}

function with_brew() {
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

function with_brew_cask() {
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

function mas_install() {
  app=$1

  app_id="$(mas search "$app" | grep -E -e "\s+\d+\s+${app}" | sed -E -e "s/[^0-9]*([0-9]+).*/\1/g")"
  if [[ -z "${app_id}" ]]
  then
    echo 'did not find "${app}" at the Mac App Store -- skipped'
    return
  fi
  
  if [[ -n "$(mas list | grep -E "^${app_id} ")" ]]
  then
    return
  fi
  
  if ! user_confirms "install ${app}?"
  then
    return
  fi
  
  while ! mas install "${app_id}"
  do
    echo -n "Please login manually at the Mac App Store. Press ENTER to continue."
    read any_key
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
  while ! xcode-select -p 2>1 /dev/null
  do
    echo -n "Please complete the Xcode Command Line Tools installation. Press ENTER to continue."
    read any_key
  done
  echo "installed Xcode Command Line Tools (CLT)"
fi

# 2. install "Oh My Zsh" - https://ohmyz.sh
if ! which -s zsh || [[ ! -d "${user_home}/.oh-my-zsh" ]]
then
  sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh) --unattended"
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
zshrc_append='export PATH="/usr/local/opt/python/libexec/bin:${PATH}"'
if [ -z "$(grep "${zshrc_append}" "${zshrc_file}")" ]
then
  echo "${zshrc_append}" >> "${zshrc_file}"
fi
export PATH="/usr/local/opt/python/libexec/bin:${PATH}"

# 3.4. install "SDKMAN!" (SDK manager for SDKs like Java, Groovy, Kotlin, Maven, Gradle, ...)
if ! zsh -i -c 'which sdk &> /dev/null' || [[ ! -d "${user_home}/.sdkman" ]]
then
  curl -s "https://get.sdkman.io" | bash
  echo "installed SDKMAN!"
fi

# 4. install CLI tools
with_brew 'coreutils' false
with_brew 'htop'
with_brew 'nmap'
with_brew 'parallel'
with_brew 'tldr'
with_brew 'watch'
with_brew 'wifi-password' false false
with_brew 'speedtest-cli' false false

# 5. infrastructure tools
# 5.1. install fabric
if user_confirms "Install fabric?"
then
  pip install fabric
  echo "installed fabric"
fi

# 5.2. install terraform
with_brew 'terraform' false false

# 5.3. install awscli
if user_confirms "install AWS CLI?"
then
  pip install awscli --upgrade --user
  echo "installed AWS CLI"
fi

# 5.4. install container service
with_brew_cask 'docker' false

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
with_brew_cask 'skype' false false 'Skype'
with_brew_cask 'skype-for-business' false false 'Skype for Business'
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
