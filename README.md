# mac-setup
automated setup of a Mac with basic software

## Execute / Install
via curl
```
$ bash -c "$(curl -fsSL https://raw.githubusercontent.com/pjungermann/mac-setup/master/mac-setup.sh)"
```

via wget
```
$ bash -c "$(wget https://raw.githubusercontent.com/pjungermann/mac-setup/master/mac-setup.sh -O -)"
```

with `-y` (always yes; install and upgrade everything)

via curl
```
$ curl -fsSL https://raw.githubusercontent.com/pjungermann/mac-setup/master/mac-setup.sh | bash -s -- -y
```

via wget
```
$ wget https://raw.githubusercontent.com/pjungermann/mac-setup/master/mac-setup.sh -O - | bash -s -- -y
```

## Installed Software
### MacOS Core
* Xcode Command Line Tools

### Shell
* [Oh My Zsh](https://ohmyz.sh/) - shell
  * activate some standard plugins (see `plugins` in `~/.zshrc` as well as `~/.oh-my-zsh/plugins/`)

### Package Managers
* _optional:_ [Conda - Miniconda](https://conda.io/en/latest/) - package manager for any language
* [Homebrew](https://brew.sh/) - package manager
* [mas](https://github.com/mas-cli/mas) - CLI for the Mac App Store
* [pip](https://www.python.org/) - Python package manager
* [SDKMAN!](https://sdkman.io/) - software development kit manager
* [NVM](https://github.com/nvm-sh/nvm) - Node Version Manager
* [Yarn](https://yarnpkg.com/) - JavaScript Package Manager
* [RVM](https://rvm.io/) - Ruby Version Manager

### Terminal
* _optional:_ [iTerm2](https://www.iterm2.com/)

### General Comands
* [bfg](https://rtyley.github.io/bfg-repo-cleaner/) - Clean data out of your Git repository history (e.g. remove big files or passwords).
* _optional:_ [cheat](https://github.com/cheat/cheat) - cheatsheets at the command-line for \*nix commands (similar: _tldr_; [collaboration issue](https://github.com/tldr-pages/tldr/issues/266))
* coretuils - Provides GNU-compatible commands (all prefixed with "g" like "gfind").
* _optional:_ [fabric](https://www.fabfile.org/) - remote shell command execution over SSH
* help - custom meta-command executing both "tldr" and "cheat" (`help {command}`)
* [htop](https://hisham.hm/htop/) - interactive process viewer
* [jq](https://stedolan.github.io/jq) - A lightweight and flexible command-line JSON processor.
* [nmap](https://nmap.org/) - Network exploration tool and security / port scanner
* [parallel](https://www.gnu.org/software/parallel/man.html) - Run commands on multiple CPU cores
* _optional:_ [speedtest-cli](https://github.com/sivel/speedtest-cli) - CLI for testing internet bandwidth using speedtest.net
* _optional:_ [tldr](https://tldr.sh/) - simplified and community-driven man pages (similar: _cheat_; [collaboration issue](https://github.com/tldr-pages/tldr/issues/266))
* watch - Execute a program periodically, showing output fullscreen
* _optional:_ [wifi-password](https://github.com/rauchg/wifi-password) - get password of configured WiFis
* [yq](https://github.com/mikefarah/yq) - A portable command-line YAML processor.

### Infrastructure (as Code) Commands and Software
* _optional:_ [Akamai CLI](https://github.com/akamai/cli) - CLI for Akamai
* _optional:_ [AWS CLI](https://aws.amazon.com/cli/) - CLI for AWS
* _optional:_ [Kubernetes CLI](https://kubernetes.io/docs/reference/kubectl/overview/) - Kubernetes CLI kubectl
* _optional:_ [kubectx](https://github.com/ahmetb/kubectx) - allows switching between kubectl contexts easily
* _optional:_ [Helm](https://helm.sh/) - package manager for Kubernetes
* _optional:_ [Kubernetes Minikube](https://kubernetes.io/docs/tutorials/hello-minikube/) - local Kubernetes environment
* _optional:_ [tfswitch](https://warrensbox.github.io/terraform-switcher) - allows switching between [Terraform](https://www.terraform.io/) versions (used to write, plan, and create Infrastructure as Code)

### Containers
* [Docker](https://hub.docker.com/) - container service
* [container-diff](https://github.com/GoogleContainerTools/container-diff) - Diff your Docker container images.

### SDKs, Programming Language Support
* [Groovy](https://groovy-lang.org/) language, compiler, runtime, ...
* [Java](https://www.oracle.com/technetwork/java/javase/overview/index.html), latest [zulu distribution](https://www.azul.com/downloads/zulu-community/)
* [Kotlin](https://kotlinlang.org/) language, compiler, runtime, ...
* [Python (incl. pip)](https://www.python.org/) language, runtime, compiler, package manager, ...

### Software Build Tools
* [Gradle](https://gradle.org/) - build, automate, and deliver software; dependency manager
* [Maven](https://maven.apache.org/) - Java/JVM software project management and comprehension tool, dependency manager

### IDEs
* [JetBrains Toolbox](https://www.jetbrains.com/toolbox/) - manage JetBrains tools, multi-version support, ...
  * [JetBrains IntelliJ IDEA](https://www.jetbrains.com/idea/) can be installed using the Toolbox
* _optional:_ [Visual Studio Code / VS Code](https://code.visualstudio.com/)

### API Development and Testing
* _optional:_ [Insomnia](https://insomnia.rest/) - API debugging/testing, REST client, GraphQL support
* _optional:_ [Postman](https://www.getpostman.com/) - API development environment

### Browsers
* _optional:_ [Firefox](https://www.mozilla.org/firefox/)
* _optional:_ [Google Chrome](https://www.google.com/chrome/)

### Security
* _optional:_ [Tunnelblick](https://tunnelblick.net/) - OpenVPN client
* [SOPS](https://github.com/mozilla/sops) - sops is an editor of encrypted files that supports YAML, JSON, ENV, INI and BINARY formats 
  and encrypts with AWS KMS, GCP KMS, Azure Key Vault and PGP.

### Communication, Presentation
* _optional:_ [Airtame](https://airtame.com/) - wireless screen sharing
* _optional:_ [Slack](https://slack.com/) (App Store) - communication and collaboration

### Database
* [pgAdmin4](https://www.pgadmin.org/) - PostgreSQL utility

### File Transfer and Sync
* _optional:_ [Cyberduck](https://cyberduck.io/) - server and cloud storage browser with support for (S)FTP, AWS S3, Dropbox, ...
* _optional:_ [Dropbox](https://www.dropbox.com/) - file hosting

### Business Process Management (BPM)
* _optional:_ [Camunda Modeler](https://camunda.com/download/modeler/) - BPMN modeler (for and) by Camunda
* _optional:_ [Zeebe Modeler](https://github.com/zeebe-io/zeebe-modeler) - BPMN modeler for Zeebe by Camunda

### Wireframing, Mockups
* _optional:_ [Balsamiq Mockups](https://balsamiq.com/wireframes/) - wireframing tool

### Utilities
* _optional:_ [Amphetamine](https://apps.apple.com/de/app/amphetamine/id937984704?mt=12) - powerful keep-awake utility
* _optional:_ [Spectacle](https://www.spectacleapp.com/) - organize windows without using a mouse

### Music
* _optional:_ [Spotify](https://www.spotify.com/)

