# Étude réseau — point de décision n°3 (T-090)

13/11/2026. Question à trancher (T-091, Maxime) : quelle architecture réseau et quel hébergement pour jouer à 1 monstre contre 3 chassés, chacun dans son navigateur ?

## Contraintes

- **Navigateur seulement** : le jeu est un export web de Godot 4 (constitution 2.1). Un navigateur ne peut ni ouvrir un port ni écouter des connexions : il ne peut parler qu'à un serveur en **WebSocket** ou à d'autres navigateurs en **WebRTC**. Godot fournit les deux (`WebSocketMultiplayerPeer`, `WebRTCMultiplayerPeer`) avec la même API de multijoueur haut niveau (RPC, `MultiplayerSynchronizer`).
- **Le bruit est secret** : un chassé ne doit jamais recevoir la position des autres joueurs ni du monstre, sauf ce qu'il voit (pilier du jeu, BACKLOG T-098). C'est l'**autorité** (serveur ou joueur hôte) qui calcule les bruits et n'envoie à chacun que ce qu'il a le droit de savoir.
- **Les IA tournent chez l'autorité** : monstre IA et proies IA de complément (navmesh, physique) tournent là où la partie est simulée.
- **Page en HTTPS** (itch.io) : une connexion WebSocket doit être chiffrée (`wss://`), donc un nom de domaine et un certificat.
- **Réseaux filtrés** : ton PC passe par Zscaler. Les filtres d'entreprise et certaines box laissent passer le HTTPS (port 443) mais bloquent souvent l'UDP dont WebRTC a besoin ; il faut alors un relais TURN.
- **Débit faible** : 4 joueurs, 20 mises à jour par seconde, environ 200 octets chacune, soit environ 16 Ko/s sortant pour le serveur et 10 Mo par partie de 10 minutes. Le débit ne coûte presque rien, quelle que soit l'option.

## Options

### A. Pair-à-pair WebRTC, un joueur héberge (0 €/mois)

Le navigateur d'un joueur fait tourner la partie et l'envoie aux autres en WebRTC. Il faut quand même un petit **serveur de mise en relation** pour que les navigateurs se trouvent (par exemple Cloudflare Workers et Durable Objects, offre gratuite à 100 000 requêtes par jour), un STUN (gratuit, Cloudflare ou Google) et un **TURN** pour les réseaux filtrés (Cloudflare : 1 000 Go gratuits par mois, puis 0,05 $/Go).

- Pour : gratuit, pas de machine à entretenir.
- Contre :
  - **l'hôte est un onglet de navigateur** : si son joueur change d'onglet ou réduit la fenêtre, le navigateur ralentit la page (une image par seconde au mieux) et la partie se fige pour tout le monde ; s'il ferme l'onglet, la partie s'arrête ;
  - l'hôte reçoit tout, donc un chassé hôte pourrait tricher (acceptable entre amis) ;
  - deux morceaux réseau à écrire (mise en relation et WebRTC), plus fragiles derrière les filtres ;
  - le test automatique à 4 clients (T-103) est plus difficile : WebRTC n'existe pas dans un Godot sans affichage sans extension.

### B. Serveur dédié Godot en WebSocket (environ 5 €/mois) — recommandé

Le même projet Godot, exporté pour Linux sans affichage, tourne sur un petit serveur loué et fait autorité. Les navigateurs s'y connectent en `wss://` sur le port 443, derrière Caddy (certificat gratuit Let's Encrypt). Un serveur peut accueillir plusieurs parties à la fois.

- Pour :
  - la partie ne dépend d'aucun onglet : un joueur qui part est remplacé par une IA (T-102) ;
  - aucun joueur ne reçoit ce qu'il ne doit pas savoir : le secret du bruit est garanti ;
  - le HTTPS passe partout, filtres d'entreprise compris ;
  - un seul morceau réseau, le plus simple de Godot ;
  - la CI peut lancer le serveur et 4 clients sans affichage pour le test de bout en bout (T-103) ;
  - le serveur est déployé par la CI, comme le build itch.io.
- Contre :
  - environ 4 à 6 € par mois pour un petit serveur Hetzner en Allemagne ou en Finlande (2 cœurs, 4 Go, 20 To de trafic inclus ; à vérifier sur hetzner.com, les prix ont augmenté en avril 2026) ;
  - un nom de domaine, environ 10 € par an (ou un sous-domaine gratuit type DuckDNS) ;
  - une machine à tenir à jour (mises à jour automatiques, déploiement par script).

### C. Serveur dédié gratuit (0 €/mois)

Comme B, mais sur une offre gratuite permanente (par exemple Oracle Cloud « Always Free », processeur ARM ; Godot exporte pour Linux ARM).

- Pour : gratuit, mêmes avantages techniques que B.
- Contre : carte bancaire demandée à l'inscription, machines gratuites parfois reprises si elles restent inactives, disponibilité non garantie. Bien pour essayer, risqué pour des parties prévues avec des amis.

## Recommandation de Claude

**B, serveur dédié Godot en WebSocket**, chez Hetzner (environ 5 €/mois et un domaine). C'est la seule option où la partie ne dépend pas d'un onglet ouvert, où le secret du bruit est garanti et qui passe les filtres réseau. C'est aussi la plus simple à coder et à tester automatiquement. Le code réseau est le même qu'en C : on peut commencer gratuitement sur C et passer sur B sans rien réécrire, si tu préfères attendre avant de payer.

## Ce que ça change pour la suite

- T-094 devient « serveur dédié » : export Linux sans affichage, Caddy, script de déploiement depuis la CI, test de connexion de 4 clients.
- Ce que tu fais une fois (comme pour itch.io) : créer le compte d'hébergement, le serveur et le domaine, puis ajouter deux secrets à GitHub. Claude écrit tout le reste.

## Sources

- Cloudflare Realtime TURN, tarifs : https://developers.cloudflare.com/realtime/turn/faq/ et https://developers.cloudflare.com/realtime/sfu/pricing
- Cloudflare Durable Objects, offre gratuite : https://developers.cloudflare.com/durable-objects/platform/pricing
- Prix Hetzner 2026 (sites tiers, à vérifier sur hetzner.com) : https://vpsbenchmarks.com/hosters/hetzner/plans/cx22
