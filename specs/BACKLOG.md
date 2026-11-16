# Backlog — de la phase 9 à la sortie

**Statut** : prévisionnel (T-072, 12/11/2026)
**Point de départ** : phases 0 à 8 livrées (S-001 à S-008, tâches T-000 à T-071).

Ce document liste tout ce qui reste à faire jusqu'à la sortie publique : les phases, la spec prévue pour chacune, et ses tâches dans l'ordre, avec leurs dépendances. Il complète la [feuille de route](../ECHO_PROJET.md#7-feuille-de-route-de-a-à-z) sans la remplacer.

**Comment le lire**

- Chaque phase garde le cycle SDD (section 3) : la spec est écrite et clarifiée avec Maxime, puis le plan et `tasks.md` détaillent les tâches. Les tâches ci-dessous sont **prévisionnelles** : la spec de la phase peut en ajouter, en fusionner ou en retirer.
- Chaque phase a un **bloc de numéros réservé**. Une tâche ajoutée plus tard prend le premier numéro libre de son bloc, pour que les numéros restent dans l'ordre des phases.
- Les tâches marquées **(Maxime)** lui reviennent : une décision, ou un test avec d'autres personnes. Tout le reste est fait et vérifié par Claude (tests GUT, lint, import et export web, simulations, captures), selon la règle du 10/11/2026 : Maxime n'a pas à faire de playtest pour qu'on avance.
- Les choix de style (modèles, sons, musique, plan de map) sont montrés à Maxime avant intégration, comme pour S-005 à S-008.
- Les questions ouvertes du journal (section 10.2) sont tranchées dans la clarification de la spec qui en a besoin, pas avant.

## Vue d'ensemble

| Phase | Spec | Objectif | Bloc de tâches | Dépend de |
|---|---|---|---|---|
| 9 | S-009 | Préparer le test à plusieurs, mesurer les 60 images/s, puis **point de décision n°2** | T-073 à T-089 | S-008 |
| 10 | S-010 | Multijoueur en ligne, précédé du **point de décision n°3** | T-090 à T-119 | Phase 9 |
| 11 | S-011 | Personnages et animations | T-120 à T-139 | Phase 10 |
| 12 | S-012 | Audio complet | T-140 à T-159 | Phase 11 |
| 13 | S-013 | Interface, menus et options | T-160 à T-179 | Phase 12 |
| 14 | S-014 | L'hôpital, intégré à la cité des Tilleuls (D-019) | T-180 à T-209 | Phase 13 |
| 15 | S-015 | Finition et publication | T-210 à T-229 | Phase 14 |
| — | S-016 | Intérieurs des bâtiments de la cité (demande du 15/11/2026, hors ordre des phases) | T-230 à T-249 | S-006, S-008, S-010 |
| — | S-017 | Carte des chassés (demande du 15/11/2026, hors ordre des phases) | T-250 à T-259 | S-006, S-010 |
| — | S-018 | Prison et réseau de la cité : terminaux, caméras, leurres à distance, quêtes tirées au sort (demande du 15/11/2026, hors ordre des phases) | T-260 à T-289 | S-010, S-016 |
| — | S-019 | Ambiance des intérieurs : HLM abandonnés avec l'ambiance de l'hôpital (demande du 15/11/2026, hors ordre des phases, `specs/S-019-ambiance-interieurs/`) | T-290 à T-299 | S-016 |

L'ordre suit D-013 (12/11/2026) : le multijoueur passe juste après le test à plusieurs, avant les personnages, l'audio et les menus. Tout ce qui est ajouté avant le réseau (animations, sons d'autres joueurs, menus) devrait sinon être repris pour être synchronisé.

```
S-008 ──► 9 Test à plusieurs ──► DP2 ──► DP3 ──► 10 Multijoueur ──► 11 Personnages ──► 12 Audio ──► 13 Menus ──► 14 Hôpital (dans la cité) ──► 15 Sortie
```

---

## Phase 9 — Préparer le test à plusieurs (S-009)

**But** : une version que 3 à 5 personnes de confiance peuvent ouvrir d'un simple lien, comprendre sans explication et jouer dans les deux rôles, avec des chiffres fiables sur la performance et l'équilibre. C'est la préparation du **point de décision n°2**.

**Reste de S-006 à S-008 repris ici** : 60 images/s jamais mesurées sur la machine de référence ; deux endroits où la proie IA se fait prendre trop souvent (emplacement de fusible du parking vers 2 min, couloir en cul-de-sac du centre social vers 3,5 min) ; le monstre IA n'utilise pas encore le scan (S-003 l'avait laissé « à décider après S-004 »), donc le chassé ne voit jamais l'alerte des lumières.

**Terminé quand** : le lien de test est envoyé à Maxime, les 60 images/s sont mesurées sur la machine de référence, et une partie simulée dure 8 à 12 minutes en moyenne.

- [ ] T-073 — Spec S-009
  - Résultat vérifiable : spec validée par Maxime
  - Dépend de : —
- [ ] T-074 — Plan et tâches de S-009
  - Résultat vérifiable : `plan.md` et `tasks.md`, avec le choix de l'hébergement du build de test (Q-012)
  - Dépend de : T-073
- [ ] T-075 — Mode banc d'essai
  - Résultat vérifiable : l'adresse du build web avec `?bench` lance un parcours de caméra fixe dans la cité des Tilleuls, avec le monstre IA et la proie IA en jeu, puis affiche et écrit dans la console les images/s (moyenne, minimum, 1 % les plus lentes), les appels de dessin et le temps de chargement ; tests GUT sur le calcul des statistiques
  - Dépend de : T-074
- [ ] T-076 — Build de test en ligne
  - Résultat vérifiable : la CI publie le build web de `main` à une adresse fixe (GitHub Pages si le dépôt le permet, sinon une page itch.io non listée) ; le lien s'ouvre dans Chrome sans installation
  - Dépend de : T-074
- [ ] T-077 — Mesure des 60 images/s sur la machine de référence
  - Résultat vérifiable : banc d'essai lancé par Claude dans le navigateur intégré de l'app Claude, sur le PC de Maxime, sans lui demander de jouer ; résultats notés dans S-006, S-007, S-008 et S-009 ; s'il manque des images, tâches d'optimisation ajoutées dans le bloc de la phase
  - Dépend de : T-075, T-076
- [ ] T-078 — Le monstre IA utilise le scan
  - Résultat vérifiable : quand il perd une trace près d'un bâtiment visitable, ou entend un bruit qui en vient, le monstre IA s'arrête et scanne en respectant la jauge (D-009) ; les lumières vacillent pour le chassé ; tests GUT ; la simulation compte les scans
  - Dépend de : T-074
- [ ] T-079 — Équilibre de la proie IA et du monstre IA
  - Résultat vérifiable : les deux endroits de capture répétée sont corrigés (map ou IA) ; sur 3 séries de 20 parties simulées, la proie IA sort 40 à 60 % du temps et la partie dure 8 à 12 min en moyenne, sans blocage
  - Dépend de : T-078
- [ ] T-080 — Commandes et pause
  - Résultat vérifiable : le menu de départ montre les commandes du rôle choisi ; Échap met en pause (reprendre, revenir au menu) ; textes dans `strings.csv`
  - Dépend de : T-074
- [ ] T-081 — Recueil des retours
  - Résultat vérifiable : l'écran de fin propose « Copier le résumé » (rôle, durée, fusibles, bruits, scans, ruses, images/s moyennes) ; un questionnaire court dans `specs/S-009-test-a-plusieurs/questionnaire.md`
  - Dépend de : T-080
- [ ] T-082 — Vérification finale de S-009
  - Résultat vérifiable : chaque critère d'acceptation coché, lien de test et questionnaire envoyés à Maxime
  - Dépend de : T-077, T-079, T-081
- [ ] T-083 — Tests à 3 à 5 personnes **(Maxime)**
  - Résultat vérifiable : Maxime transmet le lien et le questionnaire, et rapporte les réponses (ou les résumés copiés depuis l'écran de fin)
  - Dépend de : T-082
- [ ] T-084 — Synthèse et réglages après les tests
  - Résultat vérifiable : retours notés dans le journal, réglages de jeu ajustés dans les `.tres`, design modifié si besoin par une décision écrite ; **point de décision n°2** tranché par Maxime
  - Dépend de : T-083

> **Point de décision n°2** : le jeu est-il amusant pour d'autres que nous ? Si non, on ajuste le design (nouvelle spec) avant le multijoueur.

---

## Phase 10 — Multijoueur en ligne (S-010)

**But** : 1 monstre et jusqu'à 3 chassés jouent ensemble depuis 4 navigateurs, avec des IA pour remplir les places vides. C'est la phase la plus difficile du projet.

**Questions tranchées dans la spec** (13/11/2026) : Q-002 (3 chassés), Q-003 (sauvable une fois), Q-005 (amis seulement, avec un code), Q-010 (pas de voix en jeu).

**Terminé quand** : 1 monstre et 3 chassés jouent une partie complète depuis 4 navigateurs différents, sur des connexions différentes.

- [x] T-090 — Étude du point de décision n°3 : architecture réseau et coûts
  - Résultat vérifiable : note comparant les options (WebRTC entre joueurs avec un hôte et un petit serveur de mise en relation, ou serveur dédié en WebSocket), avec ce qu'elles coûtent par mois, leurs limites dans le navigateur et le travail qu'elles demandent ; recommandation de Claude
  - Dépend de : T-084 (levé par D-014 : test à plusieurs reporté)
  - Fait le 13/11/2026 : [`specs/S-010-multijoueur/etude-reseau.md`](S-010-multijoueur/etude-reseau.md), recommandation : serveur dédié Godot en WebSocket
- [x] T-091 — Choix de l'architecture et de l'hébergement **(Maxime)**
  - Résultat vérifiable : décision écrite dans le journal (point de décision n°3)
  - Dépend de : T-090
  - Fait le 13/11/2026 : D-015, serveur dédié Godot en WebSocket chez Hetzner
- [x] T-092 — Spec S-010
  - Résultat vérifiable : spec validée, Q-002, Q-003, Q-005 et Q-010 closes
  - Dépend de : T-091
  - Fait le 13/11/2026 : Q1 à Q4 validées par Maxime (3 chassés, sauvable une fois, entre amis avec un code, pas de voix)
- [x] T-093 — Plan et tâches de S-010
  - Résultat vérifiable : `plan.md` (qui fait autorité, ce que chaque client reçoit, ce qui n'est jamais envoyé aux chassés) et `tasks.md`
  - Dépend de : T-092
  - Fait le 13/11/2026 : [`plan.md`](S-010-multijoueur/plan.md) et [`tasks.md`](S-010-multijoueur/tasks.md)
- [x] T-106 — Commandes séparées du clavier
  - Résultat vérifiable : `PlayerCommands` (sérialisation testée), `LocalControls` ; `Player` et `MonsterAvatar` ne lisent plus `Input` ; tous les tests existants, la simulation et le banc inchangés
  - Dépend de : T-093
  - Fait le 13/11/2026 : `game/net/player_commands.gd` (22 octets plus un par action, valeurs bornées à la lecture) et `local_controls.gd` ; les deux avatars lisent `commands` et n'ajoutent `LocalControls` que si `local_controls` est vrai ; 420 tests GUT, dont 8 nouveaux, tous passent
- [x] T-094 — Serveur dédié : accueil et salles
  - Résultat vérifiable : préréglage d'export « Server », modes `--lobby` et `--room`, `RoomCode` testé, une salle lancée par code et arrêtée quand elle est vide ; `tools/server/` (Caddyfile, services, `setup.sh`, `deploy.sh`, README) ; la CI exporte le serveur, le démarre et y connecte 4 clients sans affichage
  - Dépend de : T-093
  - Fait le 13/11/2026 : `game/net/` (`RoomCode`, `NetAddress`, `ServerBoot`, `LobbyRegistry`, `LobbyServer`, `LobbyClient`, `RoomLink`, scènes de l'accueil et de la salle), `net_settings.tres`, préréglage « Server » (80 Mo, sans visuels) ; `tools/server/` ; la CI exporte le serveur, le lance et `tools/godot/net_smoke.tscn` y connecte 4 joueurs (ping 7 ms en local, 5e refusé) ; 13 tests GUT
- [x] T-095 — Couche réseau du jeu
  - Résultat vérifiable : autoload `NetSession` (solo, client, salle), connexion, version vérifiée, déconnexion, ping affiché avec F3 ; commandes envoyées à 30 /s et appliquées par la salle ; tests GUT avec des pairs locaux
  - Dépend de : T-094, T-106
  - Fait le 13/11/2026 : autoload `NetSession` (solo, client, salle) qui enveloppe `RoomLink` ; commandes tenues envoyées 30 fois/s (non fiable, ordonné, anciennes trames ignorées), actions ponctuelles en fiable ; version refusée, départ et fermeture de la salle signalés ; ligne `NET place 1 ping 7 ms` avec F3 ; la salle exportée passe par `NetSession` ; 9 tests GUT
- [x] T-096 — Salon (lobby)
  - Résultat vérifiable : `LobbyMenu` : créer, rejoindre avec un code, 4 places, chef, rôles, prêt, lancer ; places vides marquées « IA » ; retour au salon après la fin ; textes dans `strings.csv`
  - Dépend de : T-095
  - Fait le 13/11/2026 : `LobbyState` (places, prêt, chef, lancement ; testé), demandes et diffusion du salon dans `RoomLink`, `NetSession` relaie le salon ; `LobbyMenu` (créer, rejoindre, Prendre, Échanger pour le chef, Je suis prêt, Lancer la partie, erreurs en clair) ; bouton « Jouer en ligne » caché tant que `show_online` est faux (T-097, T-108) ; une partie lancée refuse les nouveaux venus. Le retour au salon après la fin vient avec l'écran de fin en ligne (T-099) ; 11 tests GUT
- [x] T-097 — Synchronisation des chassés
  - Résultat vérifiable : instantanés filtrés à 20 /s, prédiction et rejeu du personnage local, interpolation des autres ; accroupi, course, état caché ; écart prédit et serveur sous le seuil avec 150 ms de ping simulé
  - Dépend de : T-095
  - Fait le 13/11/2026 : `NetGame` (salle : commandes vers les avatars, instantanés à 20 /s filtrés par `NetVisibility` ; client : `Prediction` avec correction douce ou saut, `NetPuppet` interpolés par `SnapshotBuffer`), lancement de la map sur la salle et les clients, places monstre ou chassé ; la CI joue `tools/godot/net_walk.tscn` contre le serveur exporté avec 150 ms de ping : écart prédit et serveur 0,09 à 0,28 m (seuil 0,5 m) ; 11 tests GUT. L'état caché, les cachettes et les ramassages restent prédits localement jusqu'à T-099
- [x] T-098 — Synchronisation du bruit et du monstre
  - Résultat vérifiable : `NetVisibility` testé ; bruits envoyés au monstre avec leur position, aux chassés seulement s'ils les entendent et sans auteur ; un test lit les messages construits pour un chassé et n'y trouve jamais un joueur qu'il ne voit pas ; scan, lumières qui vacillent et capture synchronisés
  - Dépend de : T-097
  - Fait le 13/11/2026 : canal d'évènements fiable (`RoomLink.send_event`) ; la salle envoie au monstre tous les bruits sauf les siens, à chaque chassé seulement ceux qu'il entend (`NoiseBus.can_hear`), jamais les siens ni leur auteur ; le client les rejoue par `NoiseBus` (oreilles, marqueurs, scan inchangés). Scan d'un bâtiment envoyé aux chassés (lumières qui vacillent). Capture par contact du monstre humain (comme en solo, pas dans une cachette) ou par le monstre IA : écran « attrapé » chez le chassé, le chassé repart d'un point d'apparition en attendant T-107 ; 5 tests GUT, dont un qui vérifie qu'aucun message pour un chassé ne contient un joueur qu'il ne voit ni n'entend
- [x] T-099 — Synchronisation de la boucle de partie et des ruses
  - Résultat vérifiable : fusibles, transformateur, sirène, sortie, bouteilles, réveils, cachettes, alarmes de voiture ; écran de fin pour chaque joueur
  - Dépend de : T-098
  - Fait le 13/11/2026 : `NetWorld` liste les boîtiers, objets à ramasser, alarmes de voiture et cachettes dans le même ordre des deux côtés, avant tout tirage ; la salle envoie l'état (fusibles, objets présents, alarmes, valeurs de la boucle) quand il change. Chez le client, la boucle (`GameLoop.mirror`) et la carte ne font que copier : fusibles, transformateur, sirène, sortie, fin. Le joueur client bouge mais n'agit pas (`mirror_world`) ; la salle renvoie ce qu'il porte, sa cachette et la progression de ce qu'il tient. Bouteilles lancées et réveils posés rejoués chez chacun, réveils écrasés ; sur un client, seuls l'avatar local et la salle font du bruit. Écran de fin pour chacun (« Retour au salon »), la salle revient au salon 3 s après la fin. Hors champ : une seule équipe de fusibles par partie (plusieurs chassés : T-100), pas de victoire du monstre par capture avant T-107, cachettes occupées non envoyées (secret). En passant : boîtier 1 de la galerie déplacé de 2 m, un placard le recouvrait (test intermittent) ; 8 tests GUT + 1 test de carte ; `net_walk` vérifie aussi les fusibles copiés
- [x] T-100 — Plusieurs chassés
  - Résultat vérifiable : 3 points d'apparition éloignés, le monstre IA choisit parmi plusieurs cibles, victoire dès qu'un chassé sort, défaite quand aucun n'est libre ; simulation à 3 proies IA sans blocage
  - Dépend de : T-099
  - Fait le 13/11/2026 : `GameLoop.team` (tous les chassés) : chacun prend des fusibles et ne pose que les siens (`carried_by`, transformateur `wanted_by`), un seul qui sort fait gagner l'équipe, `hunted_out` élimine et le monstre gagne quand aucun n'est libre ; les fusibles d'un éliminé retournent dans les boîtiers vides les plus proches. `Monster.others` : le monstre IA chasse celui qu'il voit, attrape n'importe lequel (`hunted_caught`). `GameMap.far_apart` tire les points d'apparition à 40 m au moins (`spawn_spacing`). Solo inchangé. Simulation `--preys 3` : 5 parties, 4 sorties, 1 prise des trois, aucun blocage, 6,8 min en moyenne ; 8 tests GUT
- [x] T-107 — Sauvetage et spectateur
  - Résultat vérifiable : état capturé à genoux, appel à l'aide (bruit `CALL`), libération en maintenant E 4 s (bruit `RESCUE`), fusible lâché, élimination à la deuxième prise, vue spectateur qui suit un coéquipier ; solo inchangé ; tests GUT de la règle
  - Dépend de : T-100
  - Fait le 13/11/2026 : `CaptureState` (sur la salle, un par chassé) : pris une fois, le chassé est capturé à genoux sur place, ne bouge ni n'agit (`Player.held`), appelle à l'aide (bruit `CALL`, 8 m toutes les 3 s) ; un coéquipier libre qui maintient E 4 s à moins de 1,5 m le libère (bruit `RESCUE`, 15 m, au début et à la fin). Ses fusibles tombent à ses pieds (`DroppedFuse`, se ramassent comme dans un boîtier, copiés chez les clients). Pris une deuxième fois : éliminé, il quitte la carte et regarde un coéquipier encore en jeu (`SpectatorView`, la salle lui envoie ce que voit ce coéquipier ; clic ou E pour changer). Le monstre gagne quand aucun chassé n'est libre ; un capturé ne peut pas sortir. Le monstre IA laisse le capturé et repart en patrouille (il ignore l'appel, le sauvetage l'attire), le reprend en chasse une fois libéré. Chez les autres, le capturé est à genoux, avec l'invite « Maintenir E : libérer ». Solo inchangé ; 9 tests GUT
- [x] T-101 — IA de complément
  - Résultat vérifiable : la proie IA joue aux côtés des chassés humains (et sauve un capturé quand c'est sûr), le monstre IA prend la place d'un monstre absent
  - Dépend de : T-107
  - Fait le 13/11/2026 : sur la salle, chaque place de chassé vide reçoit une proie IA (`Prey`) à son point d'apparition : elle joue la boucle avec l'équipe (fusibles, transformateur, sortie), suit la règle de capture (`CaptureState`, à genoux, sauvable, éliminée à la deuxième prise), se fait attraper par le monstre IA ou humain, et apparaît chez les clients comme les autres chassés. En cherchant, elle va libérer un coéquipier capturé à moins de 80 m, ou prendre un fusible tombé tant qu'il en manque, seulement si le monstre est à plus de 25 m de là (sinon c'est un piège) ; elle reste immobile pendant qu'elle maintient E. La place du monstre vide est jouée par le monstre IA (déjà le cas). 5 tests GUT dont 3 de comportement sur la cité
- [x] T-102 — Départs et coupures
  - Résultat vérifiable : jeton de reprise, place gardée 10 s puis prise par une IA, retour possible avant la fin, chef transmis, salle arrêtée sans humains
  - Dépend de : T-101
  - Fait le 13/11/2026 : la salle donne à chaque joueur un jeton de reprise (`RoomLink.tokens`, gardé par le client dans `user://resume.cfg`, le stockage du navigateur sur le web). Un joueur qui part d'une partie en cours garde sa place : `seat_keep_time` (10 s) plus tard, une proie IA ou le monstre IA la prend là où il était, avec ce qu'il portait, ses prises et son état (capturé, éliminé) ; les autres ne voient pas de changement (même place). Revenu avec son jeton avant la fin, il reprend la place de l'IA là où elle en est, et sa carte reçoit l'état de la partie (`say_ready` puis `WORLD`). Un client coupé se reconnecte seul ; si la salle ne répond plus, il revient au menu en ligne. Le chef qui part passe son rôle au joueur suivant ; les places des absents sont libérées à la fin de la partie ; la salle sans humain s'arrête après `room_idle_timeout`, partie en cours comprise. En passant : le premier état de la carte était envoyé avant que le client l'ait chargée. 7 tests GUT ; `net_rejoin` (CI) coupe et reprend une partie contre le serveur exporté
- [x] T-103 — Test automatique à 4 clients
  - Résultat vérifiable : la CI lance l'accueil, une salle et 4 clients sans affichage, avec 75 ms de retard ajouté, et joue une partie scriptée de bout en bout (fusibles, capture, sauvetage, sortie) ; charge du serveur mesurée
  - Dépend de : T-102
  - Fait le 13/11/2026 : `tools/godot/net_match.tscn`, lancé 4 fois en parallèle par la CI contre le serveur exporté (75 ms de retard sur chaque message). Le premier crée la partie et joue le monstre, les trois autres rejoignent avec le code. Chacun se dirige comme un joueur (touches et regard, en suivant le maillage de navigation) : chaque chassé prend le fusible d'un boîtier, le monstre attrape celui de la place 2 à son boîtier puis s'éloigne, un coéquipier le libère, il reprend son fusible tombé, les trois posent leurs fusibles au transformateur et sortent. Les processus se disent leur étape par des fichiers. 6 parties d'affilée gagnées par les chassés en local, en 2 à 4 min. La salle mesure sa charge et l'écrit toutes les 30 s (temps de ses images physiques, mémoire) : environ 2,3 ms en moyenne, moins de 7 ms au pire, et 109 Mo, pour 4 joueurs.
- [x] T-108 — Mise en ligne du serveur **(Maxime crée le compte)**
  - Résultat vérifiable : serveur (VPS XS d'IONOS, choix de Maxime du 14/11/2026 à la place de Hetzner, D-016) et nom de domaine créés par Maxime, secrets de déploiement dans GitHub ; `setup.sh` passé, job `deploy` sur `main`, le jeu web est servi par le serveur sur `https://<domaine>/` (demande de Maxime du 14/11/2026 : plus besoin d'itch.io pour jouer en ligne) et `wss://<domaine>/lobby` y répond
  - Dépend de : T-094
  - Fait le 14/11/2026 : VPS XS d'IONOS (x86_64, Ubuntu 24.04) et domaine DuckDNS `echo404.duckdns.org` créés par Maxime, `setup.sh` passé, secret `ECHO_DEPLOY_KEY` et variable `ECHO_HOST` dans GitHub. Chaque fusion sur `main` déploie le serveur et le jeu web (envoi par ssh, sans sftp) ; Caddy sert le jeu sur `https://echo404.duckdns.org/` et ses routes sont rechargées à chaque déploiement par son API locale. Maxime a créé une partie depuis ce site et vu le code. Connexion SSH par clé seulement. PRs #97 à #102
- [x] T-110 — Nombre de joueurs et rôles au hasard
  - Résultat vérifiable : dans le salon, le chef choisit combien jouent (2 à 4 : le monstre et 1 à 3 chassés) ; au lancement les rôles sont tirés au hasard, un joueur est toujours le monstre (demande de Maxime du 15/11/2026)
  - Dépend de : T-096, T-107
  - Fait le 15/11/2026 : entrée « Joueurs : N » pour le chef (2, 3, 4, jamais moins que les joueurs présents), places au-delà fermées et cachées, partie pleine au-delà ; `LobbyState.deal()` tire le monstre et l'ordre des chassés, les places de chassé restantes sont jouées par des IA. Le choix manuel des places (Prendre, Échanger) disparaît. La CI joue aussi `net_spectate` (3 clients) : un chassé attrapé deux fois regarde un coéquipier, un clic passe au suivant. Tests GUT : taille de partie, partie à 2, tirage, places fermées sur la carte
- [ ] T-104 — Partie à 4 navigateurs **(Maxime)**
  - Résultat vérifiable : Maxime et 3 personnes jouent une partie complète ; retours notés dans la spec
  - Dépend de : T-103, T-108
- [ ] T-105 — Vérification finale de S-010
  - Résultat vérifiable : critères cochés, performance tenue avec 4 joueurs, spec livrée
  - Dépend de : T-104

> **Point de décision n°3** (T-090, T-091) : faut-il un serveur payant ? Coûts et hébergement tranchés avant le moindre code réseau.

---

## Phase 11 — Personnages et animations (S-011)

**But** : plus aucune forme géométrique provisoire. Le monstre définitif part des maquettes du Boucher (07/11/2026, `echo-captures/monstre-v5-*`) ; les chassés sont des habitants ordinaires de la cité, reconnaissables entre eux en multijoueur.

**Terminé quand** : plus aucune forme provisoire n'est visible, dans les deux rôles et en multijoueur, sous le budget de performance.

- [ ] T-120 — Spec S-011
  - Résultat vérifiable : spec validée (monstre retenu, nombre et allure des chassés, bras visibles ou non en vue subjective)
  - Dépend de : T-105
- [ ] T-121 — Plan et tâches de S-011
  - Résultat vérifiable : `plan.md` (squelettes, sources d'animations CC0, budget de triangles) et `tasks.md`
  - Dépend de : T-120
- [x] T-122 — Modèle du monstre
  - Résultat vérifiable : script dans `tools/blender/`, 2 500 triangles au plus, textures de 64 à 256 px ; rendus validés par Maxime
  - Dépend de : T-121
  - Fait le 14/11/2026 : le chasseur, piste B choisie par Maxime (masque blanc fêlé à deux yeux rouges, 2,30 m, bras griffus étirés), `tools/blender/hunter.py`, 2 438 triangles
- [x] T-123 — Squelette et animations du monstre
  - Résultat vérifiable : rôder, marcher, courir, scanner, ouvrir une cachette, écraser un réveil, attraper
  - Dépend de : T-122
  - Fait le 15/11/2026 : repos, rôder, marcher, courir, scanner, ouvrir une cachette, attraper, écraser un réveil, en jeu (IA et vue des chassés en ligne)
- [x] T-124 — Modèles des chassés
  - Résultat vérifiable : une variante par chassé (Q-002), 800 à 2 500 triangles, base CC0 adaptée au style ; rendus validés par Maxime
  - Dépend de : T-121
  - Fait le 14/11/2026 (avancé à la demande de Maxime, avant la fin de S-010) : les trois chassés de « Le Réseau », sans nom (ambulancier, parka, masque), sur la base CC0 Universal Base Characters de Quaternius, 2 377 à 2 478 triangles, validés par Maxime le 14/11. Script unique `tools/blender/hunted.py` (sources CC0 dans `art_src/quaternius_ubc/`) qui écrit `assets/models/hunted/*.glb` : un seul maillage skinné par chassé, textures de tissu en vraies UV, filtrage Nearest
- [x] T-125 — Animations des chassés
  - Résultat vérifiable : marcher, courir, accroupi, lancer, ramasser, réparer, entrer et sortir d'une cachette
  - Dépend de : T-124
  - Fait le 15/11/2026 : repos, marche, course, accroupi (à l'arrêt et en marche), à genoux (capturé), lancer, ramasser ou poser, travailler des mains (réparer, cachette, libérer), faits par `tools/blender/hunted.py` en tournant les os
- [x] T-126 — Intégration en jeu et en réseau
  - Résultat vérifiable : arbres d'animation pilotés par l'état synchronisé (S-010) ; IA comprises ; tests GUT sur le choix de l'animation
  - Dépend de : T-123, T-125
  - Fait le 15/11/2026 : `HuntedBody` montre un des trois chassés (place 1 à 3 en ligne, ordre des proies IA hors ligne) et choisit l'animation selon l'allure (déjà dans l'instantané), la vitesse et la capture, réglages dans `hunted_body_settings.tres` ; branché sur `Prey` et `NetPuppet` ; corps caché dans la vue spectateur ; aucun modèle sur le serveur dédié ; gestes envoyés dans l'instantané (un entier par joueur vu)
- [x] T-127 — Capture
  - Résultat vérifiable : séquence de capture vue par le chassé, qui respecte la règle des 2 secondes (2.3)
  - Dépend de : T-126
  - Fait le 15/11/2026 : la tête du chassé se tourne vers le monstre qui le saisit, 1,2 s, puis l'écran ; en solo et en ligne
- [ ] T-128 — Vérification finale de S-011
  - Résultat vérifiable : critères cochés, mesure de performance avec 4 personnages animés, spec livrée
  - Dépend de : T-127

---

## Phase 12 — Audio complet (S-012)

**But** : le jeu se joue au casque, et on sait d'où vient chaque son. Les sons déjà faits (ambiance, boucle, ruses) sont repris et mixés.

**Terminé quand** : la direction des sons est claire au casque, et chaque bruit de jeu a un son qui correspond à sa portée.

- [ ] T-140 — Spec S-012
  - Résultat vérifiable : spec validée
  - Dépend de : T-128
- [ ] T-141 — Plan et tâches de S-012
  - Résultat vérifiable : `plan.md` (bus audio, atténuation, occlusion) et `tasks.md`
  - Dépend de : T-140
- [ ] T-142 — Spatialisation et occlusion
  - Résultat vérifiable : sons en 3D, étouffés derrière un mur selon la même règle que le `NoiseBus` (S-002) ; tests GUT sur le calcul d'occlusion
  - Dépend de : T-141
- [ ] T-143 — Pas selon le sol
  - Résultat vérifiable : béton, gravier, métal, carrelage, flaques, pour les chassés et le monstre (raclement en marche) ; sons faits par nous, montrés à Maxime
  - Dépend de : T-142
- [ ] T-144 — Le vent de la cité
  - Résultat vérifiable : règle de zone de la section 6.4 (rafales qui réduisent la portée des petits bruits en extérieur), audible et lisible pour le monstre ; tests GUT
  - Dépend de : T-142
- [ ] T-145 — Voix du monstre
  - Résultat vérifiable : souffle, grognement, cri de capture, son du scan ; montrés à Maxime
  - Dépend de : T-142
- [ ] T-146 — Musique minimale et tension
  - Résultat vérifiable : nappes qui montent quand le monstre approche, sans trahir sa position exacte ; montrées à Maxime
  - Dépend de : T-142
- [ ] T-147 — Mixage
  - Résultat vérifiable : bus maître, effets, ambiance, musique, voix ; niveaux mesurés ; prêts pour les réglages de S-013
  - Dépend de : T-143, T-144, T-145, T-146
- [ ] T-148 — Vérification finale de S-012
  - Résultat vérifiable : critères cochés, taille du build sous 60 Mo, spec livrée
  - Dépend de : T-147

---

## Phase 13 — Interface, menus et options (S-013)

**But** : un joueur inconnu lance le jeu, règle ce qu'il veut et retrouve ses réglages à la visite suivante.

**Retour de Maxime (13/11/2026)** : le salon en ligne de T-096 (créer, rejoindre, places) est une version de test ; son design est à reprendre ici avec les autres menus.

**Avancée (14/11/2026)** : à la demande de Maxime, le design des menus commence avant les phases 11 et 12. Spec : `specs/S-013-interface-et-menus/spec.md` ; style A « Sodium et digicode » choisi par Maxime.

**Terminé quand** : chaque menu se parcourt à la souris et au clavier, et les réglages survivent à un rechargement de la page.

- [x] T-160 — Spec S-013
  - Résultat vérifiable : spec validée
  - Dépend de : T-148
- [x] T-161 — Plan et tâches de S-013
  - Résultat vérifiable : `plan.md` et `tasks.md`
  - Dépend de : T-160
- [x] T-162 — Menu principal définitif
  - Résultat vérifiable : jouer seul, jouer en ligne, options, crédits ; écran titre avec le nom retenu ou provisoire
  - Dépend de : T-161
- [x] T-163 — Options
  - Résultat vérifiable : volumes par bus, sensibilité, inversion, champ de vision, luminosité, qualité (brouillard, ombres), clavier AZERTY ou QWERTY et touches modifiables ; enregistrées dans `user://` ; tests GUT
  - Dépend de : T-162
- [x] T-169 — Jouer en ligne : digicode et interphone
  - Résultat vérifiable : salon en ligne refait au style choisi (T-160)
  - Dépend de : T-162
- [x] T-164 — Pause et menus en partie
  - Résultat vérifiable : en solo la partie s'arrête, en ligne elle continue ; quitter proprement
  - Dépend de : T-162
- [ ] T-165 — HUD final
  - Résultat vérifiable : HUD des deux rôles repris sur la base 640 × 360 (D-011), lisible à toutes les tailles d'écran
  - Dépend de : T-161
- [ ] T-166 — Écran de chargement et premiers pas
  - Résultat vérifiable : chargement sous 10 s affiché avec une progression ; conseils de premier lancement pour chaque rôle
  - Dépend de : T-162
- [ ] T-167 — Crédits en jeu
  - Résultat vérifiable : contenu de `CREDITS.md` affiché dans le jeu
  - Dépend de : T-162
- [ ] T-168 — Vérification finale de S-013
  - Résultat vérifiable : critères cochés, spec livrée
  - Dépend de : T-163, T-164, T-165, T-166, T-167

---

## Phase 14 — L'hôpital dans la cité (S-014)

**But** : un hôpital abandonné, **intégré à la cité des Tilleuls** (D-019, 15/11/2026), qui devient le bâtiment le plus effrayant de la map : un grand bâtiment visitable sur plusieurs niveaux, qui se joue autrement que les autres, en réutilisant toute la chaîne déjà construite (portes et cachettes de S-016).

**Règles de zone** (section 6.4) : ventilation qui couvre les petits bruits, moniteurs qui bipent, brancards et fauteuils roulants bruyants, nombreuses cachettes (lits, placards).

**Ce qui doit le rendre effrayant** (à préciser dans la spec, rendus montrés à Maxime) : néons verts qui grésillent ou meurent, longs couloirs où la vue porte loin mais où l'on ne voit pas le bout, sous-sols (morgue, chambres d'isolement), traces d'évacuation précipitée, sons lointains qui ne viennent de nulle part, très peu de lumière. Planche d'ambiance du 15/11/2026 (façade, couloir, morgue, chambre d'isolement) : rendus de `tools/blender/hospital_mood.py`, validés par Maxime (« toutes les ambiances me conviennent »).

**Terminé quand** : une partie complète dans la cité avec l'hôpital se joue en solo et en ligne, sous le budget de performance.

- [ ] T-180 — Spec S-014
  - Résultat vérifiable : spec validée (emplacement dans la cité : à la place d'une barre en façade ou en agrandissant la map, taille, nombre d'étages, ailes visitables, ce que devient le scan dans un grand bâtiment, place des fusibles, si la prison de S-018 y déménage)
  - Dépend de : T-168
- [ ] T-181 — Plan sur papier de l'hôpital
  - Résultat vérifiable : plan dessiné (comme `plan-map.svg` de S-006), validé par Maxime
  - Dépend de : T-180
- [ ] T-182 — Plan et tâches de S-014
  - Résultat vérifiable : `plan.md` et `tasks.md`
  - Dépend de : T-181
- [ ] T-183 — Greybox sur plusieurs niveaux
  - Résultat vérifiable : l'hôpital ajouté au générateur de la cité (`build_tilleuls`), escaliers, navigation des IA entre étages et avec le reste de la cité ; tests GUT
  - Dépend de : T-182
- [ ] T-184 — Scan par aile ou par étage
  - Résultat vérifiable : la règle retenue en T-180 marche pour le monstre joueur et le monstre IA ; tests GUT
  - Dépend de : T-183
- [ ] T-185 — Portes mobiles (faites en S-016, T-232 à T-234 : l'hôpital les réutilise)
  - Résultat vérifiable : ouvrir et fermer une porte fait un bruit de 6 m (section 6.2) et coupe la vue ; le monstre les ouvre ; tests GUT
  - Dépend de : T-183
- [ ] T-186 — Ventilation et moniteurs
  - Résultat vérifiable : zones où les petits bruits sont couverts, moniteurs qui bipent et qu'on peut faire sonner ; tests GUT
  - Dépend de : T-183
- [ ] T-187 — Brancards et fauteuils roulants
  - Résultat vérifiable : objets qu'on pousse pour bloquer ou faire diversion, bruyants ; tests GUT
  - Dépend de : T-183
- [ ] T-188 — L'hôpital dans la boucle de partie
  - Résultat vérifiable : emplacements de fusibles, cachettes (lits, placards) et ruses placés dans l'hôpital ; la boucle de la cité (transformateur, tunnel) reste la même
  - Dépend de : T-184, T-185, T-186, T-187
- [ ] T-189 — Assets de l'hôpital
  - Résultat vérifiable : kit de couloirs, chambres, carrelage, néons verts, mobilier ; scripts dans `tools/blender/` ; rendus validés par Maxime
  - Dépend de : T-182
- [ ] T-190 — Habillage et éclairage précalculé
  - Résultat vérifiable : map habillée, néons qui grésillent, budget de lumières tenu
  - Dépend de : T-188, T-189
- [ ] T-191 — Ambiance sonore de l'hôpital
  - Résultat vérifiable : ventilation, bourdonnement des néons, bruits lointains ; montrée à Maxime
  - Dépend de : T-190
- [ ] T-192 — IA à l'hôpital
  - Résultat vérifiable : monstre IA et proie IA jouent la cité avec l'hôpital sans blocage (simulation de 20 parties) ; la durée moyenne reste dans la cible
  - Dépend de : T-190
- [ ] T-193 — Vérification finale de S-014
  - Résultat vérifiable : critères cochés, performance mesurée sur la machine de référence, spec livrée
  - Dépend de : T-191, T-192

---

## Phase 15 — Finition et publication (S-015)

**But** : le jeu est en ligne et jouable par des inconnus.

**Questions à trancher dans la spec** : Q-001 (nom définitif), Q-007 (gratuit ou payant), Q-011 (langues de sortie).

**Terminé quand** : le jeu est en ligne, et des inconnus le trouvent, le lancent et jouent une partie sans aide.

- [ ] T-210 — Spec S-015
  - Résultat vérifiable : spec validée, Q-001, Q-007 et Q-011 closes
  - Dépend de : T-193
- [ ] T-211 — Plan et tâches de S-015
  - Résultat vérifiable : `plan.md` et `tasks.md`
  - Dépend de : T-210
- [ ] T-212 — Nom, logo et écran titre
  - Résultat vérifiable : nom retenu partout (jeu, dépôt, page), logo validé par Maxime
  - Dépend de : T-211
- [ ] T-213 — Passe d'optimisation
  - Résultat vérifiable : banc d'essai sur les deux maps à 60 images/s sur la machine de référence, build sous 60 Mo, chargement sous 10 s
  - Dépend de : T-211
- [ ] T-214 — Traduction
  - Résultat vérifiable : langues retenues (Q-011) complètes dans `strings.csv`, choix de la langue dans les options
  - Dépend de : T-211
- [ ] T-215 — Export Windows
  - Résultat vérifiable : version PC qui se lance sans installation (section 1, « possible ensuite »)
  - Dépend de : T-213
- [ ] T-216 — Bêta fermée **(Maxime)**
  - Résultat vérifiable : une dizaine de joueurs sur quelques jours ; bugs et retours notés
  - Dépend de : T-212, T-213, T-214
- [ ] T-217 — Corrections de la bêta
  - Résultat vérifiable : bugs bloquants corrigés, retours tranchés dans le journal
  - Dépend de : T-216
- [ ] T-218 — Page de publication
  - Résultat vérifiable : page itch.io avec description, captures, bannière et crédits ; validée par Maxime
  - Dépend de : T-212
- [ ] T-219 — Bande-annonce
  - Résultat vérifiable : vidéo courte montée à partir de parcours de caméra enregistrés en jeu ; validée par Maxime
  - Dépend de : T-217
- [ ] T-220 — Mise en ligne **(Maxime)**
  - Résultat vérifiable : page publique, serveur de jeu en service, lien partagé
  - Dépend de : T-217, T-218, T-219
- [ ] T-221 — Vérification finale de S-015
  - Résultat vérifiable : critères cochés, spec livrée
  - Dépend de : T-220

---

## Intérieurs des bâtiments de la cité (S-016)

**But** : des bâtiments visitables moins vides, avec plusieurs issues, des escaliers, des portes qui font du bruit, des cachettes variées et du mobilier (demande de Maxime, 15/11/2026). Spec validée le 15/11/2026 : [`S-016-interieurs/spec.md`](S-016-interieurs/spec.md). Les portes mobiles de la tâche T-185 (hôpital) sont faites ici, et l'hôpital les réutilisera.

- [x] T-230 — Spec S-016
  - Résultat vérifiable : spec validée par Maxime (plans, portes, cachettes)
  - Dépend de : —
- [x] T-231 — Plan et tâches de S-016
  - Résultat vérifiable : `plan.md` et `tasks.md`
  - Dépend de : T-230
- T-232 à T-244 : détaillées dans [`S-016-interieurs/tasks.md`](S-016-interieurs/tasks.md)

---

## Carte des chassés (S-017)

**But** : une carte du quartier que les chassés ouvrent avec Tab, sans aucun indice sur les fusibles (demande de Maxime, 15/11/2026). Spec : [`S-017-carte/spec.md`](S-017-carte/spec.md).

- [x] T-250 — Spec S-017
- [x] T-251 — Plan de la cité
- [x] T-252 — Écran carte, solo et en ligne

---

## Prison et réseau de la cité (S-018)

**But** : une prison d'où un coéquipier libère les chassés attrapés, sur place ou à distance depuis un terminal, et un réseau de vieux terminaux (caméras, haut-parleurs, rideaux métalliques) qui sert de ruse à distance et fait varier les quêtes d'une partie à l'autre (demande de Maxime, 15/11/2026, D-020). Spec : [`S-018-prison-et-reseau/spec.md`](S-018-prison-et-reseau/spec.md). Commence après la fin de S-016, qui touche aussi la cité.

**Terminé quand** : en ligne, un chassé attrapé va en prison et peut être libéré des deux façons ; les terminaux marchent pour les chassés et le monstre sait les contrer ; chaque partie tire 3 objectifs ; 20 parties simulées sans blocage, budget tenu.

- [x] T-260 — Spec S-018
  - Résultat vérifiable : spec validée par Maxime (libération sur place ou à distance, outils et quêtes tirées au sort)
  - Dépend de : —
- [x] T-261 — Plan et tâches de S-018
  - Résultat vérifiable : `plan.md` et `tasks.md`, emplacements des cages, des terminaux, des caméras, des haut-parleurs et des rideaux sur le plan de la cité
  - Dépend de : T-260, fin de S-016
  - Fait le 16/11/2026 : [`plan.md`](S-018-prison-et-reseau/plan.md) et [`tasks.md`](S-018-prison-et-reseau/tasks.md) ; le terminal du gardien va dans la galerie (90 m des cages) pour tenir les 80 m de Q4
- [x] T-262 — La prison
  - Résultat vérifiable : capture → écran noir → cage ; libération sur place (E 4 s, une cage) ; séjours de 120 s puis 60 s, élimination à la 3e prise, chrono arrêté quand le monstre est à moins de 15 m ; victoire du monstre quand tous sont en prison ou éliminés ; solo inchangé ; tests GUT
  - Dépend de : T-261
  - Fait le 16/11/2026 : trois cages dans le couloir des caves, chrono et lampe, libération à la grille ; voir le compte rendu de [`tasks.md`](S-018-prison-et-reseau/tasks.md)
- [x] T-263 — Terminaux et caméras
  - Résultat vérifiable : s'installer à un terminal (E 1 s, bruit de clavier, écran qui éclaire), voir une caméra ; lumière rouge visible du monstre, caméra cassée par le monstre ; vue des caméras pour le prisonnier ; tests GUT
  - Dépend de : T-262
  - Fait le 16/11/2026 : 6 terminaux et 8 caméras dans la cité, menu du terminal, vue verte des caméras, monstre qui éteint et casse ; voir le compte rendu de [`tasks.md`](S-018-prison-et-reseau/tasks.md)
- [x] T-264 — Terminal du gardien
  - Résultat vérifiable : ouvre toutes les cages en 10 s, sonnerie à la prison ; tests GUT
  - Dépend de : T-263
  - Fait le 16/11/2026 : ligne « Ouvrir les cages » du terminal de la pharmacie ; voir le compte rendu de [`tasks.md`](S-018-prison-et-reseau/tasks.md)
- [x] T-265 — Haut-parleurs et rideaux métalliques
  - Résultat vérifiable : leurres à distance (une fois chacun) et rideaux baissés 20 s (recharge 60 s), selon la spec ; le monstre éteint les terminaux ; tests GUT
  - Dépend de : T-263
  - Fait le 16/11/2026 : 3 haut-parleurs et 2 rideaux dans la cité, au menu des terminaux ; voir le compte rendu de [`tasks.md`](S-018-prison-et-reseau/tasks.md)
- [x] T-266 — Quêtes tirées au sort
  - Résultat vérifiable : 3 objectifs par partie parmi fusible, code, téléchargement et relais ; liste sur l'écran de la carte (Tab), sans position ; solo et en ligne ; tests GUT
  - Dépend de : T-263
  - Fait le 16/11/2026 : code, téléchargement et relais en solo (en ligne avec T-267) ; voir le compte rendu de [`tasks.md`](S-018-prison-et-reseau/tasks.md)
- [x] T-267 — Synchronisation en ligne
  - Résultat vérifiable : prison, terminaux, caméras, rideaux et objectifs synchronisés ; un chassé ne reçoit jamais la position d'un autre, sauf ce qu'il voit sur une caméra ; test à 4 clients
  - Dépend de : T-264, T-265, T-266
  - Fait le 16/11/2026 : objectifs synchronisés, choix de menu des clients acceptés par la salle, `net_match` tape le code ; voir le compte rendu de [`tasks.md`](S-018-prison-et-reseau/tasks.md)
- [x] T-268 — IA
  - Résultat vérifiable : le monstre IA éteint les terminaux et passe voir la prison ; la proie IA fait les nouveaux objectifs et utilise les leurres à distance ; 20 parties simulées sans blocage
  - Dépend de : T-266
  - Fait le 16/11/2026 : la proie IA fait code, téléchargement et relais et déclenche les haut-parleurs ; le monstre IA casse les caméras, éteint les terminaux et repasse par la prison ; délai des relais 25 s ; 20 parties simulées sans blocage ; voir le compte rendu de [`tasks.md`](S-018-prison-et-reseau/tasks.md)
- [x] T-269 — Modèles et sons
  - Résultat vérifiable : terminal, caméra, haut-parleur, rideau, cages ; clavier, disque dur, sonnerie, rideau ; montrés à Maxime avant intégration
  - Dépend de : T-261
  - Fait le 16/11/2026 : 9 modèles et 8 sons faits par script, branchés, rendus montrés à Maxime ; voir le compte rendu de [`tasks.md`](S-018-prison-et-reseau/tasks.md)
- [ ] T-270 — Vérification finale de S-018
  - Résultat vérifiable : critères cochés, budget de 300 appels de dessin et 60 images/s tenus
  - Dépend de : T-267, T-268, T-269
  - En cours le 16/11/2026 : critères vérifiés et 297 appels de dessin au pire point ; reste la mesure des 60 images/s sur la machine de référence, avec T-128

---

## Après la sortie (non planifié)

Idées de la section 6.4 gardées pour plus tard, chacune avec sa propre spec si on la lance : le hall de gare (écho énorme, annonces qui couvrent les bruits), la piscine (bruit doublé, monstre ralenti), une map de parking souterrain, une sortie sur Steam (selon Q-007), d'autres objets lançables.
