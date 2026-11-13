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
| 14 | S-014 | Deuxième map : l'hôpital | T-180 à T-209 | Phase 13 |
| 15 | S-015 | Finition et publication | T-210 à T-229 | Phase 14 |

L'ordre suit D-013 (12/11/2026) : le multijoueur passe juste après le test à plusieurs, avant les personnages, l'audio et les menus. Tout ce qui est ajouté avant le réseau (animations, sons d'autres joueurs, menus) devrait sinon être repris pour être synchronisé.

```
S-008 ──► 9 Test à plusieurs ──► DP2 ──► DP3 ──► 10 Multijoueur ──► 11 Personnages ──► 12 Audio ──► 13 Menus ──► 14 Hôpital ──► 15 Sortie
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
- [ ] T-094 — Serveur dédié : accueil et salles
  - Résultat vérifiable : préréglage d'export « Server », modes `--lobby` et `--room`, `RoomCode` testé, une salle lancée par code et arrêtée quand elle est vide ; `tools/server/` (Caddyfile, services, `setup.sh`, `deploy.sh`, README) ; la CI exporte le serveur, le démarre et y connecte 4 clients sans affichage
  - Dépend de : T-093
- [ ] T-095 — Couche réseau du jeu
  - Résultat vérifiable : autoload `NetSession` (solo, client, salle), connexion, version vérifiée, déconnexion, ping affiché avec F3 ; commandes envoyées à 30 /s et appliquées par la salle ; tests GUT avec des pairs locaux
  - Dépend de : T-094, T-106
- [ ] T-096 — Salon (lobby)
  - Résultat vérifiable : `LobbyMenu` : créer, rejoindre avec un code, 4 places, chef, rôles, prêt, lancer ; places vides marquées « IA » ; retour au salon après la fin ; textes dans `strings.csv`
  - Dépend de : T-095
- [ ] T-097 — Synchronisation des chassés
  - Résultat vérifiable : instantanés filtrés à 20 /s, prédiction et rejeu du personnage local, interpolation des autres ; accroupi, course, état caché ; écart prédit et serveur sous le seuil avec 150 ms de ping simulé
  - Dépend de : T-095
- [ ] T-098 — Synchronisation du bruit et du monstre
  - Résultat vérifiable : `NetVisibility` testé ; bruits envoyés au monstre avec leur position, aux chassés seulement s'ils les entendent et sans auteur ; un test lit les messages construits pour un chassé et n'y trouve jamais un joueur qu'il ne voit pas ; scan, lumières qui vacillent et capture synchronisés
  - Dépend de : T-097
- [ ] T-099 — Synchronisation de la boucle de partie et des ruses
  - Résultat vérifiable : fusibles, transformateur, sirène, sortie, bouteilles, réveils, cachettes, alarmes de voiture ; écran de fin pour chaque joueur
  - Dépend de : T-098
- [ ] T-100 — Plusieurs chassés
  - Résultat vérifiable : 3 points d'apparition éloignés, le monstre IA choisit parmi plusieurs cibles, victoire dès qu'un chassé sort, défaite quand aucun n'est libre ; simulation à 3 proies IA sans blocage
  - Dépend de : T-099
- [ ] T-107 — Sauvetage et spectateur
  - Résultat vérifiable : état capturé à genoux, appel à l'aide (bruit `CALL`), libération en maintenant E 4 s (bruit `RESCUE`), fusible lâché, élimination à la deuxième prise, vue spectateur qui suit un coéquipier ; solo inchangé ; tests GUT de la règle
  - Dépend de : T-100
- [ ] T-101 — IA de complément
  - Résultat vérifiable : la proie IA joue aux côtés des chassés humains (et sauve un capturé quand c'est sûr), le monstre IA prend la place d'un monstre absent
  - Dépend de : T-107
- [ ] T-102 — Départs et coupures
  - Résultat vérifiable : jeton de reprise, place gardée 10 s puis prise par une IA, retour possible avant la fin, chef transmis, salle arrêtée sans humains
  - Dépend de : T-101
- [ ] T-103 — Test automatique à 4 clients
  - Résultat vérifiable : la CI lance l'accueil, une salle et 4 clients sans affichage, avec 75 ms de retard ajouté, et joue une partie scriptée de bout en bout (fusibles, capture, sauvetage, sortie) ; charge du serveur mesurée
  - Dépend de : T-102
- [ ] T-108 — Mise en ligne du serveur **(Maxime crée le compte)**
  - Résultat vérifiable : serveur Hetzner et nom de domaine créés par Maxime, secrets de déploiement dans GitHub ; `setup.sh` passé, job `deploy` sur `main`, `wss://<domaine>/lobby` répond depuis le build itch.io
  - Dépend de : T-094
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
- [ ] T-122 — Modèle du monstre
  - Résultat vérifiable : script dans `tools/blender/`, 2 500 triangles au plus, textures de 64 à 256 px ; rendus validés par Maxime
  - Dépend de : T-121
- [ ] T-123 — Squelette et animations du monstre
  - Résultat vérifiable : rôder, marcher, courir, scanner, ouvrir une cachette, écraser un réveil, attraper
  - Dépend de : T-122
- [ ] T-124 — Modèles des chassés
  - Résultat vérifiable : une variante par chassé (Q-002), 800 à 2 500 triangles, base CC0 adaptée au style ; rendus validés par Maxime
  - Dépend de : T-121
- [ ] T-125 — Animations des chassés
  - Résultat vérifiable : marcher, courir, accroupi, lancer, ramasser, réparer, entrer et sortir d'une cachette
  - Dépend de : T-124
- [ ] T-126 — Intégration en jeu et en réseau
  - Résultat vérifiable : arbres d'animation pilotés par l'état synchronisé (S-010) ; IA comprises ; tests GUT sur le choix de l'animation
  - Dépend de : T-123, T-125
- [ ] T-127 — Capture
  - Résultat vérifiable : séquence de capture vue par le chassé, qui respecte la règle des 2 secondes (2.3)
  - Dépend de : T-126
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

**Terminé quand** : chaque menu se parcourt à la souris et au clavier, et les réglages survivent à un rechargement de la page.

- [ ] T-160 — Spec S-013
  - Résultat vérifiable : spec validée
  - Dépend de : T-148
- [ ] T-161 — Plan et tâches de S-013
  - Résultat vérifiable : `plan.md` et `tasks.md`
  - Dépend de : T-160
- [ ] T-162 — Menu principal définitif
  - Résultat vérifiable : jouer seul, jouer en ligne, options, crédits ; écran titre avec le nom retenu ou provisoire
  - Dépend de : T-161
- [ ] T-163 — Options
  - Résultat vérifiable : volumes par bus, sensibilité, inversion, champ de vision, luminosité, qualité (brouillard, ombres), clavier AZERTY ou QWERTY et touches modifiables ; enregistrées dans `user://` ; tests GUT
  - Dépend de : T-162
- [ ] T-164 — Pause et menus en partie
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

## Phase 14 — Deuxième map : l'hôpital (S-014)

**But** : une deuxième map qui se joue autrement, en réutilisant toute la chaîne déjà construite. D'après D-010 et D-012 : plus petite que la cité, sur plusieurs niveaux, choisie au salon (une map par partie).

**Règles de zone** (section 6.4) : ventilation qui couvre les petits bruits, moniteurs qui bipent, brancards et fauteuils roulants bruyants, nombreuses cachettes (lits, placards). Les **portes mobiles**, sorties du périmètre de S-008 (Q10), arrivent ici, puis peuvent revenir dans la cité.

**Terminé quand** : une partie complète se joue à l'hôpital en solo et en ligne, sous le budget de performance.

- [ ] T-180 — Spec S-014
  - Résultat vérifiable : spec validée (taille, nombre d'étages, ailes visitables, ce que devient le scan d'un bâtiment dans un seul grand bâtiment)
  - Dépend de : T-168
- [ ] T-181 — Plan sur papier de l'hôpital
  - Résultat vérifiable : plan dessiné (comme `plan-map.svg` de S-006), validé par Maxime
  - Dépend de : T-180
- [ ] T-182 — Plan et tâches de S-014
  - Résultat vérifiable : `plan.md` et `tasks.md`
  - Dépend de : T-181
- [ ] T-183 — Greybox sur plusieurs niveaux
  - Résultat vérifiable : générateur de la map, escaliers, navigation des IA entre étages, limites fermées ; tests GUT
  - Dépend de : T-182
- [ ] T-184 — Scan par aile ou par étage
  - Résultat vérifiable : la règle retenue en T-180 marche pour le monstre joueur et le monstre IA ; tests GUT
  - Dépend de : T-183
- [ ] T-185 — Portes mobiles
  - Résultat vérifiable : ouvrir et fermer une porte fait un bruit de 6 m (section 6.2) et coupe la vue ; le monstre les ouvre ; tests GUT
  - Dépend de : T-183
- [ ] T-186 — Ventilation et moniteurs
  - Résultat vérifiable : zones où les petits bruits sont couverts, moniteurs qui bipent et qu'on peut faire sonner ; tests GUT
  - Dépend de : T-183
- [ ] T-187 — Brancards et fauteuils roulants
  - Résultat vérifiable : objets qu'on pousse pour bloquer ou faire diversion, bruyants ; tests GUT
  - Dépend de : T-183
- [ ] T-188 — Boucle de partie de l'hôpital
  - Résultat vérifiable : fusibles, équivalent du transformateur (groupe électrogène), sortie, cachettes (lits, placards), ruses placées
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
- [ ] T-192 — IA à l'hôpital et choix de la map
  - Résultat vérifiable : monstre IA et proie IA jouent la map sans blocage (simulation de 20 parties) ; la map se choisit au salon
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

## Après la sortie (non planifié)

Idées de la section 6.4 gardées pour plus tard, chacune avec sa propre spec si on la lance : le hall de gare (écho énorme, annonces qui couvrent les bruits), la piscine (bruit doublé, monstre ralenti), une map de parking souterrain, une sortie sur Steam (selon Q-007), d'autres objets lançables.
