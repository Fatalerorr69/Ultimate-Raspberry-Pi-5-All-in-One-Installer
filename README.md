# 🍃 Ultimate Raspberry Pi 5 All-in-One Installer

**Kompletní automatický instalační systém pro Raspberry Pi 5 s jednotným webovým rozhraním**

## 📋 Obsah
- [🌟 Funkce](#-funkce)
- [🛠️ Požadavky](#-požadavky)
- [🚀 Rychlý start](#-rychlé-spuštění)
- [📦 Instalované služby](#-instalované-služby)
- [🔧 Podrobná instalace](#-podrobný-instalační-manuál)
- [🌐 Přístup ke službám](#-přístup-ke-službám)
- [⚙️ Konfigurace](#-konfigurace)
- [🔄 Správa systému](#-správa-systému)
- [❌ Řešení problémů](#-řešení-problémů)
- [📞 Podpora](#-podpora)

## 🌟 Funkce

- **🎯 Jednoduchá instalace** - Jedním příkazem spustíte kompletní systém
- **🌐 Jednotné webové rozhraní** - Všechny služby přístupné přes hlavní dashboard
- **🐳 Docker-based architektura** - Izolované a snadno spravovatelné služby
- **📊 Komplexní monitoring** - Přehled o výkonu a stavu systému
- **🔒 Automatické aktualizace** - Watchtower se stará o aktuálnost kontejnerů
- **📱 Responzivní design** - Přístup z jakéhokoli zařízení

## 🛠️ Požadavky

### Hardware
- **Raspberry Pi 5** (doporučeno 8GB RAM)
- **Aktivní chlazení** - povinné pro stabilní provoz
- **SSD disk přes USB 3.0** nebo kvalitní microSD karta (min. 32GB)
- **Napájecí zdroj 5V/5A**
- **Ethernet připojení** nebo stabilní Wi-Fi

### Software
- **Raspberry Pi OS (64-bit)** - Bookworm nebo novější
- **Připojení k internetu** - pro stažení Docker imagí

## 🚀 Rychlé spuštění

```bash
# Stažení a spuštění instalačního skriptu
curl -sSL https://raw.githubusercontent.com/Fatalerorr69/Ultimate-Raspberry-Pi-5-All-in-One-Installer/main/installer.sh | bash -s -- --full-install
📦 Instalované služby
Služba	Port	Popis
Heimdall Dashboard	8080	Hlavní úvodní stránka s přístupem ke všem službám
Portainer	9000	Správa Docker kontejnerů a imagí
Home Assistant	8123	Centrum chytré domácnosti a automatizace
Nextcloud	8081	Osobní cloudové úložiště a kancelářský balík
Jellyfin	8096	Mediální server pro filmy, seriály a hudbu
Vaultwarden	8082	Správce hesel (Bitwarden kompatibilní)
Pi-hole	80	Síťové blokování reklam a trackerů
Glances	61208	Monitorování výkonu systému v reálném čase
🔧 Podrobný instalační manuál
Krok 1: Příprava Raspberry Pi OS
bash
# Stažení Raspberry Pi Imager z https://www.raspberrypi.com/software/
# Instalace 64-bit OS s předkonfigurací SSH a Wi-Fi
Krok 2: Stažení a spuštění instalačního skriptu
bash
# Klonování repozitáře
git clone https://github.com/Fatalerorr69/Ultimate-Raspberry-Pi-5-All-in-One-Installer.git
cd Ultimate-Raspberry-Pi-5-All-in-One-Installer

# Kompletní instalace
./installer.sh --full-install
🌐 Přístup ke službám
Po instalaci jsou služby dostupné na:

Dashboard: http://vaše-ip:8080

Správa kontejnerů: http://vaše-ip:9000

Blokování reklam: http://vaše-ip:80

Zjištění IP adresy: hostname -I

⚙️ Konfigurace
Základní nastavení
Pi-hole: Nastavte v routeru DNS na IP Raspberry Pi

Home Assistant: První přihlášení vytvoří administrátorský účet

Nextcloud: Vytvořte účet při prvním přístupu

🔄 Správa systému
bash
# Aktualizace všech služeb
~/docker-stack/update-services.sh

# Záloha konfigurace
cp -r ~/docker-stack/config ~/docker-stack/backups/config_$(date +%Y%m%d)

# Monitorování výkonu
htop
vcgencmd measure_temp
❌ Řešení problémů
Běžné problémy
Služby se nespustí:

bash
docker-compose logs [název-sluzby]
Nelze přistupovat ke službám:

bash
docker-compose ps
sudo netstat -tulpn | grep LISTEN
