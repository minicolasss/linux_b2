# Documentation : Déploiement Automatisé Web & Monitoring

Ce projet Ansible permet de déployer ou de reconstruire entièrement un serveur Web (Docker + Nginx + SSL) et son monitoring (Zabbix) à partir de sauvegardes centralisées.

## 📋 Architecture

* **Contrôleur :** Machine Ansible contenant les backups et le playbook.
* **Cible :** Serveur Web (Ubuntu) qui sera provisionné.
* **Services déployés :**
    * Docker & Docker Compose
    * Conteneur Nginx (Web Server)
    * Certificats Let's Encrypt (Restaurés depuis backup)
    * Agent Zabbix (Installé depuis dépôt local backup)

## 📂 Structure des Fichiers (Machine Ansible)

```text
/home/user/ansible/
├── inventory.ini           # Inventaire des serveurs
├── deploy_full_stack.yml   # Le Playbook principal
└── /backup/centralized_archives/
    ├── system/             # Contient les .tar.gz (SSL, Configs, .deb Zabbix)
    └── web_current/        # Contient le code source (index.html)

```

---

## 1. Configuration de l'Inventaire (`inventory.ini`)

Fichier définissant les cibles et les méthodes de connexion.

```ini
[webservers]
web01 ansible_host=X.X.X.X  # Remplacer par l'IP du serveur web

[production:children]
webservers

[production:vars]
ansible_user=votre_utilisateur
ansible_ssh_private_key_file=~/.ssh/votre_cle_privee
ansible_become=yes
ansible_become_method=sudo

```

---

## 2. Le Playbook (`deploy_full_stack.yml`)

Ce script gère :

1. Le nettoyage des conflits Docker (containerd).
2. L'installation de Docker et des dépendances Python.
3. La recherche automatique de la dernière sauvegarde locale.
4. La restauration chirurgicale du SSL (`/etc/letsencrypt`) sans écraser le système.
5. La configuration et le lancement de Nginx dans Docker.
6. L'extraction et l'installation de l'Agent Zabbix.

```yaml
- name: Déploiement Complet (Docker Web + SSL + Zabbix)
  hosts: webservers
  become: yes

  vars:
    # --- CHEMINS ---
    backup_root: "/backup/centralized_archives"
    project_dir: "/opt/web_project"
    html_dir: "/var/www/html"
    
    # --- CONFIGURATION ZABBIX ---
    zabbix_server_ip: "Y.Y.Y.Y"   # IP du Serveur Monitoring
    zabbix_hostname: "web01"      # Nom de l'hôte dans Zabbix

  tasks:
    # ---------------------------------------------------------
    # 0. NETTOYAGE PRÉVENTIF
    # ---------------------------------------------------------
    - name: Supprimer les paquets Docker conflictuels
      apt:
        name: [docker-ce, docker-ce-cli, containerd.io, docker-doc]
        state: absent
        purge: yes

    # ---------------------------------------------------------
    # 1. INSTALLATION DOCKER
    # ---------------------------------------------------------
    - name: Installation prérequis Docker & Python
      apt:
        name: [docker.io, docker-compose-plugin, python3-docker, python3-pip]
        state: present
        update_cache: yes

    - name: Démarrer Docker
      service: name=docker state=started enabled=yes

    - name: Créer les dossiers du projet
      file:
        path: "{{ item }}"
        state: directory
        mode: '0755'
      loop: ["{{ project_dir }}", "{{ html_dir }}"]

    # ---------------------------------------------------------
    # 2. GESTION BACKUP (Exécution Locale)
    # ---------------------------------------------------------
    - name: Trouver la dernière backup système
      find:
        paths: "{{ backup_root }}/system"
        patterns: "backup-srv-web-*.tar.gz"
      delegate_to: localhost
      register: system_backups
      become: no  # Important : ne pas utiliser sudo en local

    - name: Sélectionner l'archive la plus récente
      set_fact:
        latest_archive: "{{ system_backups.files | sort(attribute='mtime') | last }}"

    # ---------------------------------------------------------
    # 3. RESTAURATION INTELLIGENTE
    # ---------------------------------------------------------
    - name: Extraire uniquement le SSL
      unarchive:
        src: "{{ latest_archive.path }}"
        dest: "/"
        extra_opts: ['--wildcards', 'etc/letsencrypt/*']
      ignore_errors: yes

    - name: Restaurer le site Web
      copy:
        src: "{{ backup_root }}/web_current/index.html"
        dest: "{{ html_dir }}/index.html"
        mode: '0644'

    # ---------------------------------------------------------
    # 4. CONFIGURATION NGINX & DOCKER
    # ---------------------------------------------------------
    - name: Créer nginx.conf
      copy:
        dest: "{{ project_dir }}/nginx.conf"
        content: |
          server {
              listen 80;
              server_name example.com [www.example.com](https://www.example.com);
              location / { return 301 https://$host$request_uri; }
          }
          server {
              listen 443 ssl;
              server_name example.com [www.example.com](https://www.example.com);
              ssl_certificate /etc/letsencrypt/live/[example.com/fullchain.pem](https://example.com/fullchain.pem);
              ssl_certificate_key /etc/letsencrypt/live/[example.com/privkey.pem](https://example.com/privkey.pem);
              location / { root /usr/share/nginx/html; index index.html; }
          }

    - name: Lancer conteneur Nginx
      docker_container:
        name: mon_nginx
        image: nginx:alpine
        state: started
        restart_policy: always
        ports: ["80:80", "443:443"]
        volumes:
          - "{{ html_dir }}:/usr/share/nginx/html:ro"
          - "{{ project_dir }}/nginx.conf:/etc/nginx/conf.d/default.conf:ro"
          - "/etc/letsencrypt:/etc/letsencrypt:ro"

    # ---------------------------------------------------------
    # 5. INSTALLATION ZABBIX (Via Backup .deb)
    # ---------------------------------------------------------
    - name: Extraire le paquet .deb Zabbix
      unarchive:
        src: "{{ latest_archive.path }}"
        dest: "/tmp"
        extra_opts: ['--wildcards', '*zabbix-release*.deb']

    - name: Trouver et installer le repo Zabbix
      find:
        paths: "/tmp"
        patterns: "zabbix-release*.deb"
        recurse: yes
      register: zabbix_deb
    
    - name: Installer le repo
      apt: deb="{{ zabbix_deb.files[0].path }}"
      when: zabbix_deb.matched > 0

    - name: Installer Agent Zabbix
      apt: name=zabbix-agent state=present update_cache=yes

    - name: Configurer Zabbix Agent
      lineinfile:
        path: /etc/zabbix/zabbix_agentd.conf
        regexp: "{{ item.regexp }}"
        line: "{{ item.line }}"
      loop:
        - { regexp: '^Server=', line: "Server={{ zabbix_server_ip }}" }
        - { regexp: '^ServerActive=', line: "ServerActive={{ zabbix_server_ip }}" }
        - { regexp: '^Hostname=', line: "Hostname={{ zabbix_hostname }}" }

    - name: Démarrer Zabbix Agent
      service: name=zabbix-agent state=restarted enabled=yes
    
    - name: Nettoyage temporaire
      file: path="/tmp/home" state=absent

```

---

## 🚀 Utilisation

### Pour déployer ou réparer le serveur :

```bash
ansible-playbook -i inventory.ini deploy_full_stack.yml

```

### En cas de première installation (Serveur vierge) :

1. Créer l'utilisateur sur le serveur distant.
2. Copier la clé SSH : `ssh-copy-id -i ~/.ssh/cle user@ip`.
3. Configurer les droits sudo (NOPASSWD).
4. Lancer le playbook.

## 🛠️ Points Techniques Importants

* **Idempotence :** Le script peut être lancé plusieurs fois sans casser l'existant.
* **Gestion des conflits :** Supprime automatiquement `containerd.io` s'il bloque l'installation standard.
* **SSL :** Les certificats sont montés en lecture seule (`:ro`) dans Docker pour plus de sécurité.
* **Zabbix :** Utilise le fichier `.deb` présent dans la sauvegarde pour garantir que la version installée correspond à celle sauvegardée.
