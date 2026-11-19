# S-020 — Retours de test : réseau d'abord, puis la dynamique de poursuite

**Statut** : en cours (19/11/2026)
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

L3 (README : « monstre aveugle » → vision normale, D-008) est faite par le fil « Évaluer la modularité du code », qui réécrit le README.

Les P2 lisibles du catalogue (E5, R3 à R6, H3, S2, S3, N3 à N5, A1, U1, U2) suivront, avec leurs propres tâches à partir de T-319.

## Critères d'acceptation
- [ ] En ligne, l'état de la carte n'est envoyé que quand il change (test GUT) ; le chrono et le vent restent à l'heure de la salle.
- [ ] L'écran F3 montre l'écart de prédiction, la taille du message carte et les images par seconde de la salle.
- [ ] Chaque piste P0 et P1 est livrée avec ses réglages dans `game/data/` et ses tests GUT.
- [ ] Après les pistes de poursuite (E1 à E4), une série de parties simulées montre des fuites réussies.
