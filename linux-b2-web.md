# 📂 Serveur Web (DMZ) - Documentation Technique

Serveur hébergeant l'application Web et la base de données MongoDB.
Infrastructure sécurisée avec double stratégie de sauvegarde :
1. **Fast Backup :** Snapshots horaires des fichiers (Rsync).
2. **Full Backup :** Archives complètes chiffrées (AES-256) bi-quotidiennes.

## 🌳 Arborescence des Fichiers Clés

```text
/
├── etc/
│   ├── mongod.conf           # Configuration MongoDB (Auth enabled)
│   └── cron.d/               # Planification des tâches
├── root/
│   └── .backup_secrets       # 🔒 Fichier de secrets (User/Pass/Clé Chiffrement)
├── usr/local/bin/
│   ├── quick_rsync.sh        # ⚡ Script Rapide (Snapshot fichiers Web)
│   └── full_backup.sh        # 📦 Script Complet (Dump Mongo + Chiffrement + System)
└── backup/
    ├── web_current/          # Miroir exact du site (pour restauration rapide)
    ├── web_history/          # Historique des modifications (fichiers modifiés)
    ├── database/             # Dumps MongoDB chiffrés (.enc)
    └── system/               # Archives système globales (.tar.gz)
```

## 🚀 Installation & Commandes Utiles

### 1. Installation des paquets
```zsh
# Outils de base
sudo apt update && sudo apt install -y gnupg curl openssl mailutils rsync

# Installation MongoDB 7.0
curl -fsSL [https://pgp.mongodb.com/server-7.0.asc](https://pgp.mongodb.com/server-7.0.asc) | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] [https://repo.mongodb.org/apt/ubuntu](https://repo.mongodb.org/apt/ubuntu) jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

sudo apt update && sudo apt install -y mongodb-org
sudo systemctl enable --now mongod
```

### 2. Mise en place des Scripts

Les scripts quick_rsync.sh et full_backup.sh dans /usr/local/bin/ et les rendre exécutables :

```zsh
sudo chmod +x /usr/local/bin/*.sh
```
## 📄 CODES SOURCES DES SCRIPTS
1. Script Fast Backup (/usr/local/bin/quick_rsync.sh)
   
    Sauvegarde incrémentale des fichiers Web toutes les heures.

    ```zsh
    #!/bin/bash

    SOURCE_DIR="/var/www/html/"
    BACKUP_DIR="/backup/web_current"
    HISTORY_DIR="/backup/web_history/$(date +%Y-%m-%d_%Hh%M)"

    # Création des dossiers
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$HISTORY_DIR"

    # Rsync : Synchronise le dossier actuel et déplace les vieux fichiers modifiés dans history
    rsync -avb --delete --backup-dir="$HISTORY_DIR" "$SOURCE_DIR" "$BACKUP_DIR"

    # Nettoyage : On garde l'historique local 24h (le serveur backup a le reste)
    find /backup/web_history/ -type d -mtime +1 -exec rm -rf {} +
    ```
2. Script Full Backup (/usr/local/bin/full_backup.sh)
   Sauvegarde complète Système + Mongo Chiffré.
   ```zsh
   #!/bin/bash

    # --- CONFIGURATION ---
    BACKUP_DIR="/backup/system"
    DB_DIR="/backup/database"
    DATE=$(date +%Y-%m-%d_%Hh%M)
    FILENAME="backup-srv-web-$DATE.tar.gz"
    LOG_FILE="/var/log/full_backup.log"
    EMAIL="ton_email@gmail.com"
    RETENTION_DAYS=1

    # --- SECURITÉ : IMPORT DES SECRETS ---
    if [ -f /root/.backup_secrets ]; then
        source /root/.backup_secrets
    else
        echo "ERREUR : Secrets introuvables !" >> "$LOG_FILE"
        exit 1
    fi

    mkdir -p "$BACKUP_DIR" "$DB_DIR"
    echo "--- Start Backup : $(date) ---" > "$LOG_FILE"

    # --- 1. MONGODB (Chiffré AES-256) ---
    echo "[1/2] Export MongoDB..." >> "$LOG_FILE"
    if pgrep mongod > /dev/null; then
        if mongodump --authenticationDatabase admin -u "$MONGO_USER" -p "$MONGO_PASS" --archive | gzip | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -k "$BACKUP_KEY" -out "$DB_DIR/mongodb_full_$DATE.archive.gz.enc"; then
            echo "OK Mongo Encrypted." >> "$LOG_FILE"
            DB_STATUS="OK"
        else
            echo "ERREUR Mongo." >> "$LOG_FILE"
            DB_STATUS="FAIL"
        fi
    else
        echo "ERREUR : Mongo éteint." >> "$LOG_FILE"
        DB_STATUS="DOWN"
    fi

    # --- 2. SYSTÈME (TAR) ---
    echo "[2/2] Compression système..." >> "$LOG_FILE"
    tar -cvpzf "$BACKUP_DIR/$FILENAME" \
        --exclude="$BACKUP_DIR" \
        --exclude=/proc --exclude=/tmp --exclude=/mnt --exclude=/dev \
        --exclude=/sys --exclude=/run --exclude=/media --exclude=/var/log \
        /backup/database / >> "$LOG_FILE" 2>&1
    TAR_STATUS=$?

    # --- NETTOYAGE & MAIL ---
    find "$DB_DIR" -name "*.enc" -mtime +$RETENTION_DAYS -delete
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

    if [ $TAR_STATUS -eq 0 ] && [ "$DB_STATUS" == "OK" ]; then
        SIZE=$(du -h "$BACKUP_DIR/$FILENAME" | cut -f1)
        echo -e "Sauvegarde OK.\nFichier: $FILENAME\nTaille: $SIZE" | mail -s "[OK] Backup Web" "$EMAIL"
    else
        tail -n 20 "$LOG_FILE" | mail -s "[ERREUR] Backup Web" "$EMAIL"
    fi
    exit 0
    ```

    
## 🔐 Configuration des Secrets

Le fichier /root/.backup_secrets (chmod 600) contient :
```zsh
MONGO_USER="admin"
MONGO_PASS='VOTRE_MOT_DE_PASSE_MONGO'
BACKUP_KEY="VOTRE_PHRASE_PASSPHRASE_POUR_CHIFFREMENT_AES256"
```

## ⚙️ Automatisation (Crontab)

Éditer avec sudo crontab -e :
```zsh
# ⚡ FAST BACKUP : Synchronisation des fichiers Web (Toutes les heures)
0 * * * * /usr/local/bin/quick_rsync.sh

# 📦 FULL BACKUP : Système + Mongo Chiffré (00h20 et 14h00)
0 2 * * * /usr/local/bin/full_backup.sh
```

## 🆘 Procédure de Restauration (Disaster Recovery)

### Cas 1 : Erreur sur un fichier du site (PHP/HTML)

Aller chercher la version de l'heure précédente dans le dossier miroir :
```zsh
cp -r /backup/web_current/les_fichier /var/www/html/
# Ou chercher dans l'historique
ls -l /backup/web_history/
```

### Cas 2 : Perte totale de la Base de Données

Prérequis : Avoir la BACKUP_KEY et le fichier .enc.
```zsh
# Déchiffrement -> Décompression -> Importation
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -salt \
    -k "VOTRE_CLE_DE_CHIFFREMENT" \
    -in /backup/database/NOM_DU_FICHIER.archive.gz.enc \
    | gzip -d \
    | mongorestore --archive --authenticationDatabase admin -u admin -p 'VOTRE_PASS_MONGO'
```

### Cas 3 : Crash Système Total (OS Corrompu / Ne boot plus)
Scénario : Linux est cassé, écran noir au démarrage. Méthode : Utiliser un "Live CD" (ISO Ubuntu) sur la VM pour écraser le système cassé avec la sauvegarde.

1.    Démarrer la VM sur une ISO Ubuntu (Mode "Try Ubuntu").

2.    Monter le disque dur de la VM dans /mnt :
    ```zsh
    sudo mount /dev/mapper/ubuntu--vg-ubuntu--lv /mnt
    ```
3.  sudo mount /dev/mapper/ubuntu--vg-ubuntu--lv /mnt
4.  Lancer la restauration (Cela va écraser les fichiers système) :
    ```zsh
    # Option --numeric-owner est CRITIQUE pour garder les droits root/users
    sudo tar -xvpzf /mnt/backup-srv-web-DATE.tar.gz -C /mnt --numeric-owner
    ```
5.  Redémarrer : Enlever l'ISO et rebooter.