# Plan — S-011

## Modèles (T-124)
- `tools/blender/hunted.py` construit les trois chassés : base Quaternius (Universal Base Characters, CC0, squelette 65 os type UE) rangée dans `art_src/quaternius_ubc/`, réduite à environ 1 300 à 1 500 triangles ; régions du corps (torse, bras, jambes...) recolorées et gonflées selon les poids des os ; vêtements en tubes (`loft`) liés à un os ; textures 64 px (tissu sali, plaque) et peau 256 px, filtrage Nearest.
- Sortie : `assets/models/hunted_<role>.glb` (maillage skinné + squelette + animations) et `assets/blender/hunted.blend`.
- Budget : 800 à 2 500 triangles par chassé ; une dizaine de matériaux par personnage, soit 40 appels de dessin au plus pour les trois chassés et le monstre.

## Animations (T-125)
- Faites par le même script, en clés sur le squelette : `idle`, `walk`, `run`, `crouch` (marche accroupie), `crouch_idle`, `kneel` (capturé). Boucles d'une seconde ou moins, 30 images/s.

## Intégration (T-126)
- `HuntedBody` (`game/entities/hunted_body/`) : instancie le modèle d'un rôle et choisit l'animation. Le choix est une fonction pure testée : `HuntedBody.pick(gait, speed, down)`.
- `NetPuppet` (chassé) et `Prey` remplacent la capsule par un `HuntedBody` ; le rôle vient de la place (Q5). `NetPuppet` lit l'allure déjà présente dans l'instantané et estime la vitesse entre deux instantanés.
- Le serveur (export « Server ») n'a pas besoin des modèles : `HuntedBody` ne charge rien sans affichage.
