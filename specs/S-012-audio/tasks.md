# Tâches — S-012

Chaque tâche est vérifiée par Claude (tests GUT, lint, import et export web, mesure dans le build web avec Playwright). Seuls les sons sont montrés à Maxime, sur une page d'écoute.

- [x] T-140 — Spec S-012
  - Résultat vérifiable : spec validée (phase lancée par Maxime le 17/11/2026)
  - Dépend de : T-128
- [x] T-141 — Plan et tâches de S-012
  - Résultat vérifiable : `plan.md` et `tasks.md`
  - Dépend de : T-140
- [x] T-142 — Spatialisation et occlusion
  - Résultat vérifiable : `SoundMath`, `SpatialSound`, versions étouffées ; tous les bruits de jeu joués en 3D passent par `SpatialSound` ; tests GUT sur les volumes et l'étouffement
  - Dépend de : T-141
- [x] T-143 — Pas selon le sol
  - Résultat vérifiable : 6 sols, flaques (portées 2/8/20 m), `SurfaceMap` générée, mes propres pas, raclement du monstre, `by_monster` en ligne ; sons montrés à Maxime ; tests GUT
  - Dépend de : T-142
- [x] T-144 — Le vent de la cité
  - Résultat vérifiable : rafales (portée des bruits ≤ 6 m divisée par deux dehors), audibles, synchronisées en ligne ; tests GUT
  - Dépend de : T-142
- [x] T-145 — Voix du monstre
  - Résultat vérifiable : souffle, grognement, cri de capture, bourdon du scan, grésillement des lampes ; bus Voix ; sons montrés à Maxime ; tests GUT
  - Dépend de : T-142
- [x] T-146 — Musique minimale et tension
  - Résultat vérifiable : trois nappes, paliers 35 m et 15 m, lents à changer ; montrées à Maxime ; tests GUT sur les paliers
  - Dépend de : T-142
- [x] T-149 — Sons provisoires remplacés
  - Résultat vérifiable : alarme de voiture, appel à l'aide, sauvetage faits par nous ; `PlaceholderSounds` supprimée
  - Dépend de : T-142
- [x] T-147 — Mixage
  - Résultat vérifiable : niveaux mesurés dans le build web (rien au-dessus de −3 dBFS), notés dans la spec ; prêts pour les curseurs de S-013
  - Dépend de : T-143, T-144, T-145, T-146, T-149
- [x] T-148 — Vérification finale de S-012
  - Résultat vérifiable : critères cochés, taille du build sous 60 Mo, spec livrée
  - Dépend de : T-147

## Compte rendu
- T-140, T-141 (17/11/2026) : spec, plan et tâches, PR #167.
- T-142, T-143 (17/11/2026) : autoload `SoundSpace` (et non une classe `SpatialSound`) ; 31 sons de jeu et 28 pas ont leur version étouffée (`tools/audio/muffle.py`) ; 4 pas par sol et 4 raclements (`tools/audio/footsteps.py`) ; `SurfaceMap` de 169 boîtes générée avec la map, 12 flaques dehors (un seul maillage) et 5 au parking ; mes propres pas et mon souffle ; `by_monster` dans les messages de la salle. Sons sur la page d'écoute envoyée à Maxime.
- T-144 (17/11/2026) : `WindGusts` (calendrier tiré d'une graine) et `CityWind` (boucle de vent qui monte de 9 dB, sifflement `gust.wav`, plus sourde dedans) ; pendant une rafale, un bruit dehors de portée ≤ 6 m porte moitié moins loin (`NoiseBus.wind_cut`, `Building.any_contains`) ; en ligne, la force du vent est la 13e entrée de l'état du monde.
- T-145, T-149 (17/11/2026) : bruits `GROWL` (12 m, premier pas de course après 3 s) et `SCREAM` (30 m, à chaque capture : monstre IA, monstre joué seul ou en ligne, cachette ouverte) ; bus Voix envoyé dans Effets ; souffle rauque du monstre, 3 grognements jamais deux fois le même ; `ScanDrone` pour le monstre seul ; grésillement près des lampes du bâtiment scanné. Alarme, appel à l'aide, sauvetage et souffle des chassés faits par nous (`tools/audio/voices.py`), avec leur version étouffée ; `PlaceholderSounds` supprimée.
- T-146 (17/11/2026) : `TensionMusic` lancé par la map (pas sur le serveur) : trois boucles de 32 s (`tools/audio/music.py`) jouées ensemble sur le bus Musique ; paliers 35 m et 15 m, palier tenu 3 s, nappe qui monte en 4 s et descend en 10 s ; le monstre en ligne est suivi par sa marionnette ; en monstre, la pulsation après un bruit entendu à moins de 25 m ; l'effroi pour tous quand la sortie est ouverte.
- T-147 (17/11/2026) : banc de mixage `?mix` dans le build web et mesure Playwright (`tools/web/measure_mix.js`) ; niveaux notés dans la spec, rien au-dessus de −3 dBFS ; `SoundSpace` coupe le fondu de Godot vers `max_distance` ; niveaux par type de bruit dans `AudioSettings` ; le bus Voix passe par le curseur Effets de S-013.
- T-148 (17/11/2026) : critères cochés, build web de 50 Mo (budget 60), spec livrée ; l'avis de Maxime sur la page d'écoute reste attendu.
