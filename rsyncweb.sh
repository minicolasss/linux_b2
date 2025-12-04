#!/bin/bash
# regle crontab
# sudo crontab -e
# 0 2,14 * * * PATH=/usr/bin:/bin:/usr/sbin:/sbin /home/<user>/rsyncweb.sh

# =============== PATCH =====================
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin



# ================= CONFIGURATION =================
DISCORD_WEBHOOK_URL="Token_a_remplacer_par_votre_webhook"
SOURCE=(
    "/var/www"
    "/home"
)
DESTINATION="/backup"
LOGFILE="/var/log/rsyncweb.log"
DATE_LOG=$(date +"%Y-%m-%d %H:%M:%S")
DATE_FILE=$(date +"%Y-%m-%d_%H-%M-%S")
RETENTION=7 

BACKUP_NAME="web_${DATE_FILE}"
CURRENT_BACKUP="$DESTINATION/$BACKUP_NAME"
LATEST_LINK="$DESTINATION/latest"



# ================= FONCTIONS =================
# Fonction de log
log() {
echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

# Fonction d'envoi Discord
send_discord() {
    local message="$1"
    local color="$2"

curl -H "Content-Type: application/json" \
         -X POST \
         -d "{
               \"embeds\": [{
                 \"title\": \"Sauvegarde Serveur\",
                 \"description\": \"$message\",
                 \"color\": $color
               }]
             }" \
         "$DISCORD_WEBHOOK_URL" > /dev/null 2>&1
}



# ================= SCRIPT =================
log "=== Début de la sauvegarde ==="
mkdir -p "$DESTINATION"

# Exécution de la commande rsync avec options
if rsync -avz --delete \
    --exclude='*.log' \
    --exclude='cache/' \
    --link-dest="$LATEST_LINK" \
    "${SOURCE[@]}" "$CURRENT_BACKUP"; then

    # --- SUCCÈS ---
    log "Sauvegarde réussie: $CURRENT_BACKUP"
    
    # Mise à jour du lien 'latest'
    rm -f "$LATEST_LINK"
    ln -s "$CURRENT_BACKUP" "$LATEST_LINK"

    # Nettoyage (On cherche les dossiers qui commencent par web_)
    find "$DESTINATION" -maxdepth 1 -mindepth 1 -type d -name "web_*" -mtime +$RETENTION -exec rm -rf {} \;
    log "Nettoyage des sauvegardes > $RETENTION jours effectué."

    send_discord "✅ **Succès**\nLa sauvegarde a été effectuée avec succès.\nDossier: \`$BACKUP_NAME\`" "3066993"

else
    # --- ÉCHEC ---
    log "ERREUR: Échec de la commande rsync"
    send_discord "❌ **Erreur Critique**\nLa sauvegarde a échoué ! Veuillez vérifier les logs sur le serveur." "15158332"
    exit 1
fi

log "=== Fin de la sauvegarde ==="