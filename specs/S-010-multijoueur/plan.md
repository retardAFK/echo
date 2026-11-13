# Plan — S-010

**Statut** : établi par Claude (13/11/2026) à partir de la spec validée et de D-015 (serveur dédié Godot en WebSocket chez Hetzner)

## Vue d'ensemble

```
navigateur (client Godot web)                 serveur Hetzner (Linux, sans affichage)
  ── wss://<domaine>/lobby ──►  Caddy (TLS) ──► processus « accueil » (codes de partie)
  ── wss://<domaine>/s3    ──►  Caddy (TLS) ──► processus « salle » n°3 (une partie)
```

- Un seul projet Godot, trois façons de le lancer : le jeu (navigateur ou PC), l'**accueil** (`--lobby`) et une **salle** (`--room <port>`). Le serveur est l'export Linux du même projet, en mode « serveur dédié » (Godot retire les textures et les sons du paquet), lancé avec `--headless`.
- **Accueil** : il reçoit « créer » ou « rejoindre KRBX », tient la table des codes et lance une salle par partie (`OS.create_process`), sur un port fixe de 9001 à 9008 (8 parties à la fois au plus, largement assez pour des amis). Il répond au client le chemin de la salle (`/s3`) puis le client s'y connecte. Une salle vide depuis 60 s s'arrête et libère son code.
- **Salle** : un processus par partie, avec son propre monde physique et sa navigation. Le crash d'une partie ne touche pas les autres.
- **Caddy** termine le chiffrement (certificat Let's Encrypt automatique) et renvoie `/lobby` vers le port 8910 et `/s1` à `/s8` vers 9001 à 9008. Les clients ne voient que le port 443, qui passe les filtres réseau d'entreprise.
- **Jouer seul** ne change pas : aucune connexion, la partie tourne dans le navigateur comme aujourd'hui (Q9).

## Qui fait autorité (Q5)
La **salle** simule tout : déplacements, physique, IA, fusibles, bruits, captures, scan, fin de partie. Les clients n'envoient que leurs **commandes** et n'affichent que ce que la salle leur renvoie. Un client ne décide de rien, sauf de l'affichage de son propre personnage en attendant la réponse (prédiction, plus bas).

### Commandes séparées du clavier
Aujourd'hui `Player` et `MonsterAvatar` lisent `Input` directement. Nouvelle classe pure **`PlayerCommands`** (`game/net/player_commands.gd`, `RefCounted`) : déplacement (`Vector2`), lacet et tangage, course, accroupi, interaction maintenue, scan maintenu, et les actions ponctuelles (lancer, poser un réveil, se cacher, sortir) avec un numéro de séquence. Chaque avatar lit un `commands` au lieu d'`Input` :
- en solo et pour son propre personnage, un nœud **`LocalControls`** remplit les commandes à partir du clavier et de la souris (même comportement qu'aujourd'hui, les tests existants doivent passer sans changement) ;
- dans la salle, les commandes arrivent du réseau.
Sérialisation compacte (`to_bytes()` / `from_bytes()`) testée par GUT.

### Ce qui circule
| Sens | Contenu | Fréquence | Canal |
|---|---|---|---|
| client → salle | commandes, avec numéro de séquence | 30 fois/s | non fiable, ordonné |
| client → salle | actions ponctuelles (lancer, réveil, cachette) | à l'appui | fiable |
| salle → client | **instantané filtré pour ce client** : son personnage (position, vitesse, dernière commande prise en compte), les entités qu'il voit | 20 fois/s | non fiable, ordonné |
| salle → client | **bruits filtrés** pour ce client (plus bas) | à l'émission | fiable |
| salle → tous | évènements de partie : fusible pris ou posé, transformateur, sirène, sortie, scan et lumières qui vacillent, porte de cachette, alarme de voiture, bouteille lancée (point de départ et vitesse), capture, sauvetage, fin | à l'émission | fiable |
| les deux sens | ping (horodatage aller et retour) | 1 fois/s | non fiable |

Pas de `MultiplayerSynchronizer` : un seul nœud **`NetSession`** construit l'instantané de chaque client lui-même, avec une fonction pure de filtrage. Le critère « un chassé ne reçoit jamais… » se teste alors sur les messages réellement construits.

## Ce que chaque client reçoit
Une fonction pure **`NetVisibility`** (`game/net/net_visibility.gd`) décide, pour un destinataire et une entité, si l'entité part dans l'instantané. Elle prend en entrée des faits déjà calculés par la salle (distance, ligne de vue libre, cachée ou non), ce qui la rend testable sans scène.

**Un chassé reçoit :**
- son propre personnage ;
- un autre chassé, une proie IA ou le monstre **seulement s'il le voit** : à moins de la portée de vue de nuit (réglage), dans un cône un peu plus large que la caméra (pour ne pas voir apparaître quelqu'un en tournant la tête), avec une ligne de vue libre (rayon sur les murs et le décor) ; jamais s'il est caché dans une cachette ;
- les bruits **que ses oreilles entendent** (`NoiseBus.can_hear` depuis sa position, murs compris) : type, position et portée perçue, **sans l'identité de celui qui l'a fait**. Ses propres bruits ne lui sont pas renvoyés (il les joue lui-même) ;
- les évènements de partie qui se voient ou s'entendent de partout (sirène, fusibles posés comptés par l'interface, fin) ou qui le concernent (sa capture, son sauvetage).

**Le monstre reçoit :**
- son propre personnage ;
- un chassé ou une proie IA s'il le voit (même règle : le monstre voit normalement, son avantage reste le bruit) ;
- **tous les bruits de tous les chassés**, avec leur position et leur portée, comme aujourd'hui en solo (marqueurs orange, scan qui révèle les bruits faibles d'un bâtiment) ;
- les mêmes évènements de partie.

**Jamais envoyé à un chassé** : la position, la direction ou l'état (caché, accroupi, en course) d'un joueur qu'il ne voit pas ; l'identité de l'auteur d'un bruit ; la position du monstre hors de sa vue ; l'emplacement des fusibles qu'il n'a pas encore trouvés au-delà de ce qu'affiche déjà l'interface solo ; la jauge et la cible du scan du monstre (il ne voit que les lumières qui vacillent, comme en solo).

Un **spectateur** (chassé éliminé, Q2) reçoit l'instantané du coéquipier qu'il suit, pas plus.

## Prédiction et interpolation (Q8)
- **Son propre personnage** : le client applique ses commandes tout de suite avec le même code de déplacement (`PlayerMotion` et `CharacterBody3D`), garde les commandes non confirmées, et à chaque instantané repart de la position du serveur et rejoue les commandes plus récentes. Si l'écart reste au-dessus d'un seuil (réglage, 0,5 m), il est corrigé en douceur sur 0,2 s ; au-dessus de 2 m, il saute.
- **Les autres** : affichés 100 ms dans le passé, interpolés entre les deux instantanés qui encadrent ce moment ; extrapolation courte (au plus 150 ms) si un instantané manque, puis immobile.
- **Le regard du monstre** côté monstre est local et instantané ; la salle utilise le dernier regard reçu pour le scan et la capture.
- Le ping et la gigue s'affichent avec F3 (`DebugOverlay`).
- Le test de latence ajoute un retard sur la boucle locale de la CI (`tc netem`, 75 ms dans chaque sens) et vérifie l'écart entre position prédite et position du serveur.

## Le salon (Q6)
- Code de 4 lettres tiré dans `ABCDEFGHJKMNPQRTUVWXYZ` (sans I, L, O, S ni chiffres), unique tant que la salle existe.
- La salle garde 4 places : monstre, chassé 1, chassé 2, chassé 3. Le premier arrivé est **chef** : il change les rôles et lance quand tous les humains sont prêts. Une place vide affiche « IA ».
- À la connexion, le client envoie la version du build ; une version différente de celle du serveur est refusée avec « Recharge la page : une nouvelle version est en ligne ».
- Une partie lancée n'accepte plus de nouveaux joueurs, seulement le retour d'un joueur parti (jeton de reprise ci-dessous).
- Fin de partie : chacun voit son écran de fin, puis retour au salon avec les mêmes places.

## Plusieurs chassés et règle de capture (Q1, Q2)
- Trois points d'apparition éloignés les uns des autres, tirés parmi les `PlayerSpawns` de la cité (au moins 40 m entre deux chassés).
- `Monster` (IA) gagne une liste de cibles au lieu d'un seul `player` ; il chasse la plus proche qu'il voit ou entend.
- **Capture** : le chassé attrapé passe à l'état `CAPTURED` sur place, à genoux, sans pouvoir bouger ni agir. Il **appelle à l'aide** : un bruit faible et régulier (nouveau type `NoiseEvent.Type.CALL`, portée et rythme en réglage), que le monstre entend comme les autres.
- **Sauvetage** : un coéquipier qui maintient E 4 s à moins de 1,5 m le libère (réutilise `HoldInteraction`) ; le sauvetage fait un bruit moyen (`RESCUE`). Le libéré repart debout, sans fusible s'il en portait (le fusible tombe au sol et se ramasse).
- **Deuxième capture** : éliminé, il devient spectateur et suit un coéquipier encore en jeu (clic pour changer).
- **Fin** : les chassés gagnent dès qu'un chassé franchit la sortie ; le monstre gagne quand aucun chassé n'est libre (tous capturés ou éliminés).
- **Solo** : rien ne change (une prise termine la partie), pour garder l'équilibre de S-009.

## Départs et coupures (Q7)
- À l'entrée en salle, le client reçoit un **jeton de reprise** (aléatoire, gardé en mémoire et dans `localStorage`). Une coupure laisse sa place 10 s, puis une IA la prend (proie IA ou monstre IA, à l'endroit où était le joueur). S'il revient avec le code et son jeton avant la fin, il reprend la place de l'IA.
- Le chef qui part transmet le rôle de chef au joueur suivant. Si tous les humains partent, la salle s'arrête.

## Fichiers prévus
| Fichier | Rôle |
|---|---|
| `game/net/net_session.gd` (autoload `NetSession`) | connexion, mode (solo, client, salle), envoi et réception, ping |
| `game/net/player_commands.gd`, `local_controls.gd` | commandes séparées du clavier |
| `game/net/net_visibility.gd` | filtrage pur de ce que reçoit chaque client |
| `game/net/snapshot.gd`, `snapshot_buffer.gd` | instantanés, interpolation et rejeu |
| `game/net/room_code.gd` | tirage et vérification des codes |
| `game/net/lobby_server.gd`, `room_server.gd` | accueil et salle côté serveur |
| `game/ui/lobby_menu.tscn` | créer, rejoindre, places, prêt, lancer |
| `game/ui/spectator_view.gd` | vue spectateur |
| `game/data/net_settings.gd` et `.tres` | fréquences, retards, seuils, ports, adresse du serveur |
| `tools/server/` | `Caddyfile`, service `systemd`, `deploy.sh`, `README.md` (mise en place du serveur) |
| `tools/godot/net_match.gd` | partie scriptée à 4 clients sans affichage pour la CI |

## Réglages
| Réglage | Fichier | Valeur de départ |
|---|---|---|
| Commandes envoyées | `net_settings.tres` | 30 /s |
| Instantanés envoyés | `net_settings.tres` | 20 /s |
| Retard d'interpolation | `net_settings.tres` | 100 ms |
| Seuil de correction douce / saut | `net_settings.tres` | 0,5 m / 2 m |
| Délai avant remplacement par une IA | `net_settings.tres` | 10 s |
| Portée de vue de nuit (filtre) | `net_settings.tres` | 40 m |
| Durée du sauvetage | `player_settings.tres` | 4 s |
| Portée et rythme de l'appel à l'aide | `noise_settings.tres` | 8 m, toutes les 3 s |
| Portée du bruit de sauvetage | `noise_settings.tres` | 15 m |
| Écart minimal entre apparitions | `loop_settings.tres` | 40 m |

## Construction et déploiement
- Nouveau préréglage d'export **« Server »** (Linux, `dedicated_server`, ressources visuelles retirées). La CI l'exporte à chaque PR (vérifie qu'il démarre et répond au ping), et sur `main` un job `deploy` l'envoie au serveur par SSH puis redémarre les services.
- L'adresse du serveur (`wss://<domaine>`) est écrite dans le build web par la CI depuis une variable du dépôt, comme la version ; en local, `ws://localhost:8910`.
- Ce que Maxime fait une fois (T-108) : créer le compte Hetzner et un serveur CX22 (Ubuntu 24.04, Allemagne ou Finlande), un nom de domaine qui pointe dessus, et ajouter les secrets SSH du déploiement dans GitHub. Claude donne les étapes pas à pas et ne voit jamais les clés ; le script `tools/server/setup.sh` installe Caddy, l'utilisateur `echo` et les services.

## Impact sur la performance
- **Client** : au plus 3 personnages de plus à l'écran (silhouettes simples, quelques centaines de triangles), aucun éclairage en plus. L'interpolation et le rejeu coûtent moins de 0,5 ms par image. Le banc d'essai garde 60 images/s, avec 3 silhouettes ajoutées au parcours.
- **Réseau** : un instantané fait environ 100 à 200 octets ; à 20 /s pour 4 clients, moins de 20 Ko/s par partie. Le trafic inclus chez Hetzner (20 To/mois) est très loin.
- **Serveur** : une salle fait tourner la physique, la navigation et l'IA sans rendu ; objectif sous 15 % d'un cœur du CX22 par partie, mesuré par le test à 4 clients.
- **Taille du build web** : quelques dizaines de Ko de scripts.

## Risques et alternatives
- **Reprendre `Player` et `MonsterAvatar` casse le solo** : la séparation des commandes (T-106) passe d'abord, seule, avec tous les tests existants, la simulation et le banc avant d'aller plus loin.
- **L'IA écrite pour une seule proie** (`Monster.player`, `GameMap.prey`) : la liste de cibles arrive dans T-100 avec des simulations à 3 proies IA ; si l'équilibre bascule, on ajuste les réglages comme en S-009.
- **Le rejeu de la prédiction diverge** (marches, cachettes, collisions avec d'autres joueurs) : correction douce, et on accepte de ne pas prédire les entrées et sorties de cachette (attente de la confirmation du serveur, 1 aller-retour).
- **Un client trafiqué** : il ne peut envoyer que des commandes, que la salle borne (vitesse, portée d'interaction). La lutte contre la triche au-delà est hors périmètre.
- **Pas encore de serveur en ligne** au moment de coder : tout se développe et se teste en local et en CI (`ws://localhost`) ; seule T-104 a besoin du serveur Hetzner.
- **Alternative écartée** : plusieurs parties dans un même processus (un monde physique par salle) ; plus économe en mémoire mais plus fragile, alors qu'un CX22 fait tourner 8 salles sans peine.

## Conformité à la constitution
- GDScript seul, renderer Compatibility côté client, aucune extension native : le serveur est le même projet exporté.
- Réglages dans `data/` (`net_settings.tres` et les réglages existants), aucun chiffre magique.
- Le bruit passe toujours par `NoiseBus` ; la salle filtre ce qui part vers chaque client, sans second système de bruit.
- Tests GUT pour les commandes, le filtrage, les instantanés, l'interpolation, les codes, la règle de capture ; test de bout en bout à 4 clients en CI.
- Une branche et une PR par tâche, comme d'habitude.
