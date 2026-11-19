# S-012 — Audio complet

**Statut** : livrée (17/11/2026), en attendant l'avis de Maxime sur la page d'écoute des sons. Validée (17/11/2026) : Maxime a lancé la phase (« on peut partir sur l'audio ») ; les réponses ci-dessous sont les propositions de Claude, retenues sans objection et ajustables à la construction. Les sons sont montrés à Maxime avant d'être intégrés (T-143, T-145, T-146).
**Piliers servis** : P1 (le son trahit), P2 (le dilemme permanent), P3 (l'inquiétante familiarité)
**Phase** : 12 — Audio complet (`specs/BACKLOG.md`)

## Pourquoi
Le cœur du jeu est le son, mais le chassé entend encore des bruits provisoires faits par le code (un « pouf » pour tous les pas, un souffle de bruit blanc), tous au même volume quelle que soit la distance, sans différence derrière un mur. Il n'entend pas ses propres pas, et ne distingue pas les pas du monstre de ceux d'un coéquipier. Le vent de la cité, prévu dans les règles de zone (section 6.4), n'existe que comme une boucle d'ambiance. Il n'y a ni voix du monstre, ni musique. Cette spec fait que le jeu se joue au casque : on sait d'où vient chaque son, à quelle distance, et s'il passe à travers un mur.

## Ce que vit le joueur
**En chassé**, casque sur les oreilles, je traverse le parvis. Mes pas claquent sur le bitume, crissent quand je coupe par la terre battue, puis sonnent creux sur le parquet du 3e de la tour. Je marche dans une flaque : ça clapote, et je sais qu'on m'entend de plus loin. Le vent monte entre les barres, siffle, et pendant quelques secondes il couvre mes pas : j'en profite pour traverser. À gauche, derrière la cloison, un raclement lourd et lent, étouffé : le monstre, de l'autre côté du mur. Il souffle. Une nappe sourde monte dans la musique ; je ne sais pas où il est exactement, mais il n'est pas loin. Je me fige. La nappe redescend doucement. Plus tard, un cri déchire la cité au loin, puis la cloche de la prison : un coéquipier vient de se faire prendre.

**En monstre**, j'entends mes propres raclements. Un pas mouillé, à droite, assez loin : quelqu'un a marché dans une flaque. Je scanne la tour : un bourdonnement sourd me remplit la tête pendant que je me concentre. Je lâche, je cours ; mon grognement part malgré moi, et je sais qu'ils l'ont entendu.

## Récits utilisateur
- En tant que chassé, je veux entendre la direction et la distance de chaque son au casque, et savoir s'il vient de derrière un mur, afin de deviner où est le danger.
- En tant que chassé, je veux reconnaître les pas du monstre de ceux de mes coéquipiers, afin de ne pas fuir un ami ni rejoindre le monstre.
- En tant que chassé, je veux entendre mes pas selon le sol, afin de savoir quand je fais plus de bruit.
- En tant que chassé, je veux profiter du vent pour bouger, afin d'avoir une ruse de plus dehors.
- En tant que monstre, je veux entendre que le vent couvre les petits bruits, afin de comprendre pourquoi j'entends moins et de chercher autrement.
- En tant que joueur, je veux une musique qui monte avec la tension sans me donner la position du monstre, afin d'avoir peur sans tricher.

## Clarifications
- Q1 : Comment rendre la direction claire au casque ? → Proposition :
  - Chaque bruit de jeu est joué **à sa position**, avec un **volume qui dépend de la distance rapportée à sa portée** : fort tout près, faible au bord de sa portée, rien au-delà (comme aujourd'hui pour l'entendre ou non). Ainsi un pas de course à 12 m s'entend faible mais net, un pas de marche à 3 m s'entend clairement.
  - **Panoramique plein** (gauche et droite francs au casque) et un son **un peu plus sourd quand il vient de derrière** (−3 dB), pour distinguer devant et derrière.
  - Le navigateur ne sait pas filtrer les sons en direct dans notre mode audio (mode « samples » de Godot, mesuré) : l'**étouffement** se fait avec une **version filtrée de chaque son**, préparée à l'avance par nos scripts.
- Q2 : Comment un mur étouffe-t-il un son ? → Proposition : **la même règle que le `NoiseBus`** (S-002). Chaque mur divise la portée par deux ; derrière au moins un mur, on joue la version étouffée du son (graves seulement) et on baisse le volume de **8 dB par mur**. Si la portée restante ne suffit pas, on n'entend rien, comme aujourd'hui. Cela vaut pour tous les bruits de jeu, y compris ceux que joue l'objet lui-même (portes, cloche, réveils, bouteilles, terminal…). Les sons d'ambiance (vent, train, ventilation, sons lointains de l'hôpital) ne sont pas concernés : ils ne trahissent personne.
- Q3 : Quels sols ? → Proposition : **6 sols** :
  - **béton** (allées en bitume, caves, parking, paliers), le sol par défaut,
  - **terre** (la pelouse morte de la cité, le sable de l'aire de jeux) : crissement de gravier,
  - **métal** (escaliers de secours, marches d'acier, zones `MetalFloor` de S-016),
  - **carrelage** (halls en terrazzo, couloirs et chambres en lino de l'hôpital, cuisines, faïence),
  - **parquet** (chambres et séjours des HLM, cage du centre social),
  - **flaque** : de nouvelles flaques d'eau, dehors (une douzaine, dans les creux des allées) et au parking.
  Chaque sol a **4 variantes** de pas, tirées au hasard avec un léger changement de hauteur, pour ne jamais entendre deux fois le même pas d'affilée. Le sol se lit dans les zones déjà connues du générateur de la map (revêtement de chaque pièce, allées, aire de jeux), pas dans les textures.
- Q4 : Les sols changent-ils les portées ? → Proposition : **seuls le métal (déjà, S-016) et les flaques**. La section 6.2 dit que « l'eau double » : dans une flaque, un pas de marche porte à **8 m** et un pas de course à **20 m** (accroupi : 2 m). Les autres sols ne changent que le son, pas la portée, pour que la règle reste simple. Le chassé voit les flaques (reflet sombre) et peut les éviter.
- Q5 : Est-ce que j'entends mes propres pas ? → Proposition : **oui**, doucement, au centre (sans position), selon le sol et l'allure : accroupi presque rien, marche discret, course bien audible. Cela aide à sentir quand on fait du bruit. Pareil pour mon souffle quand je suis essoufflé (S-003 : le scan l'entend). Le monstre entend aussi ses propres pas (raclement).
- Q6 : Comment reconnaître le monstre ? → Proposition : ses pas sont un **raclement lourd** (un pied qui frappe et traîne), toujours le même quel que soit le sol, plus grave que ceux des chassés ; son **souffle** est rauque et lent (portée 2 m, D-009). En ligne, chaque bruit envoyé par la salle dit s'il vient du monstre, pour que chaque joueur l'entende avec le bon son.
- Q7 : La voix du monstre ? → Proposition, sans nouvelle commande :
  - **Souffle** : le bruit de 2 m qui existe déjà (D-009), avec un vrai son.
  - **Grognement** : quand le monstre se met à courir après au moins 3 s sans courir, son premier pas de course part avec un grognement (même portée que la course, 12 m). C'est le « monstre pressé se trahit » de la section 6.3, rendu audible. Pour le monstre IA, c'est le début d'une poursuite.
  - **Cri de capture** : quand il attrape un chassé, un cri (bruit de **30 m**). Les coéquipiers proches comprennent ce qui s'est passé, la cloche de la prison (S-018) dit le reste.
  - **Son du scan** : le monstre entend un bourdonnement sourd qui monte pendant sa concentration (pour lui seul, jamais un bruit de jeu). Dans le bâtiment scanné, les lampes qui vacillent **grésillent** doucement là où elles sont : c'est la même alerte discrète que les lumières (D-009), pas un message.
- Q8 : Le vent de la cité ? → Proposition (section 6.4, « vent qui masque les pas ») :
  - Toutes les **25 à 50 s**, une **rafale** de **6 à 10 s**. Le vent monte pendant **2 s** avant (on l'entend arriver), siffle, puis retombe.
  - Pendant une rafale, **dehors seulement** (hors de tout bâtiment), un bruit de portée **6 m ou moins** voit sa portée **divisée par deux** : marcher (4 → 2 m), une porte ouverte doucement, marcher sur du métal (6 → 3 m). Courir, une alarme ou une bouteille cassée s'entendent toujours.
  - Les rafales tombent **au même moment pour tout le monde** (en ligne, la salle les décide et les envoie). Le monstre les entend comme les chassés : quand le vent souffle, il sait que les pas lui échappent. Rien à l'écran : on lit le vent à l'oreille.
- Q9 : La musique ? → Proposition : **pas de mélodie**, trois nappes qui se superposent, sur le bus Musique :
  - **Fond** : une nappe grave, toujours là, très basse.
  - **Malaise** : une pulsation sourde, comme un cœur lent, quand le monstre est à moins de **35 m** d'un chassé.
  - **Effroi** : des cordes aiguës dissonantes quand il est à moins de **15 m**.
  Pour **ne pas trahir sa position exacte** : la distance est lue par paliers, sans tenir compte de la direction, la nappe met **4 s à monter** et **10 s à redescendre**, et un palier ne change pas plus d'une fois toutes les 3 s. On sait que « c'est proche », pas « c'est là ».
  En monstre : le fond, plus la pulsation quand il a entendu un bruit à moins de 25 m dans les 5 dernières secondes. Pour tous : la nappe d'effroi quand la sortie est ouverte (la fin de partie).
- Q10 : Quels bus et quels niveaux ? → Proposition : **Master** (avec un limiteur si le mode audio le permet, sinon des niveaux réglés à l'avance), **Effets** (bruits de jeu), **Voix** (le monstre, les cris, les appels ; envoyé dans Effets, donc réglé par le même curseur d'options), **Ambiance**, **Musique**. Niveaux visés, mesurés dans le build web : un pas de marche à 2 m vers −18 dBFS, l'ambiance vers −30 dBFS, la musique de fond vers −32 dBFS, rien au-dessus de −3 dBFS même quand tout sonne (sirène + alarme + cri). Les curseurs de volume de S-013 ne changent pas.
- Q11 : Que deviennent les sons provisoires ? → Proposition : tous remplacés par des sons faits par nous (Q3, Q6, Q7), y compris l'**alarme de voiture** (et l'ambulance), l'**appel à l'aide** du chassé capturé et le **bruit du sauvetage**. La classe `PlaceholderSounds` disparaît.
- Q12 : Et la taille du build ? → Proposition : sons mono à 22 050 Hz compressés en QOA par Godot, comme ceux d'avant (environ 4 bits par échantillon). Estimation : pas (6 sols × 4 variantes + monstre), versions étouffées, voix, musique (3 boucles de 32 s), alarme et appels : **moins de 2 Mo** dans le build web (48 Mo aujourd'hui, budget 60). Mesuré à chaque tâche.

## Critères d'acceptation
- [x] Au casque, un pas à gauche s'entend à gauche, un pas derrière s'entend plus sourd qu'un pas devant.
- [x] Un pas de course à 3 m s'entend nettement plus fort que le même à 12 m ; au-delà de 14 m, rien.
- [x] Derrière un mur, un pas de course à 5 m s'entend étouffé et plus faible ; derrière trois murs, rien (portée 14 m ÷ 8 < 5 m).
- [x] Mes pas sonnent différemment sur le bitume, la terre, le métal, le carrelage, le parquet et dans une flaque.
- [x] Dans une flaque, ma marche porte à 8 m (jauge et monstre IA).
- [x] Les pas du monstre ne ressemblent pas à ceux d'un chassé, en solo comme en ligne.
- [x] Pendant une rafale, dehors, ma marche ne porte qu'à 2 m ; dedans, rien ne change ; en ligne, la rafale tombe en même temps chez tous.
- [x] Le monstre grogne quand il se met à courir, crie quand il attrape, et entend son scan ; les lampes d'un bâtiment scanné grésillent.
- [x] La musique monte quand le monstre approche et redescend lentement quand il s'éloigne, sans qu'on puisse le localiser avec.
- [x] Il ne reste aucun son provisoire.
- [x] Rien ne sature dans le build web (niveaux mesurés), et le build web reste sous 60 Mo.

Vérifiés par les tests GUT (`test_sound_space`, `test_floor_sounds`, `test_city_wind`, `test_monster_voice`, `test_tension_music`, `test_mix`) et par le banc de mixage dans le build web ; l'écoute au casque reste à confirmer par Maxime.

## Hors périmètre
- Le son 3D « binaural » (HRTF) : le navigateur le permettrait, mais pas le mode audio de Godot sur le web.
- La réverbération calculée en direct (impossible dans notre mode audio) : l'écho des lieux est déjà dans les sons (hôpital, tunnel).
- La voix des joueurs (Q-010).
- Le doublage, les annonces parlées.
- Les sons des menus (les menus de S-013 sont muets ; à voir avec S-015).

## Mixage mesuré (T-147, 17/11/2026)
Banc de mixage dans le build web (`?mix` dans l'adresse, `game/bench/mix_bench.gd`), écouté par le monstre (oreilles à 2 m de haut) sur l'esplanade ; sortie du navigateur mesurée avant les haut-parleurs (`tools/web/measure_mix.js`, Chromium sans écran). Volumes des options par défaut (Master 0,8, Musique 0,7).

| Moment | Crête (dBFS) | Moyenne (dBFS) |
|---|---|---|
| Pas de marche d'un chassé à 2 m devant (2,8 m des oreilles) | −21 à −23 | — |
| Pas de course d'un chassé à 3 m | −14 | — |
| Pas et grognement du monstre à 3 m | −9 à −11 | −26 |
| Mes propres pas de course (le monstre) | −16 | −32 |
| Alarme de voiture à 4 m | −16 | −22 |
| Cri du monstre à 3 m | −13 | −24 |
| Sirène à 6 m | −13 | −22 |
| Musique de fond seule | −15 à −22 | −31 |
| Musique d'effroi (trois nappes) | −15 | −27 |
| Ambiance seule | −13 à −19 | −29 à −32 |
| Tout à la fois (course, alarme, cri, sirène, effroi, ambiance) | **−3,2 à −4,9** | −16 à −17 |

Réglages qui en découlent :
- nappes de musique à −10 dB ;
- alarme −6 dB ; cri −5 dB ; sirène −6 dB ;
- mes propres pas : −26 dB en marche, −14 dB au plus.

Deux défauts trouvés en mesurant, corrigés :
- **Godot étouffait encore nos bruits vers leur portée.** Le fondu propre au moteur, réglé par `max_distance`, s'ajoutait à notre courbe et coûtait jusqu'à −25 dB. `SoundSpace` le coupe maintenant et garde la portée à part.
- **Les bruits courts pouvaient disparaître dans un navigateur trop lent.** En dessous d'environ 10 images/s, le moteur termine un son court avant que le navigateur ne le joue. Le banc coupe donc l'image 3D pour tourner à pleine vitesse. À 60 images/s, cela ne se produit pas.

## Notes de playtest
- (à venir)
