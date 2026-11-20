# S-020 — Grille de test commune (T-317, piste J2)

On pose les mêmes cinq questions après chaque partie de test, quelle que soit la façon dont elle est jouée (simulation, tests en ligne de la CI, partie entre amis). On peut ainsi comparer les versions entre elles. Chaque partie ajoute une ligne au tableau, avec la plus récente en haut.

## Les cinq questions
1. **Qui a gagné ?** Les chassés (sortis), le monstre (tous attrapés) ou personne (partie bloquée à 30 min).
2. **En combien de temps ?** La durée de la partie, en minutes de jeu.
3. **A-t-on réussi à fuir au moins une fois ?** C'est le nombre de poursuites que le monstre a perdues, sans capture à la fin.
4. **Une cachette a-t-elle sauvé quelqu'un ?** On compte les chassés cachés quand le monstre est passé à moins de 5 m, puis ressortis libres.
5. **Combien de captures ?** Celles qui ont lieu avant la fin, libérations comprises.

En ligne, on ajoute une question : **le personnage a-t-il saccadé ?** On note le pire écart de prédiction montré par l'écran F3, ou par `net_walk` en CI.

## Comment remplir
- **Simulation** : lancer `godot --headless tools/godot/simulate_games.tscn -- 4 8 --preys 1`, qui joue l'équivalent d'une partie à 2, puis la même commande avec `--preys 3` pour l'équivalent d'une partie à 3 ou 4. Chaque partie imprime une ligne `GRID | … |`, à coller telle quelle dans le tableau. `TestGrid` (`tools/godot/test_grid.gd`) fait les comptes.
- **CI en ligne** : `net_match` donne le gagnant et la durée, et `net_walk` donne le pire écart.
- **Partie entre amis** : remplir une ligne à la main après la partie, avec le mode « humains ».

## Tableau
| Date | Version | Mode | Chassés | Gagnant | Durée (min) | Fuites | Cachettes qui ont sauvé | Captures |
|---|---|---|---|---|---|---|---|---|
| 2026-11-19 | 5a03673 | simulation | 3 | monstre | 5.0 | 0 | 4 | 2 |
| 2026-11-19 | 5a03673 | simulation | 3 | chassés | 7.4 | 0 | 0 | 1 |
| 2026-11-19 | 5a03673 | simulation | 3 | chassés | 10.4 | 0 | 0 | 2 |
| 2026-11-19 | 5a03673 | simulation | 3 | chassés | 4.5 | 0 | 0 | 2 |
| 2026-11-19 | 5a03673 | simulation | 1 | monstre | 2.0 | 0 | 0 | 1 |
| 2026-11-19 | 5a03673 | simulation | 1 | monstre | 5.7 | 0 | 1 | 1 |
| 2026-11-19 | 5a03673 | simulation | 1 | chassés | 11.4 | 0 | 0 | 0 |
| 2026-11-19 | 5a03673 | simulation | 1 | chassés | 5.4 | 0 | 0 | 0 |

Premières lignes (19/11/2026, IA contre IA, 4 parties à 1 chassé puis 4 à 3) : les chassés gagnent 2 fois sur 4 seuls et 3 fois sur 4 à trois, en 6 à 7 min en moyenne. Le monstre IA perd rarement une poursuite : presque chaque poursuite finit en capture, d'où 0 fuite. Les cachettes ont sauvé 5 fois en tout, dont 4 dans une seule partie à trois, que le monstre a gagnée.

Lignes du 20/11/2026 après S-023 (gadgets au choix, paliers du monstre ; 20 parties IA contre IA, 3 chassés, x8) : les chassés sortent 13 fois, le monstre gagne 6 fois, 1 partie bloquée avant tout objectif (donc sans palier), comme sur main avant S-023.

| Date | Version | Mode | Chassés | Gagnant | Durée (min) | Fuites | Cachettes qui ont sauvé | Captures |
|---|---|---|---|---|---|---|---|---|
| 2026-11-20 | 5a0e898 | simulation | 3 | chassés | 8.7 | 0 | 0 | 1 |
| 2026-11-20 | 5a0e898 | simulation | 3 | chassés | 12.4 | 0 | 0 | 1 |
| 2026-11-20 | 5a0e898 | simulation | 3 | monstre | 4.4 | 0 | 0 | 3 |
| 2026-11-20 | 5a0e898 | simulation | 3 | chassés | 8.8 | 0 | 0 | 0 |
| 2026-11-20 | 5a0e898 | simulation | 3 | monstre | 5.1 | 0 | 0 | 3 |
| 2026-11-20 | 5a0e898 | simulation | 3 | monstre | 1.8 | 0 | 0 | 3 |
| 2026-11-20 | 5a0e898 | simulation | 3 | monstre | 2.6 | 0 | 0 | 3 |
| 2026-11-20 | 5a0e898 | simulation | 3 | chassés | 10.1 | 0 | 0 | 1 |
| 2026-11-20 | 5a0e898 | simulation | 3 | chassés | 5.8 | 0 | 0 | 0 |
| 2026-11-20 | 684d950 | simulation | 3 | bloquée | 30.0 | 0 | 38 | 1 |
| 2026-11-20 | 684d950 | simulation | 3 | chassés | 9.6 | 0 | 0 | 0 |
| 2026-11-20 | 684d950 | simulation | 3 | chassés | 6.2 | 0 | 0 | 0 |
| 2026-11-20 | 684d950 | simulation | 3 | chassés | 5.4 | 0 | 0 | 0 |
| 2026-11-20 | 684d950 | simulation | 3 | monstre | 8.0 | 1 | 0 | 3 |
| 2026-11-20 | 684d950 | simulation | 3 | chassés | 8.6 | 0 | 0 | 1 |
| 2026-11-20 | 684d950 | simulation | 3 | chassés | 9.4 | 1 | 0 | 1 |
| 2026-11-20 | 684d950 | simulation | 3 | chassés | 3.3 | 0 | 0 | 2 |
| 2026-11-20 | 684d950 | simulation | 3 | monstre | 1.5 | 0 | 1 | 1 |
| 2026-11-20 | 684d950 | simulation | 3 | chassés | 10.0 | 0 | 0 | 0 |
| 2026-11-20 | 684d950 | simulation | 3 | chassés | 7.5 | 1 | 0 | 0 |
