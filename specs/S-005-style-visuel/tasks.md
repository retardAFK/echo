# Tâches — S-005

- [x] T-029 — Rédiger la spec, le plan et les tâches de S-005
  - Résultat vérifiable : spec S-005 validée par Maxime, clarifications Q1 à Q6 répondues, maquettes A, B et C postées
  - Dépend de : —
- [x] T-030 — Nuit, brouillard et textures pixelisées
  - Résultat vérifiable : `visual_settings.tres`, greybox de nuit avec brouillard et textures de béton en Nearest, tests GUT, vérifié dans Chrome
  - Dépend de : T-029
- [x] T-031 — Filtre d'écran et tremblement
  - Résultat vérifiable : réduction des couleurs, tramage, grain et tremblement des sommets, HUD au-dessus du filtre, tests GUT, 60 images/s dans Chrome
  - Dépend de : T-030
- [x] T-032 — Nouveau rendu du scan
  - Résultat vérifiable : assombrissement hors du bâtiment, arêtes pâles, onde, jauge sous le viseur, tests GUT, vérifié dans Chrome
  - Dépend de : T-031
- [x] T-033 — Lampadaire au sodium
  - Résultat vérifiable : modèle validé par Maxime sur rendu, `.glb` dans la greybox avec sa lumière
  - Dépend de : T-029
- [x] T-034 — Banc
  - Résultat vérifiable : modèle validé par Maxime sur rendu, `.glb` dans la greybox
  - Dépend de : T-033
- [x] T-035 — Arbre nu
  - Résultat vérifiable : modèle validé par Maxime sur rendu, `.glb` dans la greybox
  - Dépend de : T-034
- [x] T-036 — Module de façade
  - Résultat vérifiable : modèle validé par Maxime sur rendu, façade répétée dans la greybox
  - Dépend de : T-035
- [ ] T-037 — Playtest « ça ressemble au jeu »
  - Résultat vérifiable : capture validée par Maxime, 60 images/s dans Chrome sur sa machine, notes de playtest remplies
  - Dépend de : T-032, T-036

## Compte rendu
- T-029 (04/11/2026) : spec, plan et tâches de S-005, maquettes d'ambiance A, B et C rendues dans la greybox. Maxime : « Parfait », ambiance A et propositions Q1 à Q6 retenues.
- T-033 (04/11/2026) : lampadaire au sodium (mât hexagonal de 5 m, bras courbé, tête « cobra », 88 triangles, une texture de 64 × 64 px), validé par Maxime sur rendu (« Parfait »). Script `tools/blender/lamppost.py`, source `assets/blender/lamppost_sodium.blend` et modèle `assets/models/lamppost_sodium.glb` en Git LFS, scène `Lamppost` avec sa lumière ocre sans ombre, `RetroProp` force les pixels nets. Deux lampadaires dans la greybox. Les `.blend` sont ignorés par Godot (`.gdignore`). 3 tests GUT.
- T-034 (04/11/2026) : deux bancs tout en béton, à la demande de Maxime (« en béton ça me semble plus effrayant », « beaucoup mieux ») : un sale mais intact (72 triangles) et un crade et cassé (144 triangles, assise brisée, pied arraché, fers rouillés), tachés, moussus et tagués en couleurs ternes (jamais d'orange), texture de 128 × 128 px pour 2 m. Modélisés en direct dans le Blender de Maxime (addon Blender Lab), script `tools/blender/bench.py`. Les bancs et les lampadaires ont maintenant une collision et découpent le maillage de navigation (recalculé, 229 polygones). 4 tests GUT pour tous les objets.
- T-035 (04/11/2026) : arbre nu d'hiver (tronc penché de 2,6 m, 4 branches et des rameaux tordus, 300 triangles, écorce de 64 × 64 px), modélisé dans le Blender de Maxime, validé (« parfait pour l'arbre »). Deux arbres dans la greybox avec une collision sur le tronc, maillage de navigation recalculé (244 polygones).
- T-036 (05/11/2026) : module de façade HLM de 3 × 3 m en cinq variantes sales (salissures, coulures, tags ternes), validées par Maxime (« oui parfait ») : fenêtre simple (132 triangles), fenêtre allumée d'une lueur de télé bleutée (132), balcon (240), fenêtre murée en parpaings (72) et porte d'entrée (60). Textures de 256 × 256 px pour 4 m, script `tools/blender/facade.py`. Un petit immeuble de 3 × 3 modules contre le mur nord de la greybox (porte et fenêtres murées au rez-de-chaussée), avec une collision par module, maillage de navigation recalculé (244 polygones). Façades ajoutées aux tests GUT des objets.
- T-030 (05/11/2026) : la greybox passe de nuit (ambiance A). `visual_settings.tres` porte la couleur de la nuit et du brouillard, sa densité (0,035, on voit à environ 25 m), la lumière ambiante bleutée et la lune très faible, appliquées par `NightEnvironment` sur le `WorldEnvironment`. Textures de béton et d'asphalte de 128 × 128 px pour 2 m (64 px par mètre), en Nearest et triplanaires en coordonnées monde, générées par `tools/godot/make_textures.gd`. Enseigne verte d'hôpital au-dessus de la porte du bâtiment, avec sa lumière sans ombre. 5 tests GUT. Vérifié dans le build web dans Chrome (nuit et brouillard présents, aucune erreur) ; les 60 images/s se mesurent sur la machine de Maxime au playtest (T-037), le Chrome du conteneur rend sans carte graphique.
- T-031 (05/11/2026) : filtre d'écran `retro_post.gdshader` (24 niveaux par couleur, tramage ordonné 4 × 4, grain qui change 12 fois par seconde) sur une couche entre le monde et le HUD, donc le HUD et l'orange restent nets. Tremblement des sommets accrochés à une grille de 320 × 180 dans un shader de surface commun (`retro_surface.gdshaderinc`, une version simple face pour la greybox et une double face pour les assets Blender), que `RetroWorld` pose sur tous les matériaux éclairés et opaques de la carte, en gardant la lueur des fenêtres. Tous les réglages viennent de `visual_settings.tres` ; `vertex_snap` à (0, 0) coupe le tremblement. 8 tests GUT (202 au total). Vérifié dans le build web dans Chrome, sans erreur ; 60 images/s à mesurer sur la machine de Maxime (T-037).
- T-032 (05/11/2026) : nouveau rendu du scan (Q5), fait par le plan B du plan : le shader de surface commun sait si chaque pixel est dans le bâtiment scanné. Hors du bâtiment, tout s'assombrit de 70 % et perd 80 % de ses couleurs, le ciel et le brouillard aussi (`NightEnvironment`). Les arêtes du bâtiment s'allument en blanc pâle et une onde pâle part du bâtiment chaque seconde, jusqu'à 12 m. L'effet apparaît et disparaît en 0,3 s (`ScanLook`). Les bruits révélés restent orange (HUD au-dessus). La jauge devient un fin trait pâle sous le centre de l'écran. Tous les réglages dans `visual_settings.tres`. 7 tests GUT (209 au total). Vérifié sur des captures du rendu OpenGL du jeu ; le build web s'exporte et tourne dans Chrome sans erreur de shader, mais je n'ai pas réussi à viser le bâtiment au scan dans le Chrome automatisé, à vérifier au playtest (T-037).
- T-032, suite (05/11/2026) : Maxime aime l'assombrissement mais veut des éléments de viseur. Trois maquettes (A viseur de chasse, B lunette, C cadre d'écoute) ; il choisit « cadre d'écoute fusionné avec viseur de chasse ». `ScanReticle` remplace `ScanBar` : petite croix au centre, et pendant le scan un cadre pointillé aux coins verrouillés autour du bâtiment, sa distance, « ÉCOUTE » (clé `HUD_SCAN_LISTENING`) avec un vumètre de ce que le scan entend, et la jauge sous le cadre. Sans scan, la jauge est un trait sous la croix. Toujours pâle, jamais orange. 3 tests GUT de plus (211 au total). Viseur validé par Maxime (« je valide la dernière proposition viseur (A+C) ») ; la croix centrale reste affichée hors scan pour se repérer.
