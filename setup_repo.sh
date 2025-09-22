#!/bin/bash

# Název existujícího adresáře projektu (lze upravit)
PROJECT_NAME="Ultimate-Raspberry-Pi-5-All-in-One-Installer"
# Popis repozitáře
DESCRIPTION="Kompletní automatický instalační systém pro Raspberry Pi 5 s interaktivním konfigurátorem"

# Tvůj GitHub username
GITHUB_USERNAME="Fatalerorr69"

# Cesta k projektu (předpokládá, že skript běší z kořene projektu)
PROJECT_PATH=$(pwd)

echo "Začínám automatickou konfiguraci repozitáře pro: $PROJECT_NAME"
echo "Cesta k projektu: $PROJECT_PATH"

# Přesun do adresáře projektu
cd "$PROJECT_PATH"

# Inicializace git repozitáře (pokud již neexistuje)
if [ ! -d ".git" ]; then
    git init
    echo "Inicializován nový git repozitář."
else
    echo "Git repozitář již byl inicializován."
fi

# Přidání všech souborů do staging area (můžeš upravit např. pouze 'git add README.md installer.sh')
git add .

# Vytvoření počátečního commitu
git commit -m "Initial commit: $DESCRIPTION"

# Vytvoření repozitáře na GitHubu pomocí API
# DŮLEŽITÉ: Místo hesla nyní GitHub vyžaduje osobní přístupový token (Personal Access Token)
# Token si vygeneruj zde: https://github.com/settings/tokens
# Potřebuje oprávnění "repo"
echo "Pro pokračování je potřeba osobní přístupový token (PAT) s oprávněním 'repo'."
echo "Můžeš ho vygenerovat na: https://github.com/settings/tokens"
echo "Z bezpečnostních důvodů ho skript neukládá. Zadej ho prosím při výzvě."
read -s -p "Tvůj GitHub PAT: " GITHUB_TOKEN
echo

# Vytvoření repozitáře na GitHubu
API_JSON=$(printf '{"name": "%s", "description": "%s", "private": false, "auto_init": false}' "$PROJECT_NAME" "$DESCRIPTION")
curl -u "$GITHUB_USERNAME:$GITHUB_TOKEN" https://api.github.com/user/repos -d "$API_JSON"

# Propojení lokálního repozitáře s remote repozitářem na GitHubu
git remote add origin "https://github.com/$GITHUB_USERNAME/$PROJECT_NAME.git"

# První push na GitHub
git branch -M main
git push -u origin main

echo "Hotovo! Repozitář je veřejně dostupný na: https://github.com/$GITHUB_USERNAME/$PROJECT_NAME"