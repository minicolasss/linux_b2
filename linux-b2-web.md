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