#!/usr/bin/env bash
set -e

update_brewfile=false
brewfile="${HOME}/.Brewfile"
no_upgrade=""

while [ $# -gt 0 ]; do
  case "$1" in
    -f|--brewfile)
      source_brewfile="$2"
      shift
      shift
      ;;
    -b|--use-branch)
      branch="$2"
      shift
      shift
      ;;
    -u|--update-brewfile)
      update_brewfile=true
      shift
      ;;
    --no-global)
      brewfile="${HOME}/.mac-setup/Brewfile"
      shift
      ;;
    --no-upgrade)
      no_upgrade="--no-upgrade"
      shift
      ;;
    *)
      printf "Usage:\n"
      printf "mac-setup.sh {options}\n"
      printf "  Options:\n"
      printf "    [-b|--use-branch {branch}]\n"
      printf "        Branch from this repository to use when selecting the default Brewfile.\n"
      printf "    [-f|--brewfile {source-brewfile}]\n"
      printf "        Source Brewfile. By default, the one in this repository.\n"
      printf "    [-u|--update-brewfile]\n"
      printf "        Whether the local Brewfile should be overwritten with the latest state of the source.\n"
      printf "    [--no-global]\n"
      printf "        By default, we use the global location ~/.Brewfile as installation destination.\n"
      printf "        This option disables this and uses a separate location.\n"
      printf "    [--no-upgrade]\n"
      printf "        Applies the same option to the brew command.\n"
      exit 1
  esac
done

DEFAULT_BREWFILE="https://raw.githubusercontent.com/pjungermann/mac-setup/${branch:-main}/Brewfile"
if [ -z "$source_brewfile" ]
then
  source_brewfile="$DEFAULT_BREWFILE"
fi


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
if ! which -s zsh || [[ ! -d "${HOME}/.oh-my-zsh" ]]
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
ZSHRC="${HOME}/.zshrc"


# 3. install package managers
# 3.1. install "Homebrew" (general Mac OS package manager)
# shellcheck disable=SC2230
if which -s brew
then
  brew update
else
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  # shellcheck disable=SC2016
  (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/patrick.jungermann/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
  echo "installed Homebrew"
fi
HOMEBREW_PREFIX="$(brew --prefix)"


# 4. Install by Brewfile
if $update_brewfile || [ ! -f "${brewfile}" ]
then
  mkdir -p "$(dirname "$brewfile")"
  curl -fsSL "${source_brewfile}" -o "${brewfile}"
fi
if grep -E -e '^mas "' "${brewfile}" >/dev/null
then
  read -rs \
       -p "Please log in manually at the Mac App Store. Press any key to continue." \
       -n 1
fi
brew bundle --file "${brewfile}" ${no_upgrade}


# 5. Install software using asdf
# 5.1. install to zsh / handle brew caveat
asdf_zsh="${HOMEBREW_PREFIX}/opt/asdf/libexec/asdf.sh"
if ! grep "$asdf_zsh" "$ZSHRC" >/dev/null
then
 cat <<-EOS >> "$ZSHRC"
# asdf-vm.com
source "$asdf_zsh"
EOS
  # shellcheck disable=SC1090
  source "$ZSHRC"  # reload
fi

java_distribution="corretto"
for asdf_plugin in gradle groovy java maven nodejs ruby
do
  if ! asdf plugin list | grep -E -e "^${asdf_plugin}$"
  then
    asdf plugin add "$asdf_plugin"
  fi

  asdf_plugin_version=latest
  if [ "$asdf_plugin" = "java" ]
  then
    asdf_plugin_version="latest:${java_distribution}"
  fi

  asdf install "$asdf_plugin" "$asdf_plugin_version"
  asdf global "$asdf_plugin" "$asdf_plugin_version"
done
# 5.1 Java - some additional versions
for java_version in 8 11
do
  asdf install java "latest:${java_distribution}-${java_version}."
done


# 6. pre-install latest terraform version
tfswitch --latest


# 7. Oh My Zsh - Plugins
zsh_plugins="\
aws colored-man-pages command-not-found docker docker-compose git gradle helm history-substring-search \
kubectl man mvn"
sed -i "" \
    -E \
    -e "s#^plugins=\(.*\)#plugins=(${zsh_plugins})#" \
    "${HOME}/.zshrc"


echo "finished with the machine setup"


# run zsh
zsh
