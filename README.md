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
$ curl -fsSL https://raw.githubusercontent.com/pjungermann/mac-setup/master/mac-setup.sh | bash -s -- -y"
```

via wget
```
$ wget https://raw.githubusercontent.com/pjungermann/mac-setup/master/mac-setup.sh -O - | bash -s -- -y"
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

### Terminal
* _optional:_ [iTerm2](https://www.iterm2.com/)

### General Comands
* _optional:_ [fabric](https://www.fabfile.org/) - remote shell command execution over SSH
* htop - interactive process viewer
* [nmap](https://nmap.org/) - Network exploration tool and security / port scanner
* [parallel](https://www.gnu.org/software/parallel/man.html) - Run commands on multiple CPU cores
* _optional:_ [speedtest-cli](https://github.com/sivel/speedtest-cli) - CLI for testing internet bandwidth using speedtest.net
* [tldr](https://tldr.sh/) - simplified and community-driven man pages
* watch - Execute a program periodically, showing output fullscreen
* _optional:_ [wifi-password](https://github.com/rauchg/wifi-password) - get password of configured WiFis

### Infrastructure (as Code) Commands and Software
* _optional:_ [Akamai CLI](https://github.com/akamai/cli) - CLI for AWS
* _optional:_ [AWS CLI](https://aws.amazon.com/cli/) - CLI for AWS
* _optional:_ [Kubernetes CLI](https://kubernetes.io/docs/reference/kubectl/overview/) - Kubernetes CLI kubectl
* _optional:_ [Kubernetes' Helm](https://helm.sh/) - package manager for Kubernetes
* _optional:_ [Kubernetes Minikube](https://kubernetes.io/docs/tutorials/hello-minikube/) - local Kubernetes environment
* _optional:_ [Terraform](https://www.terraform.io/) - write, plan, and create Infrastructure as Code

### Containers
* [Docker](https://hub.docker.com/) - container service

### SDKs, Programming Language Support
* [Groovy](https://groovy-lang.org/) language, compiler, runtime, ...
* [Java](https://www.oracle.com/technetwork/java/javase/overview/index.html), latest [zulu distribution](https://www.azul.com/downloads/zulu-community/)
* [Kotlin](https://kotlinlang.org/) language, compiler, runtime, ...
* [Python (incl. pip)](https://www.python.org/) language, runtime, compiler, package manager, ...

### Software Build Tools
* [Gradle](https://gradle.org/) - build, automate, and deliver software; dependency manager
* [Maven](https://maven.apache.org/) - Java/JVM software project management and comprehension tool, dependency manager

### IDEs
* [JetBrains IntelliJ IDEA](https://www.jetbrains.com/idea/)
* [JetBrains Toolbox](https://www.jetbrains.com/toolbox/) - manage JetBrains tools, multi-version support, ...
* _optional:_ [Visual Studio Code / VS Code](https://code.visualstudio.com/)

### API Development and Testing
* _optional:_ [Insomnia](https://insomnia.rest/) - API debugging/testing, REST client, GraphQL support
* _optional:_ [Postman](https://www.getpostman.com/) - API development environment

### Browsers
* _optional:_ [Firefox](https://www.mozilla.org/firefox/)
* _optional:_ [Google Chrome](https://www.google.com/chrome/)

### Secured Connection
* _optional:_ [Tunnelblick](https://tunnelblick.net/) - OpenVPN client

### Communication, Presentation
* _optional:_ [Airtame](https://airtame.com/) - wireless screen sharing
* _optional:_ [Skype](https://www.skype.com/) - chats, calls
* _optional:_ [Skype for Business](https://www.skype.com/business/) - calls, meetings
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

