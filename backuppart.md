# Échange de clés SSH

```zsh
ssh-keygen -t rsa
ssh-copy-id lsblk2exa@192.168.10.10
```

# script
```zsh
sudo nano /usr/local/bin/pull_backup.sh

#!/bin/bash

# --- CONFIGURATION ---
REMOTE_USER="lsblk2exa"
REMOTE_IP="192.168.10.10"
# C'EST ICI QU'ON CHANGE : On prend le dossier des sauvegardes rsync distantes
REMOTE_DIR="/backup/"

# Dossier local où on stocke tout ça
LOCAL_DIR="/backup/centralized_archives/"
LOG_FILE="/var/log/pull_backup.log"

# --- DÉBUT ---
echo "--- Début Récupération Archives Rsync : $(date) ---" >> "$LOG_FILE"
mkdir -p "$LOCAL_DIR"

# --- RSYNC ---
# On aspire tout le dossier /backup distant vers ici
rsync -avzh --delete \
    -e "ssh -p 22" \
    "$REMOTE_USER@$REMOTE_IP:$REMOTE_DIR" \
    "$LOCAL_DIR" >> "$LOG_FILE" 2>&1

STATUS=$?

if [ $STATUS -eq 0 ]; then
    echo "[OK] Les archives ont été rapatriées avec succès." >> "$LOG_FILE"
else
    echo "[ERREUR] Échec du transfert." >> "$LOG_FILE"
fi
```

