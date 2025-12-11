# 🛡️ pfSense - Documentation Infrastructure Réseau

Ce document décrit la configuration du routeur/pare-feu pfSense central.
Il assure la segmentation (VLANs), le routage, et la sécurité entre le Web (DMZ), les Backups (Secure) et l'Administration (LAN).


## 🗺️ Topologie Réseau & VLANs

L'interface LAN physique (`vtnet1`) porte tous les VLANs (Trunk).
L'interface DMZ physique (`vtnet2`) .

| Zone | Interface | VLAN ID | CIDR | Description |
| :--- | :--- | :---: | :--- | :--- |
| **WAN** | `wan` | - | DHCP | Connexion Internet |
| **ADMIN** | `lan` | **1** | `192.168.1.1/24` | **Zone de Confiance**. Accès complet. |
| **DMZ** | `opt1` | **10** | `192.168.10.1/24` | Serveur Web Public (Nginx/Mongo). |
| **EMPLOYEE**| `opt3` | **20** | `192.168.20.1/24` | **Zone Utilisateurs**. Internet uniquement. |
| **BACKUP** | `opt2` | **40** | `192.168.40.1/24` | Serveur de Sauvegarde Isolé. |
| **MONITOR** | `opt4` | **50** | `192.168.50.1/24` | Serveur Zabbix (Supervision). |

---

## 🔥 Règles de Pare-Feu (Firewall Rules)

La logique est : **"Tout ce qui n'est pas explicitement autorisé est interdit"**.

### 1. Interface WAN
| Action | Proto | Source | Port | Destination | Port | Description |
| :---: | :---: | :--- | :---: | :--- | :---: | :--- |
| ❌ | * | * | * | * | * | *Block All (Défaut)* |
| ✅ | UDP | * | * | WAN Address | 1194 | **Allow OpenVPN Access** |
| ✅ | TCP | * | * | 192.168.10.10 | 80/443 | **NAT Web Server** (Géré par NAT) |

### 2. Interface ADMIN (LAN / VLAN 1)
*C'est le poste de pilotage. Seul l'Admin Réseau est ici.*
| Action | Proto | Source | Dest | Port | Description |
| :---: | :---: | :--- | :--- | :---: | :--- |
| ✅ | * | ADMIN net | * | * | **Allow All** (Accès à Zabbix, Web, Backup, Internet...) |

### 3. Interface EMPLOYEE (VLAN 20)
*Les employés ne doivent voir que l'Internet. Le réseau interne leur est invisible.*
| Action | Proto | Source | Dest | Port | Description |
| :---: | :---: | :--- | :--- | :---: | :--- |
| ❌ | * | EMPLOYEE net | ADMIN net | * | **Block vers Admin** |
| ❌ | * | EMPLOYEE net | DMZ net | * | **Block vers Serveurs Web** (Sauf si site public) |
| ❌ | * | EMPLOYEE net | BACKUP net | * | **Block vers Backup** |
| ❌ | * | EMPLOYEE net | MONITOR net | * | **Block vers Zabbix** (Pas touche au monitoring) |
| ❌ | * | EMPLOYEE net | Firewall | * | **Block Accès WebGUI pfSense** |
| ✅ | TCP/UDP | EMPLOYEE net | * | * | **Allow Internet** (Tout le reste) |

### 4. Interface MONITORING (VLAN 50 / Zabbix)
*Zabbix doit pouvoir interroger les serveurs, mais personne (sauf Admin) ne doit pouvoir interroger Zabbix.*
| Action | Proto | Source | Dest | Port | Description |
| :---: | :---: | :--- | :--- | :---: | :--- |
| ✅ | TCP | MONITOR net | DMZ net | 10050 | **Agent Zabbix Web** |
| ✅ | TCP | MONITOR net | BACKUP net | 10050 | **Agent Zabbix Backup** |
| ✅ | TCP | MONITOR net | * | 80/443 | **Mises à jour & Alertes Mail** |
| ❌ | * | MONITOR net | ADMIN net | * | **Block vers Admin** (Sécurité si Zabbix est piraté) |

### 5. Interface DMZ (VLAN 10)
*Zone exposée : Sécurité maximale. Ne doit jamais initier de connexion vers le LAN ou le BACKUP.*

| Action | Proto | Source | Port | Destination | Port | Description |
| :---: | :---: | :--- | :---: | :--- | :---: | :--- |
| ❌ | * | DMZ net | * | LAN net | * | **BLOCK DMZ vers LAN** (Sécurité Critique) |
| ❌ | * | DMZ net | * | BACKUP net | * | **BLOCK DMZ vers BACKUP** (Anti-Ransomware) |
| ✅ | UDP | DMZ net | * | DMZ Address | 53 | **Allow DNS** (Vers pfSense) |
| ✅ | TCP | DMZ net | * | * | 80/443 | **Allow Updates** (Apt/Curl vers Internet) |

### 6. Interface BACKUP (VLAN 40)
*Zone sécurisée : Doit "tirer" (Pull) les données.*

| Action | Proto | Source | Port | Destination | Port | Description |
| :---: | :---: | :--- | :---: | :--- | :---: | :--- |
| ❌ | * | BACKUP net | * | LAN net | * | **BLOCK BACKUP vers LAN** |
| ✅ | TCP | BACKUP net | * | 192.168.10.10 | 22 | **Allow SSH PULL** (Backup -> Web) |


### 7. Interface OpenVPN
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