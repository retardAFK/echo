# Serveur d'Écho (S-010)

Le serveur fait jouer les parties en ligne (D-015). C'est le projet Godot lui-même, exporté pour Linux sans affichage (préréglages d'export « Server » pour x86_64, « Server ARM » pour arm64). Il tourne sur un VPS XS d'IONOS (x86_64, Ubuntu 24.04, `echo404.duckdns.org` ; D-016, choix de Maxime du 14/11/2026), derrière Caddy, qui fournit le HTTPS.

```
navigateur ── wss://<domaine>/lobby ──► Caddy ──► accueil (port 8910) : codes de partie
navigateur ── wss://<domaine>/s3    ──► Caddy ──► salle n°3 (port 9003) : une partie
```

- **Accueil** (`echo_server.x86_64 --headless -- --lobby`) : il donne un code à 4 lettres à chaque nouvelle partie et lance une **salle** pour elle (au plus 8 à la fois).
- **Salle** (`-- --room <n> --code <code>`) : un processus par partie. Elle accueille jusqu'à 4 joueurs et s'arrête une minute après le départ du dernier.
- Les ports et les durées sont dans `game/data/net_settings.tres`.

## Essayer sur son PC
```
godot --headless --path . -- --lobby          # l'accueil, qui lance les salles
godot --headless res://tools/godot/net_smoke.tscn   # 4 joueurs se connectent
```
La CI fait la même chose avec le serveur exporté à chaque pull request.

## Mise en place (une fois, T-108)
Maxime crée les comptes et les clés. Claude donne les étapes au moment voulu et ne voit jamais les clés privées.
1. Deux paires de clés SSH sur le PC de Maxime : `echo_admin` (pour lui) et `echo_deploy` (pour la CI, sans phrase de passe).
2. Un VPS sous Ubuntu 24.04 (IONOS VPS XS aujourd'hui), avec la clé publique `echo_admin` dans `/root/.ssh/authorized_keys`. Dans le pare-feu de l'hébergeur (IONOS : Réseau → Stratégie de pare-feu ; Oracle : security list du VCN), autoriser l'entrée TCP 22, 80 et 443.
3. Un nom de domaine qui pointe sur l'IP publique (sous-domaine DuckDNS gratuit pour les tests).
4. Sur le serveur (`ssh -i echo_admin ubuntu@<ip>`), en root : copier ce dossier, puis
   `ECHO_DOMAIN=<domaine> DEPLOY_KEY="<clé publique echo_deploy>" bash setup.sh`.
   Sans copie du dépôt sur la machine, les trois fichiers peuvent y être envoyés en une ligne : une archive `tar.gz` en base64 décodée par `base64 -d | tar xz`.
   Le script ouvre 80 et 443 dans le pare-feu de la machine (les règles iptables des images Oracle, ou ufw ailleurs).
5. Dans GitHub : le secret `ECHO_DEPLOY_KEY` (clé privée `echo_deploy`) et la variable `ECHO_HOST` (le domaine). Sur une machine ARM, ajouter la variable `ECHO_SERVER_ARCH=arm64`.
6. La CI déploie ensuite chaque version de `main` avec `deploy.sh` (l'export pour le processeur du serveur, copié en `/opt/echo/echo_server`), et le build web de la même version, servi par Caddy sur `https://<domaine>/` (copié en `/opt/echo/web`) et connecté à `wss://<domaine>`.

## Fichiers
| Fichier | Rôle |
|---|---|
| `Caddyfile` | HTTPS, aiguillage `/lobby`, `/s1` à `/s8` vers les ports, et le jeu web à la racine |
| `echo-lobby.service` | service systemd de l'accueil (et de ses salles) |
| `setup.sh` | installation d'un serveur neuf |
| `deploy.sh` | envoi d'une nouvelle version (serveur et jeu web) et redémarrage |
