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

# 1. install xcode Command Line Tools (CLT)
if xcode-select -p 2> /dev/null 
then
  echo "Xcode Command Line Tools (CLT) already installed"
else
  echo "Xcode Command Line Tools (CLT) not installed, yet"
  xcode-select --install
  echo -n "waiting for Xcode CLT installation to be completed..
  while ! xcode-select -p 2> /dev/null
  do
     sleep 10 # seconds
     echo -n "."
  done
  echo ""
  echo "installed Xcode Command Line Tools (CLT)"
fi

# 2. install "Oh My Zsh" - https://ohmyz.sh
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
# change the default shell to zsh (needed?)
chsh -s /bin/zsh
# load the config / environment settings of ZSH
~/.zshrc
echo "installed oh-my-zsh"

# 3. install package managers
# 3.1. install "Homebrew" (general Mac OS package manager)
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
echo "installed homebrew with commands: 'brew' and 'brew cask'"

# 3.2. install "pip" by python (python package manager)
brew install python-pip
echo "installed python's pip"

# 3.3. install "SDK Man" (SDK manager for SKDs like Java, Groovy, Grails, Maven, Gradle, ...)
curl -s "https://get.sdkman.io" | bash
echo "installed SDK Man"

# 4. refresh environment settings
~/.zshrc

# 5. install CLI tools
brew install htop
echo "installed command htop"

brew install tldr
echo "installed command tldr"

# 6. install fabric
if user_confirms "install fabric?"
then
  pip install fabric
  echo "installed fabric"
fi

# 7. install SDKs
sdk install java
sdk install groovy
sdk install kotlin
sdk install maven
sdk install gradle
echo "installed the latest SDKs for: Java, Groovy, Kotlin, Maven, Gradle"

# 8. install basic software
if user_confirms "install Tunnelblick (OpenVPN)?"
then
  brew cask install tunnelblick
  echo "installed the lastest version of Tunnelblick (VPN)"
fi

# 9. install container service
brew cask install docker
echo "installed the latest version of: Docker"

# 10. install (BE) developer software
brew cask install pgadmin4
brew cask install intellij-idea
echo "installed the latest version of: pgAdmin4, IntelliJ IDEA"

# 11. install communication software
if user_confirms "install Skype?"
then
  brew cask install skype
  echo "installed the lastest version of Skype"
fi
if user_confirms "install Slack?"
then
  slack_id=$(mas search Slack | grep -E -e "\s+\d+\s+Slack" | sed -E -e "s/[^0-9]*([0-9]+).*/\1/g")
  if [ -n "${slack_id}" ]
  then
    mas install "${slack_id}"
    # alternative? brew cask install slack
    echo "installed the latest version of Slack"
  else
    echo 'did not find "Slack" at the Mac App Store -- skipped'
  fi
fi

# 12. browsers
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


echo "finished with the machine setup"

