# 🛡️ pfSense - Documentation Infrastructure Réseau

Ce document décrit la configuration du routeur/pare-feu pfSense central.
Il assure la segmentation (VLANs), le routage, et la sécurité entre le Web (DMZ), les Backups (Secure) et l'Administration (LAN).


## 🗺️ Topologie Réseau & VLANs

L'interface LAN physique (`vtnet1` ou `vmx1`) porte tous les VLANs (Trunk).

| Zone | Interface | VLAN ID | CIDR (IP Pare-feu) | Description |
| :--- | :--- | :---: | :--- | :--- |
| **WAN** | `wan` | - | DHCP / IP Publique | Connexion Internet |
| **LAN** | `lan` | - | `192.168.1.1/24` | Réseau d'Administration (PC Admin) |
| **DMZ** | `opt1` | **10** | `192.168.10.1/24` | Serveur Web Public (Nginx/Mongo) |
| **BACKUP** | `opt2` | **40** | `192.168.40.1/24` | Serveur de Sauvegarde Isolé |
| **VPN** | `ovpns1` | - | `10.0.8.0/24` | Accès distant (OpenVPN) |

---

## 🔥 Règles de Pare-Feu (Firewall Rules)

La logique est : **"Tout ce qui n'est pas explicitement autorisé est interdit"**.

### 1. Interface WAN
| Action | Proto | Source | Port | Destination | Port | Description |
| :---: | :---: | :--- | :---: | :--- | :---: | :--- |
| ❌ | * | * | * | * | * | *Block All (Défaut)* |
| ✅ | UDP | * | * | WAN Address | 1194 | **Allow OpenVPN Access** |
| ✅ | TCP | * | * | 192.168.10.10 | 80/443 | **NAT Web Server** (Géré par NAT) |

### 2. Interface LAN (Admin)
| Action | Proto | Source | Port | Destination | Port | Description |
| :---: | :---: | :--- | :---: | :--- | :---: | :--- |
| ✅ | * | LAN net | * | * | * | **Anti-Lockout Rule** (Toujours en haut) |
| ✅ | * | LAN net | * | * | * | **Allow LAN to Any** (Accès total) |

### 3. Interface DMZ (VLAN 10)
*Zone exposée : Sécurité maximale. Ne doit jamais initier de connexion vers le LAN ou le BACKUP.*

| Action | Proto | Source | Port | Destination | Port | Description |
| :---: | :---: | :--- | :---: | :--- | :---: | :--- |
| ❌ | * | DMZ net | * | LAN net | * | **BLOCK DMZ vers LAN** (Sécurité Critique) |
| ❌ | * | DMZ net | * | BACKUP net | * | **BLOCK DMZ vers BACKUP** (Anti-Ransomware) |
| ✅ | UDP | DMZ net | * | DMZ Address | 53 | **Allow DNS** (Vers pfSense) |
| ✅ | TCP | DMZ net | * | * | 80/443 | **Allow Updates** (Apt/Curl vers Internet) |

### 4. Interface BACKUP (VLAN 40)
*Zone sécurisée : Doit "tirer" (Pull) les données.*

| Action | Proto | Source | Port | Destination | Port | Description |
| :---: | :---: | :--- | :---: | :--- | :---: | :--- |
| ❌ | * | BACKUP net | * | LAN net | * | **BLOCK BACKUP vers LAN** |
| ✅ | TCP | BACKUP net | * | 192.168.10.10 | 22 | **Allow SSH PULL** (Backup -> Web) |


### 5. Interface OpenVPN
| Action | Proto | Source | Port | Destination | Port | Description |
| :---: | :---: | :--- | :---: | :--- | :---: | :--- |
| ✅ | * | * | * | * | * | **Allow VPN to Any** (Admin distant) |

---

## 🌐 NAT & Port Forwarding

Redirection des ports pour rendre le site accessible depuis l'extérieur.

* **Location :** Firewall > NAT > Port Forward
* **Règle :**
    * **Interface :** WAN
    * **Protocol :** TCP
    * **Dest. Port :** 80 (HTTP)
    * **Redirect Target IP :** `192.168.10.10` (Serveur Web)
    * **Redirect Target Port :** 80

*(Faire de même pour le port 443 HTTPS si SSL est activé).*

---

## 📡 Services

### 1. DHCP Server
Activé sur LAN, DMZ et BACKUP.
* **DMZ Range :** `.100` à `.200`.
* **Static Mappings :**
    * Serveur Web : `192.168.10.10`
    * Serveur Backup : `192.168.40.100`

### 2. DNS Resolver (Unbound)
* **Location :** Services > DNS Resolver
* **Config :**
    * Enable DNS Resolver : ✅
    * Network Interfaces : All (ou LAN/DMZ/BACKUP/Localhost)
    * Register DHCP leases : ✅ (Permet de résoudre les noms de machines)

### 3. OpenVPN (Remote Access)
* **Server Mode :** Remote Access (User Auth + TLS)
* **Tunnel Network :** `10.0.8.0/24`
* **Local Networks :** `192.168.1.0/24, 192.168.10.0/24, 192.168.40.0/24` (Pour accéder à tout).
* **Client Export :** Utiliser le package `openvpn-client-export` pour générer les `.ovpn`.

---

## ⚙️ Maintenance & Sauvegarde Config

### Sauvegarder la configuration pfSense
* **Menu :** Diagnostics > Backup & Restore.
* **Action :** Télécharger le fichier `.xml` (incluant les données RRD pour les graphiques).
* **Fréquence :** À chaque modification des règles Firewall.

### En cas d'urgence
Si vous vous enfermez dehors (Anti-Lockout désactivé par erreur) :
1. Accéder à la console VM via Proxmox.
2. Choisir l'option **8) Shell**.
3. Taper : `pfSsh.php playback enableallowallwan` (Ouvre temporairement le WAN) ou restaurer une config précédente via l'option **15**.