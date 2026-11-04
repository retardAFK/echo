# Tâches — S-005

- [x] T-029 — Rédiger la spec, le plan et les tâches de S-005
  - Résultat vérifiable : spec S-005 validée par Maxime, clarifications Q1 à Q6 répondues, maquettes A, B et C postées
  - Dépend de : —
- [ ] T-030 — Nuit, brouillard et textures pixelisées
  - Résultat vérifiable : `visual_settings.tres`, greybox de nuit avec brouillard et textures de béton en Nearest, tests GUT, vérifié dans Chrome
  - Dépend de : T-029
- [ ] T-031 — Filtre d'écran et tremblement
  - Résultat vérifiable : réduction des couleurs, tramage, grain et tremblement des sommets, HUD au-dessus du filtre, tests GUT, 60 images/s dans Chrome
  - Dépend de : T-030
- [ ] T-032 — Nouveau rendu du scan
  - Résultat vérifiable : assombrissement hors du bâtiment, arêtes pâles, onde, jauge sous le viseur, tests GUT, vérifié dans Chrome
  - Dépend de : T-031
- [x] T-033 — Lampadaire au sodium
  - Résultat vérifiable : modèle validé par Maxime sur rendu, `.glb` dans la greybox avec sa lumière
  - Dépend de : T-029
- [ ] T-034 — Banc
  - Résultat vérifiable : modèle validé par Maxime sur rendu, `.glb` dans la greybox
  - Dépend de : T-033
- [ ] T-035 — Arbre nu
  - Résultat vérifiable : modèle validé par Maxime sur rendu, `.glb` dans la greybox
  - Dépend de : T-034
- [ ] T-036 — Module de façade
  - Résultat vérifiable : modèle validé par Maxime sur rendu, façade répétée dans la greybox
  - Dépend de : T-035
- [ ] T-037 — Playtest « ça ressemble au jeu »
  - Résultat vérifiable : capture validée par Maxime, 60 images/s dans Chrome sur sa machine, notes de playtest remplies
  - Dépend de : T-032, T-036

## Compte rendu
- T-029 (04/11/2026) : spec, plan et tâches de S-005, maquettes d'ambiance A, B et C rendues dans la greybox. Maxime : « Parfait », ambiance A et propositions Q1 à Q6 retenues.
- T-033 (04/11/2026) : lampadaire au sodium (mât hexagonal de 5 m, bras courbé, tête « cobra », 88 triangles, une texture de 64 × 64 px), validé par Maxime sur rendu (« Parfait »). Script `tools/blender/lamppost.py`, source `assets/blender/lamppost_sodium.blend` et modèle `assets/models/lamppost_sodium.glb` en Git LFS, scène `Lamppost` avec sa lumière ocre sans ombre, `RetroProp` force les pixels nets. Deux lampadaires dans la greybox. Les `.blend` sont ignorés par Godot (`.gdignore`). 3 tests GUT.
