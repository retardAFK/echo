# Serveur d'Écho (S-010)

Le serveur fait jouer les parties en ligne (D-015). C'est le projet Godot lui-même, exporté pour Linux sans affichage (préréglage d'export « Server »). Il tourne chez Hetzner, derrière Caddy, qui fournit le HTTPS.

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

## Mise en place chez Hetzner (une fois, T-108)
Maxime crée le compte, le serveur et le nom de domaine. Claude donne les étapes au moment voulu et ne voit jamais les clés.
1. Un serveur **CX22** (Ubuntu 24.04, Allemagne ou Finlande) et un nom de domaine qui pointe sur son adresse IP.
2. Une paire de clés SSH réservée au déploiement : la clé publique va au serveur, la clé privée dans le secret GitHub `ECHO_DEPLOY_KEY` ; le domaine va dans la variable `ECHO_HOST`.
3. Sur le serveur, en root : copier ce dossier, puis
   `ECHO_DOMAIN=<domaine> DEPLOY_KEY="<clé publique>" bash setup.sh`.
4. La CI déploie ensuite chaque version de `main` avec `deploy.sh`.

## Fichiers
| Fichier | Rôle |
|---|---|
| `Caddyfile` | HTTPS et aiguillage `/lobby`, `/s1` à `/s8` vers les ports |
| `echo-lobby.service` | service systemd de l'accueil (et de ses salles) |
| `setup.sh` | installation d'un serveur neuf |
| `deploy.sh` | envoi d'une nouvelle version et redémarrage |
