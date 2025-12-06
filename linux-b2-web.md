# Conf serveur ubuntu 

## ip 

```bash
ip a
ens18

ls /etc/netplan/
...

sudo nano /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens18:
      dhcp4: no
      addresses:
        - 192.168.10.10/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
```

## ufw

```zsh
sudo ufw allow 'Nginx HTTP'
sudo ufw allow 'Nginx HTTPS'
sudo ufw allow 'OpenSSH'
sudo ufw enable
```

## conf HTTPS

```zsh
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt

sudo nano /etc/nginx/sites-available/b2-linux-web

# Bloc pour rediriger HTTP (Port 80) vers HTTPS (Port 443)
server {
    listen 80;
    server_name b2-linux-web.lan;
    return 301 https://$host$request_uri;
}

# Bloc principal HTTPS
server {
    listen 443 ssl;
    server_name b2-linux-web.lan;

    # Chemins vers les certificats générés à l'étape 1
    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;

    # Paramètres SSL de base (sécurité)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Dossier de ton site web
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

## sauvegarde

# grosse sauvegarde
###  1. INSTALLATION DES PRÉREQUIS

```zsh
sudo apt update
sudo apt install rsync mailutils libsasl2-modules libsasl2-modules-db sasl2-bin
```

### 2. CONFIGURATION GMAIL (Relais SMTP)

A. Obtenir le mot de passe d'application

    Aller sur le compte Google > Sécurité.

    Activer la "Validation en deux étapes".

    Aller dans "Mots de passe des applications".

    Créer un mot de passe pour "Serveur Linux" et copier le code de 16 lettres.


B. Configurer Postfix

Créer le fichier de mot de passe :
```zsh
sudo nano /etc/postfix/sasl_passwd
[smtp.gmail.com]:587    TON_ADRESSE@gmail.com:TON_MOT_DE_PASSE_16_LETTRES

sudo chmod 600 /etc/postfix/sasl_passwd
sudo postmap /etc/postfix/sasl_passwd
```

Modifier la configuration principale :
```zsh
sudo nano /etc/postfix/main.cf

relayhost = [smtp.gmail.com]:587
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_security_options = noanonymous
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
inet_protocols = ipv4
```
Redémarrer Postfix :
```zsh
sudo systemctl restart postfix
```

### 3. LE SCRIPT DE SAUVEGARDE
Fichier : **/usr/local/bin/full_backup.sh**
```zsh
#!/bin/bash

# --- CONFIGURATION ---
BACKUP_DIR="/backup/system"
DATE=$(date +%Y-%m-%d_%Hh%M)
FILENAME="backup-srv-web-$DATE.tar.gz"
LOG_FILE="/var/log/full_backup.log"
EMAIL="TON_ADRESSE@gmail.com"
RETENTION_DAYS=7

# Création du dossier si nécessaire
mkdir -p "$BACKUP_DIR"

# --- LOG ---
echo "--- Démarrage sauvegarde complète : $(date) ---" > "$LOG_FILE"

# --- COMPRESSION DU SYSTÈME ---
# Sauvegarde la racine "/" en excluant les dossiers virtuels et le dossier de backup lui-même
tar -cvpzf "$BACKUP_DIR/$FILENAME" \
    --exclude="$BACKUP_DIR" \
    --exclude=/proc \
    --exclude=/tmp \
    --exclude=/mnt \
    --exclude=/dev \
    --exclude=/sys \
    --exclude=/run \
    --exclude=/media \
    --exclude=/var/log \
    --exclude=/swapfile \
    / >> "$LOG_FILE" 2>&1

TAR_STATUS=$?

# --- VÉRIFICATION ET MAIL ---
if [ $TAR_STATUS -eq 0 ] || [ $TAR_STATUS -eq 1 ]; then
    echo "Sauvegarde terminée avec succès : $FILENAME" >> "$LOG_FILE"
    
    # Suppression des archives de plus de 7 jours
    find "$BACKUP_DIR" -name "backup-srv-web-*.tar.gz" -mtime +$RETENTION_DAYS -exec rm {} \; >> "$LOG_FILE" 2>&1
    
    # Envoi du Mail de SUCCÈS
    SIZE=$(du -h "$BACKUP_DIR/$FILENAME" | cut -f1)
    echo "Sauvegarde complète OK. Fichier: $FILENAME. Taille: $SIZE." | mail -s "[OK] Full Backup Web Server" "$EMAIL"
else
    echo "ERREUR CRITIQUE lors de la sauvegarde." >> "$LOG_FILE"
    # Envoi du Mail d'ERREUR avec les logs
    tail -n 20 "$LOG_FILE" | mail -s "[ERREUR] Full Backup Web Server" "$EMAIL"
fi

exit 0
```

### 4. AUTOMATISATION (CRON)

Éditer le planificateur de tâches (en root) :
```zsh
sudo crontab -e

0 2 * * * /usr/local/bin/full_backup.sh
```
# petite sauvegarde

```zsh
sudo mkdir -p /backup/web_current
sudo mkdir -p /backup/web_history
```

```zsh
sudo nano /usr/local/bin/quick_rsync.sh

#!/bin/bash

# --- CONFIGURATION ---
SOURCE_DIR="/var/www/html/"
# Dossier qui contient la copie exacte du site
CURRENT_DIR="/backup/web_current/"
# Dossier qui contiendra les fichiers modifiés/supprimés (le différentiel)
HISTORY_DIR="/backup/web_history/$(date +%Y-%m-%d_%Hh%M)"
LOG_FILE="/var/log/quick_rsync.log"
EMAIL="ton_email@gmail.com"

# --- DÉBUT DU TRAITEMENT ---
echo "--- Début Rsync Rapide : $(date) ---" > "$LOG_FILE"

# Création du dossier d'historique uniquement si rsync détecte des changements
# L'option --backup-dir est magique : elle dit "avant d'écraser ou supprimer un fichier, mets l'ancienne version ici"
rsync -avbh --delete --backup --backup-dir="$HISTORY_DIR" "$SOURCE_DIR" "$CURRENT_DIR" >> "$LOG_FILE" 2>&1

RSYNC_STATUS=$?

# --- NOTIFICATION ---
if [ $RSYNC_STATUS -eq 0 ]; then
    # On vérifie si un dossier d'historique a été créé (donc s'il y a eu des changements)
    if [ -d "$HISTORY_DIR" ]; then
        CHANGE_COUNT=$(find "$HISTORY_DIR" -type f | wc -l)
        echo "Sauvegarde différentielle OK. $CHANGE_COUNT fichiers modifiés/archivés dans $HISTORY_DIR." >> "$LOG_FILE"
        SUBJECT="[INFO] Web Backup: Changements détectés"
    else
        echo "Aucun changement détecté. Synchronisation rapide terminée." >> "$LOG_FILE"
        SUBJECT="[INFO] Web Backup: Aucun changement"
    fi
    
    # Envoi du mail (seulement le résumé)
    tail -n 5 "$LOG_FILE" | mail -s "$SUBJECT" "$EMAIL"
else
    echo "ERREUR lors du Rsync." >> "$LOG_FILE"
    tail -n 20 "$LOG_FILE" | mail -s "[ERREUR] Web Rsync Failed" "$EMAIL"
fi

exit 0

sudo chmod +x /usr/local/bin/quick_rsync.sh
```


## restarte en cas de crash nginx

```zsh
sudo systemctl edit nginx

[Service]
Restart=on-failure
RestartSec=5s
```
