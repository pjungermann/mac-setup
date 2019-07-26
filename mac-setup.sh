#!/bin/bash
set -e

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
      brew upgrade "$formulae"
      echo "upgraded $formulae"
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
      brew cask install "$formulae"
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

# 1. install xcode Command Line Tools (CLT)
if xcode-select -p 2> /dev/null 
then
  echo "Xcode Command Line Tools (CLT) already installed"
else
  echo "Xcode Command Line Tools (CLT) not installed, yet"
  xcode-select --install
  echo -n "waiting for Xcode CLT installation to be completed.."
  while ! xcode-select -p 2>1 /dev/null
  do
     sleep 10 # seconds
     echo -n "."
  done
  echo ""
  echo "installed Xcode Command Line Tools (CLT)"
fi

# 2. install "Oh My Zsh" - https://ohmyz.sh
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh) --unattended"
# change the default shell to zsh
current_shell="$(finger $USER | grep Shell | sed -E -e 's/.*Shell: (.*)/\1/g')"
if [ "${current_shell}" != "/bin/zsh" ]
then
  chsh -s /bin/zsh
fi
echo "installed oh-my-zsh"

# 3. install package managers
# 3.1. install "Homebrew" (general Mac OS package manager)

/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
echo "installed homebrew with commands: 'brew' and 'brew cask'"

# 3.2. install "mas" Mac App Store CLI
brew_install_or_upgrade 'mas' 'Upgrade MAS (Mac App Store CLI)?'

# 3.3. install python and "pip" (python package manager)
brew_install_or_upgrade 'python' 'Upgrade Python?'

# 3.4. install "SDK Man" (SDK manager for SKDs like Java, Groovy, Grails, Maven, Gradle, ...)
curl -s "https://get.sdkman.io" | bash
echo "installed SDK Man"

# 4. install CLI tools
brew_install_or_upgrade 'coreutils' 'Upgrade coreutils?'
brew_install_or_upgrade 'htop'
brew_install_or_upgrade 'tldr'

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
brew_install_or_upgrade 'kubernetes-cli' 'Upgrade kubernetes-cli?' 'Install kubernetes-cli?'
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
brew_cask_install_or_uprgade 'pgadmin4' 'Upgrade pgAdmin4?'
brew_cask_install_or_upgrade 'intellij-idea' 'Upgrade IntelliJ IDEA?'

# 9. install communication software
brew_cask_install_or_upgrade 'skype' 'Upgrade Skype?' 'Install Skype?'
if user_confirms "install Slack?"
then
  slack_id=$(mas search Slack | grep -E -e "\s+\d+\s+Slack" | sed -E -e "s/[^0-9]*([0-9]+).*/\1/g")
  if [ -n "${slack_id}" ]
  then
    install_status=1
    while ! mas install "${slack_id}"
    do
      echo -n "Please login manually at the Mac App Store. Press ENTER to continue."
      read any_key
    done
    # alternative? brew cask install slack
    echo "installed the latest version of Slack"
  else
    echo 'did not find "Slack" at the Mac App Store -- skipped'
  fi
fi

# 10. browsers
user_home="$(cd ~ && pwd)"
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


echo "finished with the machine setup"

# run zsh
zsh
