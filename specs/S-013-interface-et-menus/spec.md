# S-013 — Interface, menus et options

**Statut** : validée (14/11/2026), Q1 tranchée par Maxime, Q2 à Q8 proposées par Claude
**Piliers servis** : P3 (l'inquiétante familiarité) et P4 (le rétro qui dérange) dès le premier écran ; P1 par des réglages de son qui laissent entendre les bruits
**Phase** : 13 — Interface, menus et options (voir `specs/BACKLOG.md`), commencée avant les phases 11 et 12 à la demande de Maxime (14/11/2026)
**Maquettes** : https://claude.ai/artifact/9uoNuSUbyjuRZcnAdZ9wrA (trois styles, cinq écrans chacun)

## Pourquoi
Les menus actuels marchent mais sont des versions de test : fond gris uni, boutons Godot par défaut, salon en ligne construit dans le code (T-096), que Maxime a qualifié de version de test le 13/11/2026. Le premier écran est la première image que voit un joueur : il doit déjà raconter la cité la nuit. Un joueur inconnu doit aussi pouvoir régler le son, la souris et l'image, et retrouver ses réglages à la visite suivante.

## Ce que vit le joueur
**Léa** ouvre le lien. Le titre ÉCHO apparaît sur une vue de la cité des Tilleuls dans le brouillard. Elle descend dans le menu avec les flèches ; l'entrée choisie se démarque nettement. Elle ouvre « Options », baisse la musique, passe le clavier en QWERTY et monte la sensibilité de la souris. Elle revient, clique sur « Jouer en ligne », tape le code **KMRB** que Tom lui a envoyé et arrive dans le salon : quatre places, Tom au monstre, elle sur « Chassé 1 », une place jouée par une IA. Elle se dit prête, Tom lance.

En pleine partie, elle appuie sur Échap : le menu de pause s'ouvre par-dessus le jeu, qui continue puisqu'elle joue en ligne. Elle relit les commandes, ferme la pause et reprend. Le lendemain, elle rouvre le lien : ses réglages sont toujours là.

## Récits utilisateur
- En tant que joueur, je veux un écran d'accueil dans l'ambiance du jeu, afin de savoir tout de suite à quoi je vais jouer.
- En tant que joueur, je veux tout parcourir à la souris ou au clavier seul, afin de ne jamais être bloqué.
- En tant que joueur, je veux régler le son, la souris, l'image et les touches, et les retrouver à la visite suivante.
- En tant que joueur en ligne, je veux voir le code de la partie, les quatre places et qui est prêt, sans rien avoir à deviner.
- En tant que joueur, je veux une pause qui ne me fait pas perdre la partie en ligne, et qui arrête vraiment le jeu en solo.

## Écrans
1. **Accueil** : titre, « Jouer seul », « Jouer en ligne », « Options », « Crédits ».
2. **Jouer seul** : choix du rôle (chassé ou monstre), puis l'objectif et les commandes du rôle, puis « Jouer » (comme aujourd'hui, restylé).
3. **Jouer en ligne** : « Créer une partie », « Rejoindre » avec la saisie du code de 4 lettres, « Retour ». Les erreurs du salon (code inconnu, partie complète, serveur injoignable…) s'affichent sur cet écran.
4. **Salon** : le code à envoyer, les quatre places (monstre, chassés 1 à 3) avec qui y est et qui est prêt, « Je suis prêt », « Lancer la partie » pour le chef, « Quitter ».
5. **Pause** : « Reprendre », « Options », « Revenir au menu », avec les commandes du rôle.
6. **Options** : quatre onglets, Son, Contrôles, Image, Touches (Q4).
7. **Crédits** : le contenu de `CREDITS.md` (T-167).
8. **Chargement** : une progression pendant le chargement de la map (T-166).

## Clarifications
- Q1 : Quel style pour tous les menus ? → Proposition : **A, Sodium et digicode** (signalétique de cité, sélection en ocre de lampadaire, rejoindre sur un digicode, salon en interphone), le plus lisible et le plus proche de la palette de la section 2.3. Autres choix : B, Main courante (dossier de police) ; C, Vidéosurveillance (écran du gardien, salon en quatre caméras). → R : **A, Sodium et digicode** (Maxime, 14/11/2026).
- Q2 : Que montre le fond des menus ? → Proposition : de **vraies vues de la cité**, capturées dans le jeu par un script de `tools/godot/` et enregistrées en images (une par écran). Une vraie scène 3D en mouvement derrière le menu serait plus belle mais chargerait la map avant même de jouer, ce qui coûte du temps de chargement et de la mémoire. → R : proposition de Claude.
- Q3 : Quelles polices ? → Proposition : des polices **libres (OFL ou Apache)** embarquées dans le jeu, notées dans `CREDITS.md`, avec un seul thème Godot (`game/ui/theme/`) partagé par tous les menus au lieu de réglages bouton par bouton. → R : proposition de Claude.
- Q4 : Quels réglages ? → Proposition : **Son** : volume général, effets, ambiance, musique (les bus qui n'existent pas encore avant S-012 sont créés vides). **Contrôles** : sensibilité de la souris, inversion verticale. **Image** : luminosité, champ de vision, qualité (brouillard, ombres). **Touches** : clavier AZERTY ou QWERTY (le jeu lit déjà les touches physiques, ce réglage change l'affichage des noms de touches), et touches modifiables action par action. → R : proposition de Claude.
- Q5 : Où sont enregistrés les réglages ? → Proposition : dans `user://settings.cfg` (un `ConfigFile`). Dans le navigateur, Godot le garde dans le stockage du site, donc les réglages survivent à un rechargement de la page. Un réglage illisible ou inconnu revient à sa valeur par défaut. → R : proposition de Claude.
- Q6 : Que fait la pause en ligne ? → Proposition : le menu s'ouvre par-dessus le jeu, qui **continue** ; le personnage du joueur s'arrête (aucune entrée envoyée) tant que la pause est ouverte. En solo, le jeu s'arrête comme aujourd'hui (T-080). En ligne, « Quitter la partie » remplace « Revenir au menu » : le joueur quitte la partie, une IA prend sa place (S-010, Q7) et le même code lui permet de revenir. → R : proposition de Claude.
- Q7 : Manette ? → Proposition : **hors périmètre**. Souris et clavier seulement, comme le reste du jeu. → R : proposition de Claude.
- Q8 : Le nom du jeu à l'écran ? → Proposition : **ÉCHO**, provisoire, tant que le nom définitif n'est pas choisi (S-015). → R : proposition de Claude.

## Hors périmètre
- Le HUD en partie, repris à part (T-165).
- La musique et les sons des menus (S-012) ; les réglages de volume sont prêts pour eux.
- La manette (Q7), les comptes, la liste publique de parties.
- La traduction dans d'autres langues (Q-011, S-015) ; tous les textes passent déjà par `game/i18n/strings.csv`.

## Critères d'acceptation (vérifiables à la main)
- [ ] Les écrans 1 à 6 suivent le style choisi en Q1, sur la base 640 × 360, lisibles en 1280 × 720 et en 1920 × 1080.
- [ ] Chaque écran se parcourt entièrement au clavier (flèches, Entrée, Échap) et à la souris, avec une sélection toujours visible.
- [ ] Les réglages changent le jeu tout de suite et survivent à un rechargement de la page dans le navigateur.
- [ ] Une touche modifiée marche en partie et s'affiche avec son nouveau nom dans les commandes et les invites.
- [ ] En solo la pause arrête le jeu ; en ligne la partie continue et le joueur peut reprendre ou quitter proprement.
- [ ] Le salon montre le code, les quatre places, les IA et qui est prêt, et garde tout ce que fait le salon actuel (T-096 à T-099).
- [ ] Aucune couleur orange de bruit dans les menus (section 2.3).
- [ ] Tests GUT sur l'enregistrement et la relecture des réglages, et sur la navigation au clavier.
- [ ] Le build web reste sous 60 Mo avec les polices et les images de fond.

## Notes de playtest
