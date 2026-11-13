# ÉCHO — Document de pilotage du projet

> Document de référence du projet. Tout le travail, humain ou IA, part d'ici.
> Si une décision n'est pas écrite ici ou dans une spec, elle n'est pas prise.
> À placer à la racine du dépôt Git. Version 0.1, 29 octobre 2026.

---

## Sommaire

1. [Vision du jeu](#1-vision-du-jeu)
2. [Constitution : les règles non négociables](#2-constitution--les-règles-non-négociables)
3. [La méthode : Spec Driven Development](#3-la-méthode--spec-driven-development)
4. [Organisation du dépôt](#4-organisation-du-dépôt)
5. [Pipeline des assets Blender → Godot](#5-pipeline-des-assets-blender--godot)
6. [Game design de référence](#6-game-design-de-référence)
7. [Feuille de route de A à Z](#7-feuille-de-route-de-a-à-z)
8. [Modèles de documents](#8-modèles-de-documents)
9. [Glossaire du jeu vidéo pour débutant](#9-glossaire-du-jeu-vidéo-pour-débutant)
10. [Journal des décisions et questions ouvertes](#10-journal-des-décisions-et-questions-ouvertes)

---

## 1. Vision du jeu

**Pitch en une phrase**
Une chasse à l'homme asymétrique dans des espaces liminaux, où chaque bruit trahit la position des chassés auprès du monstre.

**Les 4 piliers** (toute fonctionnalité doit servir au moins un pilier, sinon elle est refusée)

| # | Pilier | Ce que ça veut dire concrètement |
|---|---|---|
| P1 | **Le son trahit** | Chaque action du chassé fait du bruit, et chaque bruit donne sa position et sa distance au monstre. Le chassé n'a que sa ruse et l'environnement pour brouiller les pistes. |
| P2 | **Le dilemme permanent** | Le monstre doit s'arrêter pour scanner un bâtiment, et son scan prévient ceux qui sont dedans. Le chassé doit bouger pour réussir ses quêtes, mais bouger fait du bruit. |
| P3 | **L'inquiétante familiarité** | Lieux réels et vides (cité HLM, hôpital, gare, piscine), de nuit, dans le brouillard. Peu de monstre visible, beaucoup de tension. |
| P4 | **Le rétro qui dérange** | Style low-poly façon PS1 et *Neyasnoe* : basse résolution, textures pixelisées, sommets qui tremblent. |

**Ce que le jeu n'est PAS** (pour éviter de s'éparpiller)
- Pas un jeu de tir, pas de combat pour le chassé.
- Pas un monde ouvert : des maps fermées, grandes mais finies.
- Pas de rendu réaliste.
- Pas de version mobile tactile dans un premier temps.

**Plateforme cible** : navigateur web (export Godot HTML5) en priorité, export PC Windows possible ensuite sans effort supplémentaire.

---

## 2. Constitution : les règles non négociables

La constitution s'applique à tout le projet. On ne la modifie que par une décision écrite dans le [journal des décisions](#10-journal-des-décisions-et-questions-ouvertes).

### 2.1 Stack technique

| Domaine | Choix | Raison |
|---|---|---|
| Moteur | **Godot 4**, dernière version stable, fixée au démarrage et notée dans `project.godot` | Gratuit, léger, exporte vers le web, utilisé par *Neyasnoe* |
| Langage | **GDScript** uniquement | Le seul langage exportable sur le web avec Godot 4, et le plus simple à apprendre |
| Moteur de rendu | **Compatibility** | C'est le seul accepté par l'export web de Godot 4 |
| Modélisation 3D | **Blender** (version stable) | Gratuit, scriptable en Python, ce qui permet à Claude de générer des assets |
| Format d'échange 3D | **glTF binaire (`.glb`)** | Format recommandé par Godot |
| Versionnage | **Git + GitHub**, fichiers lourds via **Git LFS** | Historique, retour arrière, travail avec Claude Code |
| Tests | **GUT** (Godot Unit Test) pour la logique pure | Vérifier le système de bruit et l'IA sans lancer le jeu |
| Agent IA | **Claude Code** dans le dépôt | Implémente les tâches à partir des specs |

### 2.2 Budget de performance

La machine de référence est le portable de développement : Ryzen 5 PRO 215, Radeon 740M intégrée, 16 Go de RAM.
**Si le jeu tourne bien dessus dans un navigateur, il tourne partout.**

| Mesure | Budget |
|---|---|
| Images par seconde | **60 en visée, 30 au minimum absolu** dans Chrome |
| Résolution de rendu | 3D à la **résolution de l'écran**, textures en pixels nets ; interface dessinée sur une base de **640 × 360** agrandie (D-011) |
| Triangles affichés à l'écran | 150 000 maximum |
| Appels de dessin (draw calls) | 300 maximum |
| Lumières dynamiques visibles | 4 maximum, le reste est précalculé |
| Taille du téléchargement web | 60 Mo maximum |
| Temps de chargement d'une map | 10 secondes maximum |

Toute fonctionnalité qui dépasse un budget doit être simplifiée ou faire l'objet d'une décision écrite.

### 2.3 Règles de direction artistique

- **Échelle** : 1 unité Godot = 1 unité Blender = **1 mètre**. Un joueur mesure 1,75 m.
- **Textures** : 64 ou 128 px pour les petits objets, 256 px pour les bâtiments, 512 px maximum. Filtrage **Nearest** (pixels nets).
- **Densité** : environ 64 pixels de texture par mètre, partout, pour que les pixels aient la même taille sur tous les objets.
- **Polygones** : objet décoratif 50 à 500 triangles, bâtiment 500 à 3 000, personnage 800 à 2 500.
- **Palette** : gris béton, ocre des lampadaires au sodium, vert néon d'hôpital, noir. Accent réservé au gameplay : **orange = bruit**. Cette couleur ne sert jamais pour le décor.
- **Éclairage** : précalculé (baking) partout où c'est possible, brouillard obligatoire en extérieur.
- **Le monstre ne se montre pas** côté chassé plus de 2 secondes d'affilée.

### 2.4 Règles de code

- Une scène Godot par entité (joueur, monstre, porte, fusible…), avec un script du même nom.
- Noms : fichiers et dossiers en `snake_case`, classes en `PascalCase`, constantes en `MAJUSCULES`.
- **Aucun chiffre magique** dans le code : les valeurs de gameplay (vitesses, portées de bruit, durées) vivent dans des fichiers de réglage (`Resource` Godot) dans `data/`.
- Les entités communiquent par **signaux**, pas en s'appelant directement de loin.
- Le **système de bruit** est un service central unique (autoload `NoiseBus`) : toute source de bruit passe par lui.
- Toute logique testable sans affichage (calcul de bruit, atténuation, décisions de l'IA) a des tests GUT.
- Le code est écrit en anglais (noms, commentaires). Les textes affichés au joueur sont en français et passent par des clés de traduction.

### 2.5 Règles Git

- `main` est toujours jouable. On n'y pousse jamais directement.
- Une branche par tâche : `feat/T-012-noise-bus`, `fix/T-031-door-sound`, `art/T-040-hlm-facade`.
- Messages de commit : `T-012: ajoute l'atténuation du bruit par les murs`.
- Une pull request = une tâche, relue et testée avant fusion.

### 2.6 Règles pour l'agent IA (Claude)

1. Claude ne code **que** ce qu'une tâche validée demande, et cite l'identifiant de la tâche et de la spec.
2. Si la spec est floue ou contradictoire, Claude **s'arrête et pose la question** au lieu d'inventer.
3. Claude ne modifie jamais la constitution, les specs validées ou le budget de perf sans accord explicite.
4. Claude respecte les budgets de la section 2.2 et le signale quand une demande risque de les dépasser.
5. Chaque tâche livrée contient : le code, les tests si applicable, et une ligne de compte rendu dans la tâche.
6. Les assets générés par Claude passent par des scripts Blender rangés dans `tools/blender/`, jamais par des fichiers modifiés à la main sans trace.
7. Claude met à jour la section « Questions ouvertes » quand il découvre un point non décidé.

### 2.7 Droits et licences

- Uniquement des assets **faits par nous** ou sous licence **CC0** (Kenney, Quaternius, Poly Haven, Freesound filtré en CC0, etc.).
- Chaque asset externe est noté dans `CREDITS.md` : nom, auteur, licence, lien.
- Pas de nom, logo ou personnage d'une œuvre existante. *Neyasnoe* est une inspiration de style, pas une source à copier.

---

## 3. La méthode : Spec Driven Development

### 3.1 Le principe

On écrit **ce qu'on veut** avant d'écrire **comment on le fait**, et le code arrive en dernier. L'IA travaille à partir des documents, pas de souvenirs de conversation. Chaque fonctionnalité suit le même cycle.

```
 1. SPÉCIFIER     →  2. CLARIFIER      →  3. PLANIFIER     →  4. DÉCOUPER
 Quoi et pourquoi    Questions/réponses    Comment, technique   Tâches de 1 à 4 h
        ↑                                                            ↓
 7. METTRE À JOUR ←  6. VÉRIFIER (playtest) ←  5. IMPLÉMENTER (Claude + toi)
```

| Étape | Qui | Document produit | Règle |
|---|---|---|---|
| 1. Spécifier | Toi, aidé par Claude | `specs/S-xxx/spec.md` | Aucune technique ici : on décrit ce que vit le joueur |
| 2. Clarifier | Claude pose les questions, tu tranches | Section « Clarifications » de la spec | On ne passe pas à la suite tant qu'il reste une question bloquante |
| 3. Planifier | Claude propose, tu valides | `specs/S-xxx/plan.md` | Doit respecter la constitution |
| 4. Découper | Claude | `specs/S-xxx/tasks.md` | Une tâche = un résultat vérifiable, 4 h maximum |
| 5. Implémenter | Claude code, tu relis | Code, assets, tests | Une branche et une PR par tâche |
| 6. Vérifier | Toi | Notes de playtest dans la spec | On vérifie chaque critère d'acceptation à la main |
| 7. Mettre à jour | Toi + Claude | Spec, journal des décisions | Si le jeu a changé, la spec change aussi |

### 3.2 Les outils SDD

Ce document fonctionne seul, avec de simples fichiers Markdown. Si tu veux t'entraîner avec un outil dédié (Spec Kit, OpenSpec, BMAD), la correspondance est directe :

| Ce document | Spec Kit | OpenSpec | BMAD |
|---|---|---|---|
| Section 2, Constitution | `constitution.md` | `project.md` | Architecture + règles |
| `spec.md` | `spec.md` | proposition de changement | PRD / story |
| `plan.md` | `plan.md` | `design.md` | Architecture |
| `tasks.md` | `tasks.md` | `tasks.md` | Stories |

Conseil : commence à la main avec ce document sur les 2 premières phases, pour comprendre la logique. Tu adopteras un outil ensuite si tu en ressens le besoin.

### 3.3 Le rituel d'une séance de travail

1. Ouvre Claude Code dans le dépôt.
2. Dis-lui : « Lis `ECHO_PROJET.md` et `specs/S-xxx/`, puis fais la tâche T-yyy. »
3. Claude lit, pose ses questions éventuelles, puis code sur une branche dédiée.
4. Tu lances le jeu dans Godot et tu vérifies les critères d'acceptation.
5. Tu fusionnes, tu coches la tâche, tu notes ce que tu as appris.

---

## 4. Organisation du dépôt

```
echo/
├── ECHO_PROJET.md          ← ce document, la référence
├── CLAUDE.md               ← une ligne : « Lis ECHO_PROJET.md avant toute action »
├── CREDITS.md              ← licences des assets externes
├── README.md               ← comment lancer le projet
├── project.godot
│
├── specs/                  ← une dossier par fonctionnalité
│   ├── S-001-deplacement-joueur/
│   │   ├── spec.md
│   │   ├── plan.md
│   │   └── tasks.md
│   └── ...
│
├── game/                   ← tout ce que Godot charge
│   ├── autoload/           ← services globaux (NoiseBus, GameState)
│   ├── entities/           ← player/, monster/, door/, fuse/ … (scène + script)
│   ├── maps/               ← une scène par map
│   ├── shaders/            ← ps1, post-process
│   ├── ui/                 ← menus, HUD
│   ├── data/               ← fichiers de réglage (.tres)
│   └── assets/
│       ├── models/         ← .glb exportés depuis Blender
│       ├── textures/
│       └── audio/
│
├── art_src/                ← fichiers .blend sources (Git LFS)
├── tools/
│   └── blender/            ← scripts Python de génération d'assets
└── tests/                  ← tests GUT
```

---

## 5. Pipeline des assets Blender → Godot

### 5.1 Le chemin d'un asset

```
Script Python (tools/blender/)  ─┐
                                 ├→ Fichier .blend (art_src/) → Export .glb (game/assets/models/) → Import Godot → Scène
Modélisation à la main ─────────┘
```

### 5.2 Règles Blender

- Unités en mètres, échelle 1.0. **Appliquer les transformations** (Ctrl + A → All Transforms) avant chaque export.
- Origine de l'objet posée **au sol, au centre de sa base**.
- Un fichier `.blend` par asset ou par famille d'assets (`hlm_facade.blend`, `gurney.blend`).
- Nom des objets en anglais, `snake_case`.
- **Collisions** : on ajoute à côté du modèle une forme simple dont le nom finit par `-colonly`. Godot la transforme automatiquement en collision invisible.
- **Deuxième jeu d'UV** (UV2) sur les décors fixes, pour recevoir l'éclairage précalculé.
- Export : `File → Export → glTF 2.0`, format **glTF Binary (.glb)**, option « +Y Up » cochée.

### 5.3 Ce que Claude génère, ce que tu fais

| Type d'asset | Méthode recommandée |
|---|---|
| Bâtiments, murs, couloirs, sols | Script Blender généré par Claude, retouché par toi si besoin |
| Mobilier simple (bancs, brancards, poubelles, lampadaires) | Script Blender par Claude ou pack CC0 |
| Textures (béton, carrelage, façades) | Packs CC0 réduits en basse résolution, ou générées par script |
| Personnages chassés | Pack CC0 low-poly (Quaternius) adapté au style |
| Le monstre | Modélisé à la main, ou par un artiste plus tard. Silhouette provisoire générée par script en attendant |
| Animations | Packs CC0 ou Mixamo, retouchées dans Blender |
| Sons | Freesound CC0 et sons générés, mixés dans Audacity |

---

## 6. Game design de référence

Cette section décrit le jeu cible. Chaque point deviendra une ou plusieurs specs.

### 6.1 Rôles

| | Chassé | Monstre |
|---|---|---|
| Nombre | 3 (prototype : 1, plus des IA alliées éventuelles) | 1 |
| Vue | Vision normale, nuit et brouillard | Vision normale, nuit et brouillard, plus les bruits affichés à leur position avec leur distance |
| Objectif | Trouver 3 fusibles, réparer le transformateur, atteindre la sortie | Attraper tous les chassés avant qu'ils ne sortent |
| Force | Ruse, cachettes, objets de diversion et leurres, connaissance du terrain | Rapide, entend à travers les murs, scan de bâtiment, tue au contact |
| Faiblesse | Lent, fragile, chaque action fait du bruit | Un chassé immobile et silencieux lui échappe s'il ne le voit pas ; le scan l'immobilise et prévient les chassés |

### 6.2 Le système de bruit (cœur du jeu)

Chaque action émet un **événement sonore** : position, intensité, portée, durée.

| Action | Portée de départ (à régler en playtest) |
|---|---|
| Accroupi | 1 m |
| Marche | 4 m |
| Course | 14 m |
| Ouvrir une porte | 6 m |
| Lancer un objet (impact) | 8 m |
| Alarme de voiture | 30 m |

Modificateurs : un **mur** divise l'intensité par deux, l'**eau** la double, la **pluie et le vent** en extérieur réduisent la portée des petits bruits, un **tunnel** ajoute de l'écho.

### 6.3 Le monstre

- **Vision normale** : le monstre voit comme le chassé, de nuit et dans le brouillard (D-008). Il n'y a ni sonar, ni cri, ni clic.
- **Bruits** : chaque bruit qu'il entend (portées de la section 6.2, atténuées par les murs) apparaît en orange à sa position, avec sa distance, et s'efface en 3 s.
- **Scan de bâtiment (focus)** : il vise un bâtiment et maintient une touche. Après 1 s de concentration, il entend en direct tous les bruits de ce bâtiment, même ceux trop faibles pour lui parvenir normalement. Pendant le scan, il est immobile.
  - **Alerte discrète** : dans le bâtiment scanné, les lumières vacillent. Aucun message à l'écran : un chassé qui regarde ailleurs ou qui est dans le noir peut la rater.
  - **Se figer a un prix** : un chassé immobile et silencieux n'apparaît pas, mais le scan entend le souffle d'un chassé essoufflé (environ 10 s après une course), et lâcher une quête en cours (tableau électrique, porte à forcer) fait perdre une partie de sa progression.
  - **Limite** : une jauge de concentration de 8 s de scan au total, qui se recharge en 45 s, et qu'on ne peut pas lancer sous 25 %.
- **Discrétion** : le monstre suit le même système de bruit que le chassé, mais en plus discret. Il est inaudible quand il rôde lentement, s'entend de près quand il marche (environ 3 m), et de loin quand il court (environ 12 m). Son souffle s'entend à moins de 2 m. Le chassé n'est donc jamais prévenu de loin d'un monstre patient, mais un monstre pressé se trahit.

### 6.4 Attracteurs et zones

| Zone | Règle spéciale |
|---|---|
| Cité HLM (extérieur) | Vent qui masque les pas, alarmes de voiture, garage plein de leurres |
| Hôpital | Ventilation qui couvre les petits bruits, moniteurs qui bipent, brancards et fauteuils roulants bruyants, nombreuses cachettes (lits, placards) |
| Hall de gare | Écho énorme, annonces qui couvrent les bruits pendant 10 s |
| Piscine | Bruit doublé, monstre ralenti |
| Parking souterrain | Alarmes de voiture, leurres |

**Ruse du chassé** : objets lancés, leurres sonores, portes fermées pour couper la vue, cachettes. Le but est de faire croire au monstre qu'on est ailleurs.

### 6.5 Boucle de partie

1. Les chassés apparaissent à des points aléatoires, le monstre dans une zone éloignée.
2. Les chassés cherchent les fusibles (positions variables).
3. Une fois les 3 fusibles posés, la sortie s'ouvre et une alarme retentit dans toute la map.
4. Victoire du chassé : au moins un chassé sort. Victoire du monstre : tous les chassés sont attrapés.
5. Durée visée : 8 à 12 minutes.

---

## 7. Feuille de route de A à Z

Chaque phase a un objectif, des livrables et une **définition de « terminé »**. On ne passe pas à la phase suivante tant que la précédente n'est pas terminée. Les durées sont indicatives, pour quelqu'un qui apprend sur son temps libre.

### Phase 0 — Mise en place et apprentissage (1 à 2 semaines)
- Installer Godot, Blender, Git LFS. Créer le dépôt GitHub.
- Suivre le tutoriel officiel « Your first 3D game » de Godot, pour apprendre les nœuds, les scènes et les signaux.
- Créer la structure du dépôt (section 4) et `CLAUDE.md`.
- Faire un export web d'une scène vide et l'ouvrir dans le navigateur.
- **Terminé quand** : une scène vide s'exporte et s'ouvre dans Chrome depuis le dépôt.

### Phase 1 — Le joueur dans une boîte grise (1 semaine)
- Spec S-001 : déplacement en vue subjective (marche, course, accroupi, regard souris).
- Map de test en cubes gris (« greybox »).
- **Terminé quand** : on se déplace confortablement à 60 images/s dans le navigateur.

### Phase 2 — Le système de bruit (1 à 2 semaines)
- Spec S-002 : `NoiseBus`, émission par les actions, atténuation par les murs.
- Outil de debug qui dessine les cercles de bruit à l'écran.
- Jauge de bruit dans le HUD.
- **Terminé quand** : les tests GUT passent et on voit les bruits se propager correctement en debug.

### Phase 3 — Le monstre IA (2 semaines)
- Spec S-003 : monstre contrôlé par l'ordinateur, qui patrouille, entend, enquête, poursuit, perd la trace.
- Navigation avec le système intégré de Godot (NavigationRegion3D).
- **Terminé quand** : en jouant le chassé, le monstre réagit de façon crédible au bruit qu'on fait. Premier test de « fun ».

> **Point de décision n°1** : le concept est-il amusant en gris, sans aucun graphisme ? Si non, on ajuste le game design avant d'aller plus loin.

### Phase 4 — Jouer le monstre (1 à 2 semaines)
- Spec S-004 : vue du monstre, affichage des bruits avec leur distance, scan de bâtiment et sa jauge.
- Chassé contrôlé par une IA simple, pour tester seul.
- **Terminé quand** : on arrive à traquer une proie IA grâce aux bruits et au scan.

### Phase 5 — Le style visuel (2 semaines)
- Spec S-005 : rendu basse résolution, tremblement PS1, réduction des couleurs, brouillard, grain.
- Premiers assets Blender : un module de façade, un lampadaire, un banc, un arbre.
- **Terminé quand** : une capture d'écran « ressemble au jeu », et le budget de perf tient.

### Phase 6 — Première vraie map : la cité des Tilleuls (3 à 4 semaines)
- Spec S-006 : plan de la map sur papier, puis greybox, test, et enfin habillage.
- Taille et bâtiments : 220 × 220 m, une douzaine de bâtiments dont 4 visitables (D-010).
- Éclairage précalculé, sons d'ambiance, lieux horrifiques (balançoire, tunnel, garage).
- **Terminé quand** : la map est jouable du début à la fin, sous le budget de perf.

### Phase 7 — La boucle de partie (1 à 2 semaines)
- Spec S-007 : fusibles, transformateur, sortie, victoire et défaite, écran de fin.
- **Terminé quand** : une partie complète se joue en solo contre le monstre IA.

> **Point de décision n°2** : reporté à la phase 9, après les ruses (voir plus bas).

### Phase 8 — Ruses et attracteurs (1 à 2 semaines)
- Spec S-008 : objets de diversion, leurres sonores, cachettes, alarmes de voiture.
- **Terminé quand** : chaque attracteur change réellement le comportement du monstre ou du joueur.

> Le détail des phases 9 à 15 (specs prévues, tâches T-073 à T-221, dépendances) est dans [`specs/BACKLOG.md`](specs/BACKLOG.md). Le multijoueur passe avant les personnages, l'audio et les menus (D-013).

### Phase 9 — Préparer le test à plusieurs
- Spec S-009 : build de test en ligne, mode banc d'essai, mesure des 60 images/s sur la machine de référence, scan du monstre IA, équilibre des IA, commandes et pause, recueil des retours.
- **Terminé quand** : le lien de test est prêt, les 60 images/s sont mesurées, une partie simulée dure 8 à 12 minutes en moyenne.

> **Point de décision n°2** : version jouable à faire tester à 3 ou 5 personnes de confiance. On note les retours dans le journal.

> **Point de décision n°3** : faut-il un serveur payant ? Coûts et hébergement à étudier avant de commencer la phase 10. → Tranché le 13/11/2026 (D-015) : serveur dédié Hetzner.

### Phase 10 — Multijoueur en ligne (la phase la plus difficile)
- Spec S-010 : architecture réseau. Pour le navigateur, Godot propose WebSocket et WebRTC. Choix à faire dans le plan.
- Lobby, synchronisation des joueurs, du monstre et des bruits, IA pour remplir les places vides.
- **Terminé quand** : 1 monstre et 3 chassés jouent ensemble depuis 4 navigateurs différents.

### Phase 11 — Personnages et animations
- Spec S-011 : modèles des chassés, monstre définitif (à partir des maquettes du Boucher), animations.
- **Terminé quand** : plus aucune forme géométrique provisoire visible.

### Phase 12 — Audio complet
- Spec S-012 : sons spatialisés en 3D, ambiances par zone, vent de la cité, voix du monstre, musique minimale.
- **Terminé quand** : le jeu se joue au casque et la direction des sons est claire.

### Phase 13 — Interface et menus
- Spec S-013 : menu principal, choix du rôle, options (volume, sensibilité, qualité, touches), pause.

### Phase 14 — Deuxième map : l'hôpital
- Spec S-014 : hôpital sur plusieurs niveaux (D-010), portes mobiles, ventilation, brancards, en réutilisant toute la chaîne déjà construite.

### Phase 15 — Finition et publication
- Spec S-015 : corrections, optimisation, nom définitif, page itch.io, captures, bande-annonce courte.
- **Terminé quand** : le jeu est en ligne et jouable par des inconnus.

---

## 8. Modèles de documents

### 8.1 Modèle de spec (`specs/S-xxx/spec.md`)

```markdown
# S-xxx — Titre de la fonctionnalité

**Statut** : brouillon | en clarification | validée | livrée
**Piliers servis** : P1, P2…

## Pourquoi
Le problème ou l'envie, du point de vue du joueur. 2 à 4 phrases.

## Ce que vit le joueur
Description de l'expérience, sans aucune technique.

## Récits utilisateur
- En tant que chassé, je veux … afin de …
- En tant que monstre, je veux … afin de …

## Critères d'acceptation (vérifiables à la main)
- [ ] Quand je cours, la jauge de bruit monte à 9 sur 10.
- [ ] Le monstre IA situé à 10 m derrière un mur m'entend courir, pas marcher.

## Hors périmètre
Ce qu'on ne fait volontairement pas dans cette spec.

## Clarifications
- Q : … → R : … (date)

## Notes de playtest
- (date) ce qui marche, ce qui ne marche pas.
```

### 8.2 Modèle de plan (`specs/S-xxx/plan.md`)

```markdown
# Plan — S-xxx

## Approche technique
Scènes, scripts, nœuds Godot concernés.

## Données et réglages
Fichiers .tres créés, valeurs par défaut.

## Impact sur la performance
Estimation face au budget de la section 2.2.

## Risques et alternatives
Ce qui peut mal tourner, plan B.

## Conformité à la constitution
Points vérifiés, et écarts éventuels à faire valider.
```

### 8.3 Modèle de liste de tâches (`specs/S-xxx/tasks.md`)

```markdown
# Tâches — S-xxx

- [ ] T-001 — Créer l'autoload NoiseBus avec le signal noise_emitted
  - Résultat vérifiable : test GUT « émission reçue par un auditeur »
  - Dépend de : —
- [ ] T-002 — …
  - Résultat vérifiable : …
  - Dépend de : T-001

## Compte rendu
- T-001 (date) : fait, branche feat/T-001-noise-bus, PR #3.
```

---

## 9. Glossaire du jeu vidéo pour débutant

| Terme | Explication |
|---|---|
| **Nœud (Node)** | La brique de base de Godot. Tout est un nœud : une caméra, une lumière, un son, un modèle. |
| **Scène** | Un assemblage de nœuds, sauvegardé et réutilisable. Le joueur est une scène, une porte aussi. |
| **Signal** | Un message envoyé par un nœud quand il se passe quelque chose (« porte ouverte »). D'autres nœuds peuvent l'écouter. |
| **Autoload** | Un script toujours chargé et accessible partout, comme un service global. |
| **Boucle de jeu (`_process`, `_physics_process`)** | Fonctions appelées à chaque image. C'est là que le jeu « vit ». |
| **Greybox** | Version d'une map en formes grises, pour tester le gameplay avant de faire du beau. |
| **Asset** | Tout fichier de contenu : modèle 3D, texture, son, animation. |
| **Low-poly** | Modèles avec peu de polygones, au style volontairement simple. |
| **Shader** | Petit programme exécuté par la carte graphique pour dessiner les pixels. Le tremblement façon PS1 en est un. |
| **Post-process** | Effets appliqués à l'image finale : grain, flou, couleurs. |
| **Baking (précalcul)** | Calculer une fois l'éclairage et l'enregistrer dans une texture, au lieu de le recalculer à chaque image. |
| **UV / UV2** | La façon dont une image 2D est « dépliée » sur un modèle 3D. UV2 sert à l'éclairage précalculé. |
| **Collision** | Forme invisible qui empêche de traverser les objets. |
| **NavMesh** | Carte des zones où une IA peut marcher, utilisée pour trouver un chemin. |
| **Draw call** | Une demande de dessin envoyée à la carte graphique. Trop de draw calls = jeu lent. |
| **FPS** | Images par seconde. 60 = fluide, en dessous de 30 = désagréable. |
| **Playtest** | Session où l'on joue pour vérifier si c'est amusant et si ça marche. |
| **Machine à états** | Façon d'organiser une IA : « patrouille », « enquête », « poursuite »… avec des règles de passage. |
| **Spatialisation audio** | Le son vient de la bonne direction et s'atténue avec la distance. |
| **Autorité réseau** | Qui décide de la « vérité » en multijoueur (un serveur ou un joueur hôte). |

---

## 10. Journal des décisions et questions ouvertes

### 10.1 Décisions prises

| # | Date | Décision | Raison |
|---|---|---|---|
| D-001 | 25/10/2026 | Jeu asymétrique : monstre aveugle à écholocalisation contre chassés (remplacée par D-008) | Concept de départ |
| D-002 | 25/10/2026 | Espaces liminaux réels plutôt que Backrooms officielles | Plus original, chaque lieu a sa règle sonore |
| D-003 | 25/10/2026 | Style low-poly rétro inspiré de *Neyasnoe*, avec des maps extérieures et plus grandes | Choix artistique |
| D-004 | 27/10/2026 | Godot plutôt que Three.js | Éditeur visuel, assets réels, export web et PC |
| D-005 | 29/10/2026 | Méthode Spec Driven Development, assets créés avec Blender | Apprentissage du SDD, travail structuré avec l'IA |
| D-006 | 29/10/2026 | Prototype solo contre IA avant tout multijoueur | Valider le fun avant la partie la plus difficile |
| D-007 | 30/10/2026 | Priorité à un jeu léger et très optimisé : le budget de 60 Mo s'applique à la taille **non compressée** du build Web (le moteur seul en pèse déjà 38), et la CI bloque toute PR qui le dépasse | Aucune lourdeur, chargement rapide dans le navigateur, sur la machine de référence comme ailleurs |
| D-008 | 03/11/2026 | Le monstre voit normalement. Son atout : les bruits lui donnent la position et la distance des chassés, et il peut scanner un bâtiment pour en entendre tous les bruits en direct. Le chassé n'a que sa ruse et l'environnement. La contamination est supprimée, l'hôpital reste un lieu prévu. | Rôle du monstre plus agréable et moins lassant que l'écran noir à sonar ; jeu plus lisible pour les deux camps |
| D-009 | 03/11/2026 | Scan de bâtiment limité par une jauge (8 s, recharge 45 s, seuil 25 %), alerte discrète par les lumières, se figer a un prix (souffle après une course, progression de quête perdue). Monstre discret : inaudible en rôdant, 3 m en marche, 12 m en course, souffle à 2 m | Le scan doit être un pari et non une victoire automatique, et se figer ne doit pas suffire |
| D-010 | 07/11/2026 | Cité des Tilleuls : zone jouable de 220 × 220 m, une douzaine de bâtiments dont 4 visitables, les autres en façades. Un fusible se trouve toujours dans un bâtiment visitable. L'hôpital sera une map séparée, plus petite et sur plusieurs niveaux | Une map assez grande pour qu'un bruit lointain reste un pari pour le monstre, avec des bâtiments visitables qui obligent les chassés à entrer là où le scan les menace |
| D-011 | 10/11/2026 | Rendu net : la 3D est rendue à la résolution de l'écran, sans réduction des couleurs, sans tramage ni tremblement des sommets, avec un grain à peine visible. Les textures restent en gros pixels nets et le brouillard reste | Le rendu basse résolution de S-005, avec son grain et son tramage, faisait mal aux yeux dans une scène de nuit (retour de Maxime sur la cité des Tilleuls) |
| D-012 | 12/11/2026 | Les maps sont séparées : une map par partie (clôt Q-004) | Suite logique de D-010, qui fait déjà de l'hôpital une map à part ; plus simple à construire et à charger dans le navigateur |
| D-013 | 12/11/2026 | Après le test à plusieurs (phase 9), le multijoueur passe avant les personnages, l'audio et les menus. Nouvel ordre : 9 test à plusieurs, 10 multijoueur, 11 personnages, 12 audio, 13 menus, 14 hôpital, 15 sortie (détail dans `specs/BACKLOG.md`) | Ce qui est ajouté avant le réseau devrait sinon être repris pour être synchronisé, et on teste plus tôt à 4 vrais joueurs |
| D-014 | 13/11/2026 | Le test à 3 à 5 personnes (T-083, T-084, point de décision n°2) est reporté : Maxime veut un jeu plus avancé avant de le montrer. La phase 10 (multijoueur) commence sans attendre ; le test sera replanifié plus tard | Maxime a joué le build itch.io et validé les corrections (scan expliqué, objets visibles) |
| D-015 | 13/11/2026 | Point de décision n°3 : multijoueur sur un **serveur dédié** (le projet Godot exporté pour Linux sans affichage fait autorité), connexions WebSocket chiffrées (`wss://`) derrière Caddy, hébergé chez Hetzner (environ 5 €/mois) avec un nom de domaine | Partie indépendante des onglets, secret du bruit garanti, passe les filtres réseau, simple à tester à 4 clients en CI (`specs/S-010-multijoueur/etude-reseau.md`) |

### 10.2 Questions ouvertes

- [ ] **Q-001** : Nom définitif du jeu (« Écho » est provisoire).
- [x] **Q-002** : Combien de chassés au final : 3 ou 4 ? → 3 chassés contre 1 monstre (S-010, Q1, 13/11/2026).
- [x] **Q-003** : Le chassé attrapé est-il éliminé, ou peut-il être sauvé par un coéquipier ? → sauvable une fois par un coéquipier ; attrapé une deuxième fois, il est éliminé et devient spectateur (S-010, Q2, 13/11/2026).
- [x] **Q-004** : Les maps sont-elles reliées entre elles ou séparées ? → séparées, une map par partie (D-012).
- [x] **Q-005** : Multijoueur entre amis seulement, ou matchmaking public ? → entre amis seulement, avec un code de partie ; le matchmaking public pourra revenir avec S-015 (S-010, Q3, 13/11/2026).
- [ ] **Q-006** : Le PC de développement est fourni par l'employeur. Faut-il un PC personnel pour ce projet ?
- [ ] **Q-007** : Projet gratuit ou payant à terme (itch.io, Steam) ? Lien avec la structure envisagée pour publier des applications.
- [x] **Q-008** : Limite du scan de bâtiment → jauge de concentration (D-009).
- [x] **Q-009** : Discrétion du monstre et alerte du scan → voir D-009.
- [x] **Q-010** : Les chassés peuvent-ils se parler en jeu (voix de proximité qui fait du bruit), ou passent-ils par un outil externe ? → pas de voix dans le jeu pour l'instant, outil externe au besoin ; une voix de proximité serait une spec à part, après les premières parties à 4 (S-010, Q4, 13/11/2026).
- [ ] **Q-011** : Langues de sortie : français seul, ou aussi anglais ? À trancher dans S-015.
- [x] **Q-012** : Où héberger le build de test ? → page itch.io en accès restreint, protégée par mot de passe (S-009, Q1, 12/11/2026).
