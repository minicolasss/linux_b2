| VLAN ID | Nom du Réseau | Device / Serveur | Adresse IP | CIDR | Passerelle (GW) | Rôle / Notes |
| ------- | ------------- | ---------------- | ---------- |color-scripts----------- | ---- | --------------- | ------------------------------------------------------ |
| **WAN** | Internet         | OPNsense (WAN)         | DHCP / IP Publique    | -    | FAI             | Connexion Internet                                     |
| **10**  | **DMZ**          | OPNsense (Interface)   | 192.168.10.1          | /24  | -               | Passerelle pour la DMZ                                 |
| 10      | DMZ              | Server_Web             | 192.168.10.11         | /24  | 192.168.10.1    | Serveur Web Ubuntu 1                                   |
| 10      | DMZ              | Serveur_DMZ            | 192.168.10.13         | /24  | 192.168.10.1    | Le serveur "DMZ" de ton schéma                         |
| **20**  | **MGMT / ADMIN** | OPNsense (Interface)   | 192.168.20.1          | /24  | -               | Passerelle d'administration                            |
| 20      | MGMT             | Switch_Principal       | 192.168.20.2          | /24  | 192.168.20.1    | IP de management du switch                             |
| 20      | MGMT             | **Zabbix_Monitoring**  | 192.168.20.50         | /24  | 192.168.20.1    | Serveur de supervision (Accès ports 10050 vers autres) |
| 20      | MGMT             | PC_Admin               | 192.168.20.100        | /24  | 192.168.20.1    | Ton poste de travail (Fixe)                            |
| **30**  | **SERVICES**     | OPNsense (Interface)   | 192.168.30.1          | /24  | -               | Passerelle interne                                     |
| 30      | SERVICES         | **Serveur_DNS**        | 192.168.30.10         | /24  | 192.168.30.1    | Résolution de noms interne                             |
| **40**  | **BACKUP**       | OPNsense (Interface)   | 192.168.40.1          | /24  | -               | Passerelle backup (très filtrée)                       |
| 40      | BACKUP           | **Backup_1**           | 192.168.40.10         | /24  | 192.168.40.1    | Serveur de stockage des sauvegardes                    |
| **50**  | **LAN_USER**     | OPNsense (Interface)   | 192.168.50.1          | /24  | -               | Passerelle pour les employés                           |
| 50      | LAN_USER         | Imprimante_Reseau      | 192.168.50.10         | /24  | 192.168.50.1    | Imprimante partagée (IP Fixe)                          |
| 50      | LAN_USER         | **PC_Employés (DHCP)** | 192.168.50.100 - .200 | /24  | 192.168.50.1    | Plage DHCP pour les PC de bureau                       |
| **99**  | **VPN**          | Clients VPN            | 10.8.0.10 - .200      | /24  | 10.8.0.1        | Plage IP virtuelle pour les télétravailleurs           |