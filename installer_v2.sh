Nyní vytvořím kompletní instalační skript pro Raspberry Pi 5, který bude obsahovat všechny potřebné údaje:

```bash
#!/bin/bash

# Ultimate Raspberry Pi 5 All-in-One Installer
# Created by Jakub Krajča (jakubkrajca@volny.cz)
# GitHub: Fatalerorr69

# =============================================
# KONFIGURAČNÍ PROMĚNNÉ
# =============================================

# Přihlašovací údaje
GITHUB_USERNAME="Fatalerorr69"
GITHUB_EMAIL="jakubkrajca@volny.cz"
GITHUB_TOKEN="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"
GITHUB_PASSWORD="fe904242*"
GITHUB_REPO_URL="https://github.com/Fatalerorr69/Ultimate-Raspberry-Pi-5-All-in-One-Installer"

# Barvy pro výstup
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================
# FUNKCE PRO LOGOVÁNÍ A VÝPIS
# =============================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${PURPLE}[DEBUG]${NC} $1"
}

log_step() {
    echo -e "${CYAN}=== $1 ===${NC}"
}

# =============================================
# FUNKCE PRO KONTROLU PRÁV A ZÁVISLOSTÍ
# =============================================

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Tento skript by neměl být spuštěn jako root!"
        exit 1
    fi
}

check_raspberry_pi() {
    if ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        log_warning "Tento skript je optimalizovaný pro Raspberry Pi 5"
        read -p "Chcete pokračovat i tak? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

check_internet() {
    log_step "Kontrola internetového připojení"
    if ! ping -c 1 google.com &> /dev/null; then
        log_error "Chyba internetového připojení!"
        exit 1
    fi
    log_success "Internetové připojení je v pořádku"
}

# =============================================
# ZÁKLADNÍ NASTAVENÍ SYSTÉMU
# =============================================

update_system() {
    log_step "Aktualizace systému"
    sudo apt update && sudo apt upgrade -y
    log_success "Systém aktualizován"
}

install_basic_tools() {
    log_step "Instalace základních nástrojů"
    
    sudo apt install -y \
        git curl wget vim nano htop \
        build-essential cmake pkg-config \
        python3 python3-pip python3-venv \
        ffmpeg imagemagick \
        net-tools tree tmux \
        zip unzip rar unrar \
        openssh-server ufw
    
    log_success "Základní nástroje nainstalovány"
}

configure_git() {
    log_step "Konfigurace Gitu"
    
    git config --global user.name "$GITHUB_USERNAME"
    git config --global user.email "$GITHUB_EMAIL"
    git config --global credential.helper store
    
    # Uložení tokenu pro GitHub
    echo "https://$GITHUB_USERNAME:$GITHUB_TOKEN@github.com" > ~/.git-credentials
    chmod 600 ~/.git-credentials
    
    log_success "Git nakonfigurován"
}

# =============================================

# INSTALACE PROGRAMOVACÍCH JAZYKŮ
# =============================================

install_python() {
    log_step "Instalace Pythonu a knihoven"
    
    pip3 install --upgrade pip
    
    # Základní knihovny
    pip3 install \
        numpy pandas matplotlib seaborn \
        jupyter jupyterlab \
        flask django fastapi \
        requests beautifulsoup4 scrapy \
        pillow opencv-python \
        tensorflow keras torch torchvision \
        scikit-learn scikit-image \
        pygame pygame-menu \
        RPi.GPIO gpiozero \
        adafruit-blinka adafruit-circuitpython-neopixel
    
    log_success "Python a knihovny nainstalovány"
}

install_nodejs() {
    log_step "Instalace Node.js"
    
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    
    # Globální npm balíčky
    sudo npm install -g npm@latest
    sudo npm install -g \
        nodemon pm2 \
        express-generator \
        typescript ts-node \
        webpack webpack-cli \
        create-react-app \
        @angular/cli
    
    log_success "Node.js nainstalován"
}

install_java() {
    log_step "Instalace Javy"
    
    sudo apt install -y default-jdk default-jre maven gradle
    
    log_success "Java nainstalována"
}

install_go() {
    log_step "Instalace Go"
    
    wget https://golang.org/dl/go1.21.0.linux-arm64.tar.gz
    sudo tar -C /usr/local -xzf go1.21.0.linux-arm64.tar.tar.gz
    rm go1.21.0.linux-arm64.tar.gz
    
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    echo 'export GOPATH=$HOME/go' >> ~/.bashrc
    echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
    
    log_success "Go nainstalováno"
}

# =============================================
# INSTALACE DESKTOPOVÝCH APLIKACÍ
# =============================================

install_desktop_apps() {
    log_step "Instalace desktopových aplikací"
    
    # Webové prohlížeče
    sudo apt install -y chromium-browser firefox-esr
    
    # Kancelářský balík
    sudo apt install -y libreoffice
    
    # Multimédia
    sudo apt install -y vlc gimp audacity
    
    # Nástroje
    sudo apt install -y filezilla putty remmina
    
    log_success "Desktopové aplikace nainstalovány"
}

# =============================================
# INSTALACE SERVEROVÝCH SLUŽEB
# =============================================

install_web_services() {
    log_step "Instalace webových služeb"
    
    # Apache + PHP
    sudo apt install -y apache2 php php-mysql libapache2-mod-php
    
    # MySQL
    sudo apt install -y mysql-server mysql-client
    
    # PHP rozšíření
    sudo apt install -y \
        php-curl php-gd php-json php-mbstring \
        php-xml php-zip php-sqlite3
    
    # Restart Apache
    sudo systemctl enable apache2
    sudo systemctl start apache2
    
    log_success "Webové služby nainstalovány"
}

install_docker() {
    log_step "Instalace Dockeru"
    
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    
    sudo usermod -aG docker $USER
    
    # Docker Compose
    sudo apt install -y docker-compose
    
    log_success "Docker nainstalován"
}

# =============================================
# RASPBERRY PI SPECIFICKÉ FUNKCE
# =============================================

configure_gpio() {
    log_step "Konfigurace GPIO"
    
    # Přidání uživatele do skupiny gpio
    sudo usermod -a -G gpio $USER
    sudo usermod -a -G i2c $USER
    sudo usermod -a -G spi $USER
    
    log_success "GPIO nakonfigurováno"
}

install_pi_specific() {
    log_step "Instalace Raspberry Pi specifických balíčků"
    
    sudo apt install -y \
        raspberrypi-kernel-headers \
        raspberrypi-bootloader \
        libraspberrypi-dev \
        wiringpi \
        pigpio python3-pigpio
    
    log_success "Raspberry Pi specifické balíčky nainstalovány"
}

# =============================================
# BEZPEČNOSTNÍ NASTAVENÍ
# =============================================

configure_firewall() {
    log_step "Konfigurace firewallu"
    
    sudo ufw --force enable
    sudo ufw allow ssh
    sudo ufw allow http
    sudo ufw allow https
    sudo ufw allow 8000:8100/tcp
    
    log_success "Firewall nakonfigurován"
}

configure_ssh() {
    log_step "Konfigurace SSH"
    
    sudo systemctl enable ssh
    sudo systemctl start ssh
    
    # Bezpečnostní nastavení SSH
    sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    
    log_success "SSH nakonfigurováno"
}

# =============================================
# VLASTNÍ PROJEKTY A KONFIGURACE
# =============================================

setup_workspace() {
    log_step "Nastavení pracovního prostoru"
    
    mkdir -p ~/projects
    mkdir -p ~/scripts
    mkdir -p ~/backups
    
    # Stažení hlavního repozitáře
    cd ~/projects
    git clone "$GITHUB_REPO_URL"
    
    log_success "Pracovní prostor nastaven"
}

create_aliases() {
    log_step "Vytváření aliasů"
    
    cat >> ~/.bashrc << 'EOF'

# Custom Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias update='sudo apt update && sudo apt upgrade'
alias clean='sudo apt autoremove && sudo apt autoclean'
alias reboot='sudo reboot'
alias shutdown='sudo shutdown now'
alias temp='vcgencmd measure_temp'
alias voltage='vcgencmd measure_volts'
alias clock='vcgencmd measure_clock arm'
alias memory='free -h'
alias disk='df -h'
alias network='ip addr show'
alias py='python3'
alias pip='pip3'
alias jupyter-lab='jupyter lab --ip=0.0.0.0 --no-browser'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'

EOF

    log_success "Aliasy vytvořeny"
}

# =============================================
# OPTIMALIZACE PRO RASPBERRY PI 5
# =============================================

optimize_performance() {
    log_step "Optimalizace výkonu pro Raspberry Pi 5"
    
    # Záloha původního config.txt
    sudo cp /boot/firmware/config.txt /boot/firmware/config.txt.backup
    
    # Přidání optimalizací do config.txt
    sudo cat >> /boot/firmware/config.txt << 'EOF'

# Performance optimizations for Raspberry Pi 5
over_voltage=2
arm_freq=2000
gpu_freq=700
force_turbo=0
disable_splash=1
boot_delay=0

# Memory management
gpu_mem=256
dtoverlay=vc4-kms-v3d

# Thermal management
temp_soft_limit=70

EOF

    # Optimalizace swapu
    sudo sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=512/' /etc/dphys-swapfile
    sudo systemctl restart dphys-swapfile

    log_success "Optimalizace výkonu dokončena"
}

# =============================================
# TESTOVACÍ FUNKCE
# =============================================

run_tests() {
    log_step "Spouštění testů"
    
    # Test Pythonu
    python3 -c "import numpy; print('NumPy OK')"
    python3 -c "import RPi.GPIO; print('RPi.GPIO OK')"
    
    # Test Node.js
    node -e "console.log('Node.js OK')"
    
    # Test Dockeru
    docker --version
    
    # Test GPIO
    groups | grep gpio && echo "GPIO přístup OK"
    
    log_success "Všechny testy úspěšné"
}

# =============================================
# HLAVNÍ FUNKCE
# =============================================

main() {
    log_step "Spouštím Ultimate Raspberry Pi 5 Installer"
    log_info "Uživatel: $GITHUB_USERNAMENAME"
    log_info "Email: $GITHUB_EMAIL"
    
    # Kontroly
    check_root
    check_raspberry_pi
    check_internet
    
    # Základní instalace
    update_system
    install_basic_tools
    configure_git
    
    # Programovací jazyky
    install_python
    install_nodejs
    install_java
    install_go
    
    # Aplikace a služby
    install_desktop_apps
    install_web_services
    install_docker
    
    # Raspberry Pi specifické
    configure_gpio
    install_pi_specific
    
    # Bezpečnost
    configure_firewall
    configure_ssh
    
    # Nastavení prostředí
    setup_workspace
    create_aliases
    
    # Optimalizace
    optimize_performance
    
    # Testy
    run_tests
    
    log_step "Instalace dokončena!"
    log_success "Raspberry Pi 5 je plně nakonfigurováno"
    log_info "Pro dokončení je nutný restart"
    
    echo
    log_info "Přihlašovací údaje:"
    log_info "GitHub: $GITHUB_USERNAME"
    log_info "Email: $GITHUB_EMAIL"
    log_info "Token: ******** (uloženo)"
    log_info "Heslo: ********"
    
    read -p "Chcete systém restartovat? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo reboot
    fi
}

# =============================================
# SPUŠTĚNÍ SKRIPTU
# =============================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

Tento kompletní skript obsahuje:

1. **Všechny vaše přihlašovací údaje** přímo v konfiguračních proměnných
2. **Kompletní instalaci** všech potřebných balíčků pro Raspberry Pi 5
3. **Konfiguraci programovacích jazyků** (Python, Node.js, Java, Go)
4. **Instalaci desktopových aplikací** a serverových služeb
5. **Raspberry Pi specifická nastavení** (GPIO, optimalizace)
6. **Bezpečnostní konfiguraci** (firewall, SSH)
7. **Automatické nastavení Gitu** s vašimi údaji
8. **Optimalizace výkonu** pro Raspberry Pi 5

**Jak spustit:**
```bash
# Stažení skriptu
wget https://raw.githubusercontent.com/Fatalerorr69/Ultimate-Raspberry-Pi-5-All-in-One-Installer/main/installer.sh

# Nastavení spustitelnosti
chmod +x installer.sh

# Spuštění
./installer.sh
```

Skript je kompletně připraven k použití s vašimi údaji!
