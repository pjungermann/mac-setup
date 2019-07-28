#!/bin/bash
set -e

user_home="$(cd ~ && pwd)"


function user_confirms() {
  text=$1

  answer=""

  while [ "$answer" != "y" ] && [ "$answer" != "n" ]
  do
    echo -n "${text} (y/n): "
    read answer
  done

  if [ "$answer" == "y" ]
  then
    true
  else
    false
  fi
}

function brew_install_or_upgrade() {
  formulae=$1
  prompt_upgrade=$2
  prompt_install=$3
  
  if [ -z "$(brew list | grep "$formulae")" ]
  then
    if [ -z "$prompt_install" ] || user_confirms "$prompt_install"
    then
      brew install "$formulae"
      echo "installed $formulae"
    fi
  else
    if [ -z "$prompt_upgrade" ] || user_confirms "$prompt_upgrade"
    then
      brew upgrade "$formulae" && echo "upgraded $formulae" || echo "not upgraded"
    fi
  fi
}

function brew_cask_install_or_upgrade() {
  formulae=$1
  prompt_upgrade=$2
  prompt_install=$3
  
  if [ -z "$(brew list | grep "$formulae")" ]
  then
    if [ -z "$prompt_install" ] || user_confirms "$prompt_install"
    then
      brew cask install --force "$formulae"
      echo "installed $formulae"
    fi
  else
    if [ -z "$prompt_upgrade" ] || user_confirms "$prompt_upgrade"
    then
      brew cask upgrade "$formulae"
      echo "upgraded $formulae"
    fi
  fi
}

function mas_install() {
  app=$1

  app_id="$(mas search "$app" | grep -E -e "\s+\d+\s+${app}" | sed -E -e "s/[^0-9]*([0-9]+).*/\1/g")"
  if [ -z "${app_id}" ]
  then
    echo 'did not find "${app}" at the Mac App Store -- skipped'
    return
  fi
  
  if [ -n "$(mas list | grep -E "^${app_id} ")" ]
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
if ! which -s zsh || [ ! -d "${user_home}/.oh-my-zsh" ]
then
  sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh) --unattended"
  echo "installed oh-my-zsh"
fi 
# change the default shell to zsh
current_shell="$(finger $USER | grep Shell | sed -E -e 's/.*Shell: (.*)/\1/g')"
if [ "${current_shell}" != "/bin/zsh" ]
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

# 3.2. install "mas" Mac App Store CLI
brew_install_or_upgrade 'mas' 'Upgrade MAS (Mac App Store CLI)?'

# 3.3. install python and "pip" (python package manager)
brew_install_or_upgrade 'python' 'Upgrade Python?'

# 3.4. install "SDKMAN!" (SDK manager for SDKs like Java, Groovy, Kotlin, Maven, Gradle, ...)
if ! zsh -i -c 'which sdk &> /dev/null' || [ ! -d "${user_home}/.sdkman" ]
then
  curl -s "https://get.sdkman.io" | bash
  echo "installed SDKMAN!"
fi

# 4. install CLI tools
brew_install_or_upgrade 'coreutils' 'Upgrade coreutils?'
brew_install_or_upgrade 'htop'
brew_install_or_upgrade 'nmap'
brew_install_or_upgrade 'tldr'
brew_install_or_upgrade 'watch'
brew_install_or_upgrade 'wifi-password' 'Upgrade wifi-password?' 'Install wifi-password?'
brew_install_or_upgrade 'speedtest-cli' 'Upgrade speedtest-cli?' 'Install speedtest-cli?'

# 5. infrastructure tools
# 5.1. install fabric
if user_confirms "Install fabric?"
then
  pip3 install fabric
  echo "installed fabric"
fi

# 5.2. install terraform
brew_install_or_upgrade 'terraform' 'Upgrade terraform?' 'Install terraform?'

# 5.3. install awscli
if user_confirms "install AWS CLI?"
then
  pip3 install awscli --upgrade --user
  echo "installed AWS CLI"
fi

# 5.4. install container service
brew_cask_install_or_upgrade 'docker' 'Upgrade Docker?'
echo "installed the latest version of: Docker"

# 5.5. install kubernetes-related tools
rm -f /usr/local/bin/kubectl
brew_install_or_upgrade 'kubernetes-cli' 'Upgrade kubernetes-cli?'
brew_install_or_upgrade 'kubernetes-helm' 'Upgrade kubernetes-helm?' 'Install kubernetes-helm?'

# 6. install SDKs
zsh -i -c 'sdk install java $(sdk list java | grep zulu | head -n 1 | cut -d "|" -f 6 | sed -E -e "s#[^0-9]*(.*zulu).*#\1#g")'
zsh -i -c 'sdk install groovy'
zsh -i -c 'sdk install kotlin'
zsh -i -c 'sdk install maven'
zsh -i -c 'sdk install gradle'
echo "installed the latest SDKs for: Java, Groovy, Kotlin, Maven, Gradle"

# 7. install basic software
brew_cask_install_or_upgrade 'tunnelblick' 'Upgrade Tunnelblick (OpenVPN)?' 'Install Tunnelblick (OpenVPN)?'

# 8. install (BE) developer software
brew_cask_install_or_upgrade 'pgadmin4' 'Upgrade pgAdmin4?'
brew_cask_install_or_upgrade 'intellij-idea' 'Upgrade IntelliJ IDEA?'

# 9. install communication software
brew_cask_install_or_upgrade 'skype' 'Upgrade Skype?' 'Install Skype?'
mas_install 'Slack'

# 10. browsers
if [ ! -d "${user_home}/Applications/Chrome Apps.localized" ]
then
  if user_confirms "Google Chrome seems not be installed, yet. Do you want to install it?"
  then
    brew cask install google-chrome
  fi
else
  echo "Google Chrome is already installed"
fi

# 11. Akamai CLI
brew_install_or_upgrade 'akamai' 'Upgrade Akamai CLI?' 'Install Akamai CLI??'

# 12. Airtame
brew_cask_install_or_upgrade 'airtame' 'Upgrade Airtame?' 'Install Airtame?'

# 13. Cyberduck
brew_cask_install_or_upgrade 'cyberduck' 'Upgrade Cyberduck?' 'Install Cyberduck?'

# 14. Balsamiq Mockup
brew_cask_install_or_upgrade 'balsamiq-mockups' 'Upgrade Balamiq Mockups?' 'Install Balsamiq Mockups?'

# 15. Camunda Modeler
brew_cask_install_or_upgrade 'camunda-modeler' 'Upgrade Camunda Modeler?' 'Install Camunda Modeler?'

# 16. Zeebe Modeler
brew_cask_install_or_upgrade 'zeebe-modeler' 'Upgrade Zeebe Modeler?' 'Install Zeebe Modeler?'

# 17. Dropbox
brew_cask_install_or_upgrade 'dropbox' 'Upgrade Dropbox?' 'Install Dropbox?'

# 18. Amphetamine
mas_install 'Amphetamine'


echo "finished with the machine setup"


# run zsh
zsh
