# 📦 Serveur Backup (VLAN 40) - Documentation Technique

Serveur dédié à la centralisation et la sécurisation des sauvegardes.
Il fonctionne en mode **"PULL"** (Tirer) : c'est lui qui initie la connexion vers le Web (DMZ) pour récupérer les données.
Si le Web est compromis, le Backup reste inaccessible (car le Web ne peut pas initier de connexion vers le Backup).

---

## 🗺️ Fiche Identité

| Paramètre | Valeur |
| :--- | :--- |
| **IP** | `192.168.40.100` (Statique) |
| **Passerelle** | `192.168.40.1` (pfSense) |
| **VLAN** | **40** (BACKUP) |
| **Rôle** | Centralisation des archives + Historique |
| **OS** | Ubuntu Server |

---

## 🌳 Arborescence des Fichiers Clés

```text
/
├── etc/
│   ├── netplan/              # Config Réseau (IP Statique VLAN 40)
│   ├── postfix/              # Config SMTP (Relais Gmail)
│   └── cron.d/               # Planification
├── root/
│   └── .ssh/                 # 🔑 Clés SSH (Privée) pour se connecter au Web
├── usr/local/bin/
│   └── pull_backup.sh        # 🧲 Script principal (Rsync over SSH)
└── backup/
    └── centralized_archives/ # 🗄️ Stockage final des archives (.tar.gz + .enc)
````

-----

## 📄 CODE SOURCE DU SCRIPT

### Script Pull Backup (`/usr/local/bin/pull_backup.sh`)

*Ce script se connecte au serveur Web, aspire le dossier `/backup/` distant et l'enregistre localement.*

```bash
#!/bin/bash

# --- CONFIGURATION ---
REMOTE_USER="lsblk2exa"
REMOTE_IP="192.168.10.10"
REMOTE_DIR="/backup/"          # On récupère tout (System + Mongo Chiffré)
LOCAL_DIR="/backup/centralized_archives/"
LOG_FILE="/var/log/pull_backup.log"
EMAIL="ton_email@gmail.com"
RETENTION_DAYS=30              # On garde 1 mois d'historique ici (Stockage long terme)

# --- DÉBUT ---
echo "--- Début Récupération Archives (PULL) : $(date) ---" > "$LOG_FILE"
mkdir -p "$LOCAL_DIR"

# --- RSYNC (PULL) ---
# Option -e "ssh" : Utilise la clé SSH root -> user distant
# Option --delete : Miroir strict (ce qui est supprimé là-bas est supprimé ici... 
# ATTENTION : Si on veut garder l'historique que le Web supprime, enlever --delete)
if rsync -avzh --delete -e "ssh -p 22" "$REMOTE_USER@$REMOTE_IP:$REMOTE_DIR" "$LOCAL_DIR" >> "$LOG_FILE" 2>&1; then
    
    # --- SUCCÈS ---
    echo "[OK] Synchronisation terminée." >> "$LOG_FILE"
    STATUS="OK"
    SUBJECT="[SUCCES] Backup PULL (VLAN 40)"
    
    # Nettoyage local des très vieux fichiers (> 30 jours)
    find "$LOCAL_DIR" -type f -mtime +$RETENTION_DAYS -delete >> "$LOG_FILE" 2>&1
    
else
    # --- ERREUR ---
    echo "[ERREUR] Échec du transfert Rsync." >> "$LOG_FILE"
    STATUS="FAIL"
    SUBJECT="[ERREUR] Backup PULL (VLAN 40)"
fi

# --- NOTIFICATION ---
# On envoie les logs par mail
tail -n 20 "$LOG_FILE" | mail -s "$SUBJECT" "$EMAIL"

exit 0
```

-----

## 🚀 Installation & Commandes Utiles

### 1\. Configuration Réseau (Netplan)

Fichier `/etc/netplan/00-installer-config.yaml` :

```yaml
network:
  ethernets:
    ens18:
      addresses:
      - 192.168.40.100/24
      nameservers:
        addresses:
        - 1.1.1.1
        - 8.8.8.8
      routes:
      - to: default
        via: 192.168.40.1
  version: 2
```

*Appliquer avec `sudo netplan apply`.*

### 2\. Échange de Clés SSH (Sans mot de passe)

Le serveur Backup (Root) doit pouvoir entrer chez Web (User) :

```bash
# Générer la clé sur Backup
sudo ssh-keygen -t rsa

# Envoyer la clé vers Web (nécessite le mot de passe Web une fois)
sudo ssh-copy-id lsblk2exa@192.168.10.10
```

### 3\. Installation des paquets

```bash
sudo apt update
sudo apt install -y rsync mailutils postfix libsasl2-modules
```

-----

## ⚙️ Automatisation (Crontab)

Le serveur Web fait ses backups à **00h20** et **14h00**.
Le serveur Backup doit passer **APRÈS** pour les récupérer (ex: 1h00 et 15h00).

Éditer avec `sudo crontab -e` :

```bash
# Récupération des archives (1h du matin)
0 1 * * * /usr/local/bin/pull_backup.sh

# Récupération des archives (15h00)
0 15 * * * /usr/local/bin/pull_backup.sh
```

-----

## 🛡️ Sécurité & Pare-Feu

Ce serveur est isolé.

  * **Entrée :** Seul le SSH depuis le LAN Admin (via pfSense) est autorisé.
  * **Sortie :**
      * Vers **Web (DMZ)** : Port 22 (SSH) uniquement.
      * Vers **Internet** : Ports 80/443 (Updates) et 587 (SMTP Gmail).

-----

## 📝 Check-list Maintenance

  - [ ] Vérifier l'espace disque (`df -h`). Ce serveur va se remplir plus vite que les autres car il garde 30 jours.
  - [ ] Vérifier que les mails de "Succès" arrivent bien deux fois par jour.
  - [ ] Une fois par mois, tenter de déchiffrer une archive stockée ici pour valider qu'elle n'est pas corrompue.

