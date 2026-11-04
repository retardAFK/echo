# Plan — S-005

**Statut** : validé (04/11/2026)

## Approche technique
- **Réglages** (`game/data/visual_settings.gd` + `visual_settings.tres`) : couleurs de la nuit et du brouillard, densité du brouillard, niveaux de couleur, force du tramage et du grain, grille du tremblement, rendu du scan. Aucun chiffre dans les shaders.
- **Nuit et brouillard** (`Environment` de la greybox) : fond et brouillard de la même couleur, lumière ambiante faible et bleutée, lune très faible. Le brouillard de profondeur fonctionne avec le rendu Compatibility.
- **Filtre d'écran** (`game/fx/retro_post.gdshader` sur un `ColorRect` plein écran, couche d'interface au-dessus du monde et sous le HUD) : réduction des couleurs, tramage ordonné 4 × 4, grain. Le HUD (repères de bruit, jauge) reste au-dessus du filtre, donc l'orange reste net.
- **Tremblement** (`game/fx/retro_surface.gdshader`, shader de surface commun) : les sommets sont accrochés à une grille d'écran dans le vertex shader. Texture en filtrage Nearest, coordonnées monde pour la greybox (triplanaire), UV normales pour les assets Blender.
- **Lumières** : lampadaires et enseigne en `OmniLight3D` sans ombre, 4 lumières dynamiques visibles au plus (2.2). L'éclairage précalculé à grande échelle attend la vraie map.
- **Scan** (Q5) : le filtre d'écran reçoit le volume du bâtiment scanné et assombrit et décolore ce qui est hors du volume (profondeur reconstruite dans le shader). Les arêtes du bâtiment s'allument via le shader de surface. Une onde pâle part du bâtiment chaque seconde.
- **Assets** (`assets/models/*.glb`, sources `.blend` dans `assets/blender/`, Git LFS) : modélisés dans le Blender de Maxime via le connecteur, scripts dans `tools/blender/`. Un rendu de 3 angles en basse résolution est posté dans le fil pour validation avant l'export.

## Données et réglages
| Réglage | Valeur par défaut (ambiance A) |
|---|---|
| `fog_color` / `fog_density` | bleu nuit (0,10 ; 0,11 ; 0,13) / 0,035 |
| `color_levels` | 24 par canal |
| `dither_strength` / `grain_strength` / `grain_rate` | 0,6 / 0,03 / 12 par seconde |
| `vertex_snap` | grille de 320 × 180 |
| `scan_dim` / `scan_wave_interval` | 70 % plus sombre hors du bâtiment / 1 s |

## Impact sur la performance
- Un seul passage plein écran en 640 × 360, très léger.
- Le brouillard est intégré au rendu, sans coût notable.
- Quatre assets de 120 à 400 triangles, très loin des 150 000 triangles et 300 appels de dessin.
- Mesure dans Chrome à chaque tâche, comparée au build de la phase 4.

## Risques et alternatives
- **Trop sombre pour jouer** : densité et lumière ambiante dans `visual_settings.tres`, ajustées au playtest.
- **Le tremblement donne mal au cœur** : on le baisse ou on le coupe par réglage.
- **Profondeur indisponible pour l'effet de scan dans le build web** : plan B, l'assombrissement se fait dans le shader de surface (chaque objet sait s'il est dans le volume scanné).

## Conformité à la constitution
- Budgets 2.2 vérifiés à chaque tâche, dans Chrome.
- Règles 2.3 : 1 unité = 1 m, textures 64 à 256 px en Nearest, 64 px par mètre, triangles dans les fourchettes, orange réservé au bruit.
- Aucun chiffre magique : tout dans `visual_settings.tres`.
- Logique testable (réglages chargés, scan qui pilote le filtre) couverte par GUT, et chaque effet vérifié dans le build web (leçon de T-028).
