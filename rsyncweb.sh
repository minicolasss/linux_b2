#!/bin/bash



# ================= CONFIGURATION =================
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1446091821825654876/6eehgvlf_iDh7sjgdTeLqb81U_WyWplUCca8I_GsYmrtEmPCYI-veeK8TRHJdjXMxqRl"
SOURCE=(
    "/var/www"
    "/home"
)
DESTINATION="/backup"
LOGFILE="/var/log/rsyncweb.log"
DATE=$(date +"%Y-%m-%d %H:%M:%S")
RETENTION=7 

BACKUP_NAME=$(web_ + $DATE)
CURRENT_BACKUP="$DESTINATION/$BACKUP_NAME"
LATEST_LINK="$DESTINATION/latest"



# ================= FONCTIONS =================
# Fonction de log
log() {
    echo "[$('web_' + ($DATE))] $1" | tee -a "$LOGFILE"
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
         "$DISCORD_WEBHOOK" > /dev/null 2>&1
}



# ================= SCRIPT =================
log "=== Début de la sauvegarde ==="
mkdir -p "$DESTINATION"

if rsync -avz --delete \
    --exclude='*.log' \
    --exclude='cache/' \
    --link-dest="$LATEST_LINK" \
    "${SOURCE[@]}" "$CURRENT_BACKUP"; then
    log "Sauvegarde réussie: $CURRENT_BACKUP"
    
    # Mise à jour du lien 'latest'
    rm -f "$LATEST_LINK"
    ln -s "$CURRENT_BACKUP" "$LATEST_LINK"
    find "$DESTINATION" -maxdepth 1 -mindepth 1 -type d -name "20*" -mtime +$RETENTION -exec rm -rf {} \;
    log "Nettoyage des sauvegardes > $RETENTION jours effectué."
    send_discord "✅ **Succès**\nLa sauvegarde a été effectuée avec succès.\nDossier: \`$BACKUP_NAME\`" "3066993"

else
    log "ERREUR: Échec de la commande rsync"
    send_discord "❌ **Erreur Critique**\nLa sauvegarde a échoué ! Veuillez vérifier les logs sur le serveur." "15158332"
    exit 1
fi

log "=== Fin de la sauvegarde ==="