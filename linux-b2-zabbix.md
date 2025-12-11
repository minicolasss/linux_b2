# 📡 Documentation Infrastructure Zabbix

Mise en place d'une architecture de supervision centralisée avec **Zabbix 7.4** sur Ubuntu 24.04.

## 1. Installation du Serveur Zabbix (Master)

Commandes pour installer le dépôt officiel Zabbix 7.4 et les composants serveur :

```bash
# 1. Télécharger et installer le dépôt Zabbix
wget [https://repo.zabbix.com/zabbix/7.4/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.4+ubuntu24.04_all.deb](https://repo.zabbix.com/zabbix/7.4/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.4+ubuntu24.04_all.deb)
dpkg -i zabbix-release_latest_7.4+ubuntu24.04_all.deb
apt update

# 2. Installer le serveur, le frontend et l'agent
apt install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent
````

-----

## 2\. Déploiement d'un Agent (Sur les machines à surveiller)

Pour ajouter un nouveau serveur (Web, Backup, etc.) à la supervision :

### A. Installation

```bash
# Installer le dépôt (si ce n'est pas déjà fait)
wget [https://repo.zabbix.com/zabbix/7.4/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.4+ubuntu24.04_all.deb](https://repo.zabbix.com/zabbix/7.4/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.4+ubuntu24.04_all.deb)
dpkg -i zabbix-release_latest_7.4+ubuntu24.04_all.deb
apt update

# Installer l'agent uniquement
apt install zabbix-agent
```

### B. Sécurité : Génération de la clé PSK (Chiffrement)

Nous utilisons une clé pré-partagée (PSK) pour chiffrer les échanges entre le serveur et l'agent.

1.  **Générer la clé** sur la machine agent :

    ```bash
    openssl rand -hex 32 > /etc/zabbix/zabbix_agentd.psk
    chmod 640 /etc/zabbix/zabbix_agentd.psk
    chown root:zabbix /etc/zabbix/zabbix_agentd.psk
    ```

2.  **Afficher la clé** (à copier dans l'interface Web Zabbix) :

    ```bash
    cat /etc/zabbix/zabbix_agentd.psk
    ```

### C. Configuration de l'Agent

Éditer le fichier `/etc/zabbix/zabbix_agentd.conf` :

```ini
# Adresse IP du Serveur Zabbix (Master)
Server=192.168.50.10
ServerActive=192.168.50.10

# Nom de la machine locale (Doit être identique dans l'interface Web Zabbix)
Hostname=Server-Backup  # (Adapter selon la machine : Serveur-Web, etc.)

# Configuration du chiffrement PSK
TLSConnect=psk
TLSAccept=psk
TLSPSKIdentity=PSK_Server_Backup  # (Identifiant unique à choisir)
TLSPSKFile=/etc/zabbix/zabbix_agentd.psk
```

3.  **Redémarrer l'agent** :
    ```bash
    systemctl restart zabbix-agent
    ```

-----

## 3\. Inventaire & Flux Réseau

### Liste des Agents Déployés

| Rôle | Hostname (Zabbix) | IP Agent | OS | État |
| :--- | :--- | :--- | :--- | :--- |
| **Serveur de Supervision** | `Zabbix-Server` | **192.168.50.10** | Ubuntu 24.04 | ✅ Master |
| **Serveur Web** | `Serveur-Web` | **192.168.10.10** | Linux | ✅ Actif |
| **Serveur de Backup** | `Server-Backup` | **192.168.40.100** | Linux | ✅ Actif |

### Règles Firewall (Flux)

Le serveur Zabbix doit pouvoir initier des connexions vers les agents sur le port TCP/10050.

| Source IP (Zabbix) | Destination IP (Agent) | Port | Protocole | Action | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `192.168.50.10` | `192.168.10.10` | 10050 | TCP | ALLOW | Supervision Web |
| `192.168.50.10` | `192.168.40.100` | 10050 | TCP | ALLOW | Supervision Backup |

```