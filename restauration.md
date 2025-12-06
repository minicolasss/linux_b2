# RESTAURATION (En cas de crash)
- Réinstaller un Ubuntu vierge.

* Copier l'archive .tar.gz sur le serveur.

* Exécuter la commande :
  
    ```zsh
    sudo tar -xvpzf /chemin/vers/ton-backup.tar.gz -C / --numeric-owner
    ```

## Recréer les dossiers exclus manuellement :

sudo mkdir /proc /sys /mnt /tmp /dev /media /run

## Redémarrer.