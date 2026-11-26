# Plan — S-025

## Approche technique
- **Portes** (T-401) : `VersusMode` ouvre et fige toutes les `Door` de la map (groupe des portes, sans toucher au code des portes : une méthode publique générique pour les tenir ouvertes si elle manque). `build_versus_arena.gd` ne pose plus de planches ; le maillage de navigation de l'arène est recuit portes ouvertes. Test : chemins de navigation du départ vers chaque coffre, toit et départ, et un robot qui marche jusqu'à chacun.
- **Vue** (T-402) : `VersusCamera` (bras à ressort derrière l'épaule, collision avec le décor) posée par `VersusMode` sur l'avatar local ; la caméra du joueur reste pour la vue 1re personne (V). Le tir vise le point sous le réticule (rayon de la caméra), puis part de l'arme vers ce point.
- **Armes** (T-403, T-404) : `VersusWeapon` (ressource : cadence, dégâts, dispersion, plombs, chargeur, recharge, portée, automatique, zoom, recul, couleur de traçante) dans `data/weapons/`, référencée par le `VersusItem`. `HitscanShot` (pur : rayons, dispersion tirée au sort avec une graine) ; `Tracer` (trait lumineux qui s'efface en 0,1 s) ; `DamageNumbers` (nombres flottants). Le fusil à fusées de précision tire une `Flare` droite et rapide (pas de gravité) pour garder la traînée.
- **Rareté** (T-404) : `VersusRarity` (ressource : nom, couleur, multiplicateur, poids) ; le coffre tire l'objet puis la rareté.
- **Zone** (T-406) : `VersusZone` (pur : rayon par étape, temps) + un cylindre translucide ; remplace l'aube dans `VersusRules`.
- **Ambiance** (T-405) : un `Environment` de jour propre au Versus, néons (`OmniLight3D` cuits en couleur sur les façades de l'arène), le monstre mis à l'échelle et une matière émissive par phase.
- **En ligne** (T-407) : les tirs à impact immédiat sont calculés par la salle ; un événement par rafale (origine, points d'impact) pour les traçantes des autres ; la zone dans l'instantané.
- **IA** (T-408) : le chassé IA vise avec une dispersion, tire en rafales ; le boss IA sort de la zone ; nouvelle série de simulations.

## Données et réglages
`versus_settings.tres` (temps de partie, zone, dégâts dehors), `data/weapons/*.tres`, `data/rarities/*.tres`.

## Impact sur la performance
Traçantes et nombres : quelques maillages et `Label3D` réutilisés (réserve fixe). Néons : lumière cuite dans les sommets (pas de lumières en temps réel en plus). Mesure des appels de dessin à chaque étape.

## Risques
- La 3e personne montre le modèle du chassé de dos : il faut ses animations de course et de tir (S-011 en a une partie).
- Portes ouvertes : le maillage de navigation et le budget de dessin changent ; à mesurer.
