# S-020 — Retours de test : réseau d'abord, puis la dynamique de poursuite

**Statut** : en cours (20/11/2026 : pistes P2 ajoutées)
**Phase** : hors feuille de route, demandée par Maxime le 19/11/2026 avec sa « feuille de route des propositions » (catalogue de 52 pistes tiré de ses 8 retours de test, du guide du jeu du 17/11/2026 et du code).
**Source** : le PDF du catalogue, rangé dans les fichiers du projet (`echo-s020/feuille-de-route.pdf`). L'impression s'arrête après U2 : 33 pistes sur 52, dont toutes les P0 et P1.

## Pourquoi
Les testeurs ont vu des saccades et des retours en arrière en ligne, et des poursuites perdues d'avance : rien ne ralentit le monstre, il voit aussi loin que le chassé en plus de l'entendre, et le chassé n'a aucune parade contre son ouïe.

## Règles de la feuille de route
- **Le réseau d'abord** : aucun équilibrage avant T1 à T3. Une partie qui saccade fausse tous les tests de vitesse, de cachette ou de poursuite.
- **E4 (vue du monstre réduite) avant les pièges et les cachettes** : si la nuit protège déjà le chassé, il faudra moins de pièges. (La section des dépendances du catalogue l'appelle « E5 », mais la piste de la vue réduite est E4 dans le catalogue ; E5 est le second souffle.)
- **R1 (pétard) avant le piège dans une cachette** (R6 dans le catalogue, « R7 » dans les dépendances).
- Les valeurs chiffrées (0,8 s, 12 m, 6 s…) sont des points de départ, réglables dans `game/data/`.
- **Méthode de test** après chaque lot : une partie à 2 et une à 3 ou 4, avec les mêmes questions (a-t-on réussi à fuir au moins une fois ? une cachette a-t-elle sauvé quelqu'un ? qui a gagné et en combien de temps ?). Claude la fait en simulation et avec les tests en ligne de la CI (règle du 10/11/2026 : pas de playtest demandé à Maxime).

## Pistes retenues (P0 et P1), dans l'ordre
| Tâche | Piste | Quoi |
|---|---|---|
| T-301 | T1 | Ne plus renvoyer la carte 20 fois par seconde : le chrono et le vent sortent de l'état comparé par `send_world()`, remis à l'heure une fois par seconde |
| T-302 | T2 | Brancards et fauteuils envoyés seulement s'ils ont bougé de plus de 5 cm |
| T-303 | T3 | Mesures réseau dans l'écran F3 : écart de prédiction, taille du message carte, images par seconde du serveur |
| T-304 | T4 | Écran du terminal qui reste affiché : retester après T1, sinon le client se lève tout de suite quand il bouge |
| T-305 | S1 | Rafales de vent moins fortes : `gust_db` 9 → 4, `whistle_db` -10 → -16 |
| T-306 | E4 | Vue du monstre réduite à 12 m : brouillard plus dense pour le rôle de monstre (il voit toujours normalement, D-008) |
| T-307 | E1 | Défoncer une porte en courant fige le monstre 0,8 s |
| T-308 | E3 | Bousculer un brancard en courant fige aussi le monstre 0,8 s |
| T-309 | E2 | Sprint du monstre en jauge : 6 m/s pendant 5 s, puis 5 m/s pendant 4 s |
| T-310 | H1 | Ouvrir une cachette vide fait un bruit de 4 m et fige le monstre 1 s |
| T-311 | H2 | Retenir son souffle : une touche, 6 s sans bruit de pas en marchant ni souffle au scan, recharge 40 s ; caché, à maintenir quand le monstre est à moins de 3 m |
| T-312 | R1 | Pétard assourdissant : posé au sol, il éclate au passage du monstre, plus aucun bruit affiché pendant 6 s |
| T-313 | R2 | Réveil réglable : 5 ou 15 s |
| T-314 | T5 | Aligner le guide et le code sur les IA de complément (une règle à choisir par Maxime) |
| T-315 | N1 | Caméras accrochées au mur le plus proche |
| T-316 | N2 | Clavier du transformateur en boîtier mural |
| T-317 | J2 | Grille de test commune : les mêmes questions après chaque partie, dans un tableau |
| T-318 | J1 | Nettoyer les branches fusionnées du dépôt (avec l'accord de Maxime, une suppression ne se défait pas) |

## Saccades en ligne (demande de Maxime du 19/11/2026), avant le reste
En ligne, le déplacement saccade pour son propre personnage et pour les autres ; en solo, tout est fluide. Deux défauts changent le moindre à-coup du WebSocket (TCP : paquets parfois groupés) en saccade :
- son propre personnage : la salle rejoue la dernière commande reçue à chaque image et annonce le dernier numéro reçu, qui ne correspond pas à l'image simulée ; au sprint, 100 ms d'à-coup donnent environ 0,55 m d'écart et le client se recale à tort ;
- les autres joueurs : chaque instantané est daté à son arrivée ; deux instantanés reçus à 5 ms d'écart font jouer 50 ms de trajet en 5 ms.

| Tâche | Quoi |
|---|---|
| T-319 | Réglages d'atténuation (`net_settings.gd`) : `correction_threshold` 0,5 → 1,0 m, `correction_time` 0,2 → 0,4 s, `interpolation_delay` 0,1 → 0,2 s |
| T-320 | Instantanés datés à l'heure de la salle : numéro d'image physique dans chaque instantané, décalage d'horloge lissé côté client (plus petit décalage sur une fenêtre glissante, ajusté sans saut), tampon et interpolation dans ce repère |
| T-321 | File de commandes côté salle : chaque paquet porte les 4 dernières commandes numérotées ; la salle les range, ignore celles déjà jouées, en joue une par image avec 2 à 3 d'avance, rejoue la dernière sans avancer le numéro si la file est vide, et annonce le numéro réellement joué ; les actions ponctuelles sont rattachées au numéro de leur commande |

Critères : tests dans `test_net_sync.gd` (commandes en rafale, paquet perdu, instantanés groupés) ; `worst_error` sous 0,3 m au sprint en ligne droite avec `debug_latency_ms` à 150, valeur avant et après ; solo inchangé ; gameplay inchangé ; pas de WebRTC.

L3 (README : « monstre aveugle » → vision normale, D-008) est faite par le fil « Évaluer la modularité du code », qui réécrit le README.

## Pistes P2 (cahier de Maxime du 20/11/2026), T-322 à T-342
Le PDF du catalogue s'arrête après U2 : pour les 21 pistes P2, le texte de référence est le cahier envoyé par Maxime le 20/11/2026, résumé ici. Toutes les valeurs chiffrées sont des points de départ, réglables dans `game/data/`. Une branche et une PR par tâche.

### Lot A : sans effet sur l'équilibrage, tout de suite (T-322 en premier)
| Tâche | Piste | Quoi |
|---|---|---|
| T-322 | E8 | Statistiques de poursuite à l'écran de fin : nombre de poursuites, de fuites réussies, distance moyenne. Sert à juger le lot P1. La PR définit « poursuite » et « fuite réussie » |
| T-323 | N4 | L'écran du terminal éclaire à 10 m au lieu de « de loin » |
| T-324 | L1 | Roues rondes : cylindres à 12 faces au lieu de boîtes (`tools/blender/car_park.py`, ligne « Flat tyres », et `tools/blender/outdoor.py`, avec `cylinder()` de `hospital_kit.py`), modèles régénérés |
| T-325 | L2 | Contrôle automatique des placements, branché dans la CI : tout objet du réseau (caméra, terminal, relais) à plus de 30 cm d'un mur ou d'un sol est signalé |
| T-326 | S2 | Pour le chassé, à moins de 15 m du monstre, le vent et la musique perdent quelques décibels pour laisser passer ses pas |
| T-327 | H3 | Caché, un battement de cœur qui accélère avec la proximité du monstre, à partir de `tension_music.gd` sans la dupliquer |
| T-328 | A1 | Une touche pour marquer « monstre ici » ou « objectif ici », vu par les coéquipiers (et pris en compte par les IA si c'est simple) |
| T-329 | U1 | Une bulle la première fois qu'on voit une cachette, un terminal ou un boîtier à fusible, enregistrée pour ne s'afficher qu'une fois |
| T-330 | T7 | Une partie de test en CI avec `debug_latency_ms` et `debug_jitter_ms`, qui échoue si `worst_error` dépasse un seuil ; compléter `net_walk` et `net_match` plutôt que les dupliquer |

### Test du lot P1 avant le lot B
Simulations et tests en ligne de la CI, avec les statistiques de T-322. Si le monstre gagne encore une part raisonnable des parties, le lot B suit. S'il est devenu trop faible, on s'arrête et Claude propose d'abord un réglage, car chaque piste du lot B renforce le chassé.

### Lot B : ruses et réseau, après le verdict du test du lot P1
| Tâche | Piste | Quoi |
|---|---|---|
| T-331 | R6 | Piège dans une cachette vide : un pétard (T-312) ou un réveil, qui se déclenche à l'ouverture |
| T-332 | S3 | Pendant les 8 s de passage du train (`game/audio/ambient_train.gd`), les bruits près de la voie ferrée ne s'affichent pas chez le monstre ; calcul côté salle |
| T-333 | R5 | Fil à canettes tendu en travers d'un passage, qui tinte quand le monstre passe |
| T-334 | R3 | Walkman : un leurre qui joue des pas se déplaçant sur 15 m |
| T-335 | R4 | Fumigène : un nuage de 10 s qui coupe la vue ; le filtre de visibilité de la salle (`sees()`, `net_visibility.gd`) en tient compte |
| T-336 | N3 | Caméras qui balaient : ±35° en 8 s ; la détection côté salle (`camera_sees`) suit l'orientation courante |
| T-337 | N5 | Depuis un terminal, le monstre vu par une caméra est signalé 5 s à toute l'équipe |
| T-338 | E5 | Second souffle du chassé : une fois par minute, 2 s à 6,5 m/s, très bruyant |

### Lot C : gros chantiers, après le lot B
| Tâche | Piste | Quoi |
|---|---|---|
| T-339 | U2 | Trajets de chacun et captures rejoués en accéléré sur la carte, en fin de partie |
| T-340 | E6 | Fenêtres et murets à enjamber : 0,5 s pour le chassé, 1,5 s pour le monstre ; la PR propose d'abord la liste des emplacements |
| T-341 | E7 | Boucles de poursuite : 2 ou 3 circuits par bâtiment (îlot de cuisine, rayons de la galerie, piliers du parking) ; la PR propose d'abord un plan par bâtiment |

### Critères communs aux pistes P2
- Chaque règle de jeu nouvelle a un test GUT qui échoue sans le correctif.
- Les tests en ligne de la CI (`net_walk`, `net_match`, `net_spectate`) passent ; le solo n'est pas cassé.
- Une piste qui change une règle visible du joueur met à jour le guide du jeu s'il est dans le dépôt, et le dit dans sa PR.
- Un choix que le cahier ne tranche pas est proposé dans la PR, pas imposé.

### T-342 (T6) : WebRTC, décision à prendre par Maxime
Pas d'implémentation : seulement la décision, à prendre par Maxime.

**Mesures** (`worst_error` : plus grand écart entre la position prédite par le client et celle de la salle, au sprint en ligne droite, `net_walk`) :

| Connexion simulée | Avant T-319 | Après T-321 |
|---|---|---|
| 150 ms de latence | 0,20 à 0,30 m | 0,10 à 0,20 m |
| 150 ms + 100 ms de rafales (`debug_jitter_ms`) | 0,40 à 0,60 m | 0,10 à 0,50 m |

Le critère de S-020 (sous 0,3 m à 150 ms) est tenu. L'écart qui reste avec 100 ms de rafales vient du TCP sous le WebSocket : un paquet perdu retient tous les suivants, qui arrivent ensuite groupés, et la file de commandes de la salle se vide plus longtemps que son avance de 3 commandes. WebRTC (UDP, paquets non ordonnés) supprimerait ce blocage.

**Ce que WebRTC coûterait** : un serveur de signalisation en plus du WebSocket, un serveur TURN pour les réseaux qui bloquent l'UDP (réseaux d'entreprise, filtres comme Zscaler), l'extension `webrtc-native` à compiler pour le serveur Linux, et une CI à 4 clients plus difficile à monter. Plusieurs jours de travail et un risque de joueurs qui ne peuvent plus se connecter.

**Recommandation de Claude** : ne pas passer à WebRTC maintenant. 100 ms de rafales est un cas dur, plus fort qu'une connexion domestique normale vers un serveur en France ; à 150 ms sans rafale, l'écart est déjà sous le critère. Revoir la question si, en vraie partie, l'écran F3 (T-303) montre souvent un écart de prédiction au-dessus de 0,3 m, ou si le test sous mauvaise connexion de T-330 ne tient pas son seuil. **Maxime décide.**

## Critères d'acceptation
- [ ] En ligne, l'état de la carte n'est envoyé que quand il change (test GUT) ; le chrono et le vent restent à l'heure de la salle.
- [ ] L'écran F3 montre l'écart de prédiction, la taille du message carte et les images par seconde de la salle.
- [ ] Chaque piste P0 et P1 est livrée avec ses réglages dans `game/data/` et ses tests GUT.
- [ ] Après les pistes de poursuite (E1 à E4), une série de parties simulées montre des fuites réussies.
