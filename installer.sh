#!/bin/bash
set -e

# =============================================
# KONFIGURAČNÍ PROMĚNNÉ
# =============================================

# Systémové nastavení
PI_USER=$(whoami)
PI_HOSTNAME=$(hostname)
TIMEZONE="Europe/Prague"
DOCKER_NETWORK="pi5-network"

# GitHub konfigurace (budou vyžádány interaktivně)
GITHUB_USERNAME=""
GITHUB_EMAIL=""
GITHUB_REPO_URL=""

# Barvy pro výstup
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================
# FUNKCE PRO LOGOVÁNÍ A VÝPIS
# =============================================

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

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

log_step() {
    echo -e "${CYAN}=== $1 ===${NC}"
    echo
}

# =============================================
# BEZPEČNOSTNÍ KONTROLY
# =============================================

check_security() {
    log_step "BEZPEČNOSTNÍ KONTROLA"
    
    # Kontrola citlivých údajů ve skriptu
    if grep -q "ghp_" "$0" || grep -q "password" "$0" 2>/dev/null; then
        log_error "Skript obsahuje citlivé údaje! Před spuštěním je odstraňte."
        exit 1
    fi
    
    # Kontrola práva spouštění
    if [[ $EUID -eq 0 ]]; then
        log_error "Skript nesmí být spuštěn jako root!"
        exit 1
    fi
    
    log_success "Bezpečnostní kontrola prošla"
}

check_dependencies() {
    log_step "KONTROLA ZÁVISLOSTÍ"
    
    local deps=("curl" "wget" "git")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_info "Instalace chybějících závislostí: ${missing[*]}"
        sudo apt update
        sudo apt install -y "${missing[@]}"
    fi
    
    log_success "Všechny závislosti jsou nainstalovány"
}

check_raspberry_pi() {
    log_step "KONTROLA ZAŘÍZENÍ"
    
    if ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        log_warning "Tento skript je optimalizovaný pro Raspberry Pi"
        read -p "Chcete pokračovat i tak? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# =============================================
# INTERAKTIVNÍ KONFIGURACE
# =============================================

get_github_credentials() {
    log_step "KONFIGURACE GITHUB"
    
    read -p "Zadejte GitHub uživatelské jméno: " GITHUB_USERNAME
    read -p "Zadejte GitHub email: " GITHUB_EMAIL
    
    # Validace emailu
    if [[ ! "$GITHUB_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Neplatný email formát!"
        exit 1
    fi
    
    GITHUB_REPO_URL="https://github.com/$GITHUB_USERNAME/Ultimate-Raspberry-Pi-5-All-in-One-Installer"
    
    log_success "GitHub údaje nastaveny"
}

get_service_passwords() {
    log_step "NASTAVENÍ HESEL PRO SLUŽBY"
    
    read -s -p "Heslo pro Pi-hole admin: " PIHOLE_PASSWORD
    echo
    read -s -p "Heslo pro Vaultwarden: " VAULTWARDEN_PASSWORD
    echo
    
    # Základní validace hesel
    if [[ ${#PIHOLE_PASSWORD} -lt 8 ]]; then
        log_warning "Heslo pro Pi-hole by mělo mít alespoň 8 znaků"
    fi
}

# =============================================
# ZÁKLADNÍ INSTALACE SYSTÉMU
# =============================================

update_system() {
    log_step "AKTUALIZACE SYSTÉMU"
    
    sudo apt update
    sudo apt upgrade -y
    sudo apt autoremove -y
    sudo apt autoclean
    
    log_success "Systém aktualizován"
}

install_basic_tools() {
    log_step "INSTALACE ZÁKLADNÍCH NÁSTROJŮ"
    
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
    log_step "KONFIGURACE GITU"
    
    git config --global user.name "$GITHUB_USERNAME"
    git config --global user.email "$GITHUB_EMAIL"
    git config --global credential.helper store
    
    log_success "Git nakonfigurován pro: $GITHUB_USERNAME"
}

# =============================================
# INSTALACE DOCKERU
# =============================================

install_docker() {
    log_step "INSTALACE DOCKER ENGINE"
    
    # Odstranění starých verzí
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Instalace Dockeru
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    
    # Přidání uživatele do skupiny docker
    sudo usermod -aG docker "$USER"
    
    # Instalace Docker Compose
    sudo apt install -y docker-compose-plugin
    
    log_success "Docker úspěšně nainstalován"
}

# =============================================
# PŘÍPRAVA PROSTORU PRO SLUŽBY
# =============================================

setup_directories() {
    log_step "PŘÍPRAVA ADRESÁŘOVÉ STRUKTURY"
    
    local base_dir="$HOME/docker-stack"
    
    mkdir -p "$base_dir"/{config,data,backups,scripts}
    mkdir -p "$base_dir/config"/{portainer,heimdall,nextcloud,vaultwarden,jellyfin,homeassistant,pihole,monitoring}
    mkdir -p "$base_dir/data"/{media,downloads,documents,backups}
    
    log_success "Adresářová struktura vytvořena v: $base_dir"
}

create_docker_compose() {
    log_step "VYTVÁŘENÍ DOCKER COMPOSE SOUBORU"
    
    local compose_file="$HOME/docker-stack/docker-compose.yml"
    
    cat > "$compose_file" << EOF
version: '3.8'

services:
  # 🎯 SPRÁVA SYSTÉMU
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports: ["9000:9000"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./config/portainer:/data
    networks: [pi5-network]

  # 📊 MONITORING
  glances:
    image: nicolargo/glances:latest
    container_name: glances
    restart: unless-stopped
    ports: ["61208:61208"]
    volumes: [/var/run/docker.sock:/var/run/docker.sock:ro]
    networks: [pi5-network]

  # 🏠 DASHBOARD
  heimdall:
    image: lscr.io/linuxserver/heimdall:latest
    container_name: heimdall
    restart: unless-stopped
    ports: ["8080:80"]
    environment: 
      TZ: $TIMEZONE
      PUID: 1000
      PGID: 1000
    volumes: [./config/heimdall:/config]
    networks: [pi5-network]

  # ☁️ CLOUDOVÉ ÚLOŽIŠTĚ
  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    restart: unless-stopped
    ports: ["8081:80"]
    environment: 
      TZ: $TIMEZONE
    volumes: 
      - ./config/nextcloud:/var/www/html
      - ./data/documents:/var/www/html/data/documents
    networks: [pi5-network]

  # 🔐 SPRÁVCE HESEL
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    ports: ["8082:80"]
    environment: 
      WEBSOCKET_ENABLED: "true"
      SIGNUPS_ALLOWED: "false"
      ADMIN_TOKEN: "$VAULTWARDEN_PASSWORD"
    volumes: [./config/vaultwarden:/data]
    networks: [pi5-network]

  # 🎬 MEDIÁLNÍ SERVER
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    ports: ["8096:8096"]
    environment: 
      TZ: $TIMEZONE
    volumes: 
      - ./config/jellyfin:/config
      - ./data/media:/media
    networks: [pi5-network]

  # 🏡 CHYTRÁ DOMÁCNOST
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    ports: ["8123:8123"]
    environment: 
      TZ: $TIMEZONE
    volumes: 
      - ./config/homeassistant:/config
      - /etc/localtime:/etc/localtime:ro
    networks: [pi5-network]

  # 🛡️ BLOKOVÁNÍ REKLAM
  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    restart: unless-stopped
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80"
    environment:
      TZ: $TIMEZONE
      WEBPASSWORD: "$PIHOLE_PASSWORD"
    volumes:
      - ./config/pihole/etc-pihole:/etc/pihole
      - ./config/pihole/etc-dnsmasq.d:/etc/dnsmasq.d
    networks: [pi5-network]

networks:
  pi5-network:
    driver: bridge
EOF

    log_success "Docker Compose soubor vytvořen: $compose_file"
}

# =============================================
# KONFIGURACE SLUŽEB
# =============================================

interactive_service_selection() {
    log_step "VÝBĚR SLUŽEB K INSTALACI"
    
    declare -A services=(
        ["Portainer"]="Správa Docker kontejnerů"
        ["Heimdall"]="Dashboard pro všechny služby"
        ["Nextcloud"]="Cloudové úložiště"
        ["Vaultwarden"]="Správce hesel"
        ["Jellyfin"]="Mediální server"
        ["Home Assistant"]="Chytrá domácnost"
        ["Pi-hole"]="Blokování reklam"
    )
    
    selected_services=()
    
    for service in "${!services[@]}"; do
        read -p "Nainstalovat $service? (${services[$service]}) (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            selected_services+=("$service")
        fi
    done
    
    log_info "Vybráno služeb: ${#selected_services[@]}"
    printf '%s\n' "${selected_services[@]}"
}

deploy_services() {
    log_step "SPOUŠTĚNÍ VYBRANÝCH SLUŽEB"
    
    cd "$HOME/docker-stack"
    
    # Vytvoření Docker sítě
    docker network create "$DOCKER_NETWORK" 2>/dev/null || true
    
    # Spuštění služeb
    docker compose up -d
    
    # Čekání na start
    sleep 15
    
    # Kontrola stavu
    log_info "Kontrola stavu kontejnerů..."
    docker compose ps
    
    log_success "Služby úspěšně spuštěny"
}

# =============================================
# OPTIMALIZACE PRO RASPBERRY PI
# =============================================

optimize_system() {
    log_step "OPTIMALIZACE SYSTÉMU PRO RASPBERRY PI"
    
    # Záloha původního config.txt
    sudo cp /boot/firmware/config.txt /boot/firmware/config.txt.backup 2>/dev/null || true
    
    # Přidání optimalizací
    sudo tee -a /boot/firmware/config.txt > /dev/null << EOF

# Optimalizace pro Raspberry Pi 5
over_voltage=2
arm_freq=2000
gpu_freq=700
force_turbo=0
disable_splash=1
boot_delay=0
gpu_mem=256
temp_soft_limit=70
EOF

    # Optimalizace swapu
    sudo sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=512/' /etc/dphys-swapfile 2>/dev/null || true
    
    log_success "Systém optimalizován"
}

# =============================================
# BEZPEČNOSTNÍ NASTAVENÍ
# =============================================

configure_security() {
    log_step "KONFIGURACE BEZPEČNOSTI"
    
    # Firewall
    sudo ufw --force enable
    sudo ufw allow ssh
    sudo ufw allow http
    sudo ufw allow https
    sudo ufw allow 9000:9100/tcp
    
    # SSH hardening
    sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    
    sudo systemctl enable ssh
    sudo systemctl restart ssh
    
    log_success "Bezpečnostní nastavení dokončeno"
}

# =============================================
# NÁSTROJE PRO SPRÁVU
# =============================================

create_management_scripts() {
    log_step "VYTVÁŘENÍ SKRIPTŮ PRO SPRÁVU"
    
    local scripts_dir="$HOME/docker-stack/scripts"
    
    # Skript pro aktualizaci
    cat > "$scripts_dir/update-services.sh" << 'EOF'
#!/bin/bash
echo "🔄 Aktualizace všech služeb..."
cd ~/docker-stack
docker compose pull
docker compose up -d
docker system prune -f
echo "✅ Aktualizace dokončena!"
EOF

    # Skript pro zálohu
    cat > "$scripts_dir/backup-data.sh" << 'EOF'
#!/bin/bash
BACKUP_DIR="$HOME/docker-stack/backups"
BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
echo "📦 Vytváření zálohy: $BACKUP_NAME"
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"
cp -r ~/docker-stack/config "$BACKUP_DIR/$BACKUP_NAME/"
echo "✅ Záloha vytvořena: $BACKUP_DIR/$BACKUP_NAME"
EOF

    # Skript pro restart
    cat > "$scripts_dir/restart-services.sh" << 'EOF'
#!/bin/bash
echo "🔄 Restartování služeb..."
cd ~/docker-stack
docker compose down
sleep 5
docker compose up -d
echo "✅ Služby restartovány"
EOF

    chmod +x "$scripts_dir"/*.sh
    log_success "Management skripty vytvořeny"
}

generate_access_info() {
    log_step "GENEROVÁNÍ PŘÍSTUPOVÝCH ÚDAJŮ"
    
    local ip_address
    ip_address=$(hostname -I | awk '{print $1}')
    local access_file="$HOME/docker-stack/ACCESS_INFO.txt"
    
    cat > "$access_file" << EOF
=== RASPBERRY PI 5 ALL-IN-ONE SYSTEM ===
Datum instalace: $(date)
IP adresa: $ip_address

📋 PŘÍSTUPOVÉ ÚDAJE:

$(if [[ " ${selected_services[@]} " =~ "Portainer" ]]; then
echo "🛠️  Portainer (Správa kontejnerů):"
echo "   URL: http://$ip_address:9000"
echo "   Poznámka: První přihlášení vytvoří admin účet"
echo ""
fi)

$(if [[ " ${selected_services[@]} " =~ "Heimdall" ]]; then
echo "📊 Heimdall (Dashboard):"
echo "   URL: http://$ip_address:8080"
echo ""
fi)

$(if [[ " ${selected_services[@]} " =~ "Nextcloud" ]]; then
echo "☁️  Nextcloud (Cloudové úložiště):"
echo "   URL: http://$ip_address:8081"
echo ""
fi)

$(if [[ " ${selected_services[@]} " =~ "Vaultwarden" ]]; then
echo "🔐 Vaultwarden (Správce hesel):"
echo "   URL: http://$ip_address:8082"
echo "   Admin token: $VAULTWARDEN_PASSWORD"
echo ""
fi)

$(if [[ " ${selected_services[@]} " =~ "Jellyfin" ]]; then
echo "🎬 Jellyfin (Mediální server):"
echo "   URL: http://$ip_address:8096"
echo ""
fi)

$(if [[ " ${selected_services[@]} " =~ "Home Assistant" ]]; then
echo "🏠 Home Assistant (Chytrá domácnost):"
echo "   URL: http://$ip_address:8123"
echo ""
fi)

$(if [[ " ${selected_services[@]} " =~ "Pi-hole" ]]; then
echo "🛡️  Pi-hole (Blokování reklam):"
echo "   URL: http://$ip_address:80"
echo "   Admin heslo: $PIHOLE_PASSWORD"
echo ""
fi)

🔧 SPRÁVA SYSTÉMU:

Zastavení všech služeb:
  cd ~/docker-stack && docker compose down

Restart služeb:
  cd ~/docker-stack && docker compose restart

Aktualizace služeb:
  ~/docker-stack/scripts/update-services.sh

Záloha dat:
  ~/docker-stack/scripts/backup-data.sh

📞 PODPORA:
Problémy reportujte na: $GITHUB_EMAIL
Repozitář: $GITHUB_REPO_URL

EOF

    log_success "Přístupové údaje uloženy do: $access_file"
}

# =============================================
# HLAVNÍ INSTALAČNÍ FUNKCE
# =============================================

main_installation() {
    clear
    echo "================================================"
    echo "  ULTIMATE RASPBERY PI 5 ALL-IN-ONE INSTALLER  "
    echo "================================================"
    echo ""
    
    # Bezpečnostní kontroly
    check_security
    check_dependencies
    check_raspberry_pi
    
    # Konfigurace
    get_github_credentials
    get_service_passwords
    
    # Základní instalace
    update_system
    install_basic_tools
    configure_git
    
    # Docker a služby
    install_docker
    setup_directories
    interactive_service_selection
    create_docker_compose
    deploy_services
    
    # Další nastavení
    optimize_system
    configure_security
    create_management_scripts
    generate_access_info
    
    # Dokončení
    log_step "INSTALACE DOKONČENA"
    
    local ip_address
    ip_address=$(hostname -I | awk '{print $1}')
    
    echo "🎉 Všechny služby byly úspěšně nainstalovány!"
    echo ""
    echo "📊 PŘEHLED SLUŽEB:"
    for service in "${selected_services[@]}"; do
        echo "   ✅ $service"
    done
    echo ""
    echo "🌐 PŘÍSTUPOVÉ ÚDAJE:"
    echo "   Soubor: ~/docker-stack/ACCESS_INFO.txt"
    echo "   IP adresa: $ip_address"
    echo ""
    echo "🔧 DALŠÍ KROKY:"
    echo "   1. Pro aplikování Docker skupiny se odhlaste a přihlaste"
    echo "   2. Přístupové údaje najdete v ACCESS_INFO.txt"
    echo "   3. Management skripty jsou v ~/docker-stack/scripts/"
    echo ""
    
    read -p "Chcete systém restartovat? (doporučeno) (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restartování systému..."
        sudo reboot
    fi
}

# =============================================
# SPUŠTĚNÍ SKRIPTU
# =============================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        "--help"|"-h")
            echo "Použití: $0 [option]"
            echo "Options:"
            echo "  --help     Zobrazení nápovědy"
            echo "  --info     Informace o skriptu"
            echo "  --quick    Rychlá instalace (všechny služby)"
            echo ""
            echo "Příklad: $0 --quick"
            ;;
        "--info")
            echo "Ultimate Raspberry Pi 5 Installer v2.0"
            echo "Kompletní automatický instalační systém"
            echo "Autor: $GITHUB_USERNAME"
            ;;
        "--quick")
            # Rychlá instalace s výchozími hodnotami
            selected_services=("Portainer" "Heimdall" "Nextcloud" "Vaultwarden" "Jellyfin" "Home Assistant" "Pi-hole")
            main_installation
            ;;
        *)
            main_installation
            ;;
    esac
fi    fi
    
    if ! command -v curl &> /dev/null; then
        sudo apt update && sudo apt install -y curl wget
    fi
}

# 🐳 INSTALACE DOCKERU
install_docker() {
    log "Instalace Docker Engine..."
    
    # Odstranění starých verzí
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Instalace závislostí
    sudo apt update
    sudo apt install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Přidání oficiálního GPG klíče
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Nastavení repozitáře
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Instalace Dockeru
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Přidání uživatele do skupiny docker
    sudo usermod -aG docker $USER
    log "Docker úspěšně nainstalován. Pro aplikování změn se odhlaste a přihlaste."
}

# 📁 PŘÍPRAVA ADRESÁŘŮ
setup_directories() {
    log "Příprava adresářové struktury..."
    
    mkdir -p ~/docker-stack/{config,data,backups}
    mkdir -p ~/docker-stack/config/{portainer,heimdall,nextcloud,vaultwarden,jellyfin,homeassistant,pihole,monitoring}
    mkdir -p ~/docker-stack/data/{media,downloads,documents,backups}
    
    log "Adresářová struktura vytvořena"
}

# 🛠️ VYTVOŘENÍ DOCKER-COMPOSE.SH
create_docker_compose() {
    cat > ~/docker-stack/docker-compose.yml << 'EOF'
version: '3.8'

services:
  # 🎯 SPRÁVA SYSTÉMU
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports: ["9000:9000"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./config/portainer:/data
    networks: [pi5-network]

  # 📊 MONITORING
  glances:
    image: nicolargo/glances:latest
    container_name: glances
    restart: unless-stopped
    ports: ["61208:61208"]
    volumes: [/var/run/docker.sock:/var/run/docker.sock:ro]
    networks: [pi5-network]

  # 🏠 DASHBOARD
  heimdall:
    image: lscr.io/linuxserver/heimdall:latest
    container_name: heimdall
    restart: unless-stopped
    ports: ["8080:80"]
    environment: {TZ: Europe/Prague, PUID: 1000, PGID: 1000}
    volumes: [./config/heimdall:/config]
    networks: [pi5-network]

  # ☁️ CLOUDOVÉ ÚLOŽIŠTĚ
  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    restart: unless-stopped
    ports: ["8081:80"]
    environment: {TZ: Europe/Prague}
    volumes: [./config/nextcloud:/var/www/html, ./data/documents:/var/www/html/data/documents]
    networks: [pi5-network]

  # 🔐 SPRÁVCE HESEL
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    ports: ["8082:80"]
    environment: {WEBSOCKET_ENABLED: "true", SIGNUPS_ALLOWED: "false"}
    volumes: [./config/vaultwarden:/data]
    networks: [pi5-network]

  # 🎬 MEDIÁLNÍ SERVER
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    ports: ["8096:8096"]
    environment: {TZ: Europe/Prague}
    volumes: [./config/jellyfin:/config, ./data/media:/media]
    networks: [pi5-network]

  # 🏡 CHYTRÁ DOMÁCNOST
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    ports: ["8123:8123"]
    environment: {TZ: Europe/Prague}
    volumes: [./config/homeassistant:/config, /etc/localtime:/etc/localtime:ro]
    networks: [pi5-network]

  # 🛡️ BLOKOVÁNÍ REKLAM
  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    restart: unless-stopped
    ports: ["53:53/tcp", "53:53/udp", "80:80"]
    environment: {TZ: Europe/Prague, WEBPASSWORD: change_this_password}
    volumes: [./config/pihole/etc-pihole:/etc/pihole, ./config/pihole/etc-dnsmasq.d:/etc/dnsmasq.d]
    networks: [pi5-network]

networks:
  pi5-network:
    driver: bridge
EOF

    log "Hlavní docker-compose.yml vytvořen"
}

# ⚙️ INTERAKTIVNÍ KONFIGURÁTOR
interactive_configurator() {
    log "Spouštím interaktivní konfigurátor..."
    
    # Výběr služeb
    echo "Vyberte služby k instalaci:"
    services=("Portainer" "Heimdall" "Nextcloud" "Vaultwarden" "Jellyfin" "Home Assistant" "Pi-hole")
    selected_services=()
    
    for service in "${services[@]}"; do
        read -p "Nainstalovat $service? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            selected_services+=("$service")
        fi
    done
    
    # Konfigurace hesel
    read -s -p "Zadejte heslo pro Pi-hole admin rozhraní: " pihole_password
    echo
    read -s -p "Zadejte heslo pro Vaultwarden: " vaultwarden_password
    echo
    
    # Aktualizace docker-compose s hesly
    sed -i "s/change_this_password/$pihole_password/" ~/docker-stack/docker-compose.yml
    
    log "Konfigurace dokončena. Vybráno služeb: ${#selected_services[@]}"
}

# 🚀 SPUŠTĚNÍ SLUŽEB
deploy_services() {
    log "Spouštím všechny služby..."
    cd ~/docker-stack
    
    # Vytvoření Docker network
    docker network create $DOCKER_NETWORK 2>/dev/null || true
    
    # Spuštění služeb
    docker-compose up -d
    
    # Čekání na start služeb
    sleep 10
    
    # Kontrola stavu
    log "Kontrola stavu kontejnerů..."
    docker-compose ps
}

# 📊 GENEROVÁNÍ PŘÍSTUPOVÝCH ÚDAJŮ
generate_access_info() {
    local ip_address=$(hostname -I | awk '{print $1}')
    
    cat > ~/docker-stack/ACCESS_INFO.txt << EOF
=== RASPBERRY PI 5 ALL-IN-ONE SYSTEM ===
Datum instalace: $(date)
IP adresa: $ip_address

📋 PŘÍSTUPOVÉ ÚDAJE:

🛠️  Portainer (Správa kontejnerů):
   URL: http://$ip_address:9000
   Poznámka: První přihlášení vytvoří admin účet

📊 Heimdall (Dashboard):
   URL: http://$ip_address:8080

☁️  Nextcloud (Cloudové úložiště):
   URL: http://$ip_address:8081
   Poznámka: První přihlášení vytvoří admin účet

🔐 Vaultwarden (Správce hesel):
   URL: http://$ip_address:8082
   Poznámka: Registrace nových účtů je vypnutá

🎬 Jellyfin (Mediální server):
   URL: http://$ip_address:8096

🏠 Home Assistant (Chytrá domácnost):
   URL: http://$ip_address:8123

🛡️  Pi-hole (Blokování reklam):
   URL: http://$ip_address:80
   Admin heslo: $(grep WEBPASSWORD ~/docker-stack/docker-compose.yml | cut -d: -f2 | tr -d ' "')

📈 Glances (Monitoring):
   URL: http://$ip_address:61208

🔧 SPRÁVA SYSTÉMU:

Zastavení všech služeb:
  cd ~/docker-stack && docker-compose down

Restart služeb:
  cd ~/docker-stack && docker-compose restart

Aktualizace všech služeb:
  cd ~/docker-stack && docker-compose pull && docker-compose up -d

Záloha dat:
  cp -r ~/docker-stack/config ~/docker-stack/backups/config_\$(date +%Y%m%d)

EOF

    log "Přístupové údaje uloženy do: ~/docker-stack/ACCESS_INFO.txt"
}

# 🔄 SKRIPT PRO AKTUALIZACI
create_update_script() {
    cat > ~/docker-stack/update-services.sh << 'EOF'
#!/bin/bash
echo "Aktualizace všech služeb..."
cd ~/docker-stack
docker-compose pull
docker-compose up -d
docker system prune -f
echo "Aktualizace dokončena!"
EOF
    
    chmod +x ~/docker-stack/update-services.sh
}

# 🎯 HLAVNÍ FUNKCE
main() {
    clear
    echo "================================================"
    echo "  ULTIMATE RASPBERY PI 5 ALL-IN-ONE INSTALLER  "
    echo "================================================"
    echo ""
    
    case "${1:-}" in
        "--quick-setup")
            check_dependencies
            install_docker
            setup_directories
            create_docker_compose
            ;;
        "--config-wizard")
            interactive_configurator
            ;;
        "--deploy-all")
            deploy_services
            generate_access_info
            create_update_script
            ;;
        "--full-install")
            check_dependencies
            install_docker
            setup_directories
            create_docker_compose
            interactive_configurator
            deploy_services
            generate_access_info
            create_update_script
            ;;
        *)
            echo "Použití: $0 [option]"
            echo "Options:"
            echo "  --quick-setup    Základní instalace Dockeru a struktury"
            echo "  --config-wizard  Interaktivní konfigurace služeb"
            echo "  --deploy-all     Spuštění všech služeb"
            echo "  --full-install   Kompletní instalace (doporučeno)"
            echo ""
            echo "Příklad kompletní instalace:"
            echo "  $0 --full-install"
            exit 1
            ;;
    esac
    
    log "Instalace dokončena úspěšně!"
    echo ""
    echo "📋 Další kroky:"
    echo "1. Pro aplikování Docker skupiny se odhlaste a přihlaste"
    echo "2. Přístupové údaje najdete v ~/docker-stack/ACCESS_INFO.txt"
    echo "3. Služby jsou dostupné na IP adrese: $(hostname -I | awk '{print $1}')"
}

# 🏁 SPUŠTĚNÍ HLAVNÍ FUNKCE
main "$@"
