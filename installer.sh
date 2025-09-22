#!/bin/bash
set -e

# 📝 KONFIGURAČNÍ PROMĚNNÉ
PI_USER="starko"
PI_HOSTNAME="rpi5"
TIMEZONE="Europe/Prague"
DOCKER_NETWORK="pi5-network"

# 🎨 BARVY PRO VÝPIS
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 📊 FUNKCE PRO LOGOVÁNÍ
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[VAROVÁNÍ]${NC} $1"
}

error() {
    echo -e "${RED}[CHYBA]${NC} $1"
    exit 1
}

# 🔍 KONTROLA PRÁV A ZÁVISLOSTÍ
check_dependencies() {
    log "Kontrola závislostí a oprávnění..."
    
    if [[ $EUID -eq 0 ]]; then
        error "Skript nesmí být spuštěn jako root. Použijte běžného uživatele."
    fi
    
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