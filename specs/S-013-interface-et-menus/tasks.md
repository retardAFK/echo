# Tâches — S-013

Chaque tâche est vérifiée par Claude (tests GUT, lint, import, export web, captures des écrans dans le build web). Maxime ne fait pas de test à la main.

- [x] T-160 — Spec S-013
  - Résultat vérifiable : spec validée, style choisi
  - Dépend de : —
  - Fait le 14/11/2026 : trois styles maquettés, Maxime choisit A « Sodium et digicode »
- [x] T-161 — Plan et tâches de S-013
  - Résultat vérifiable : `plan.md` et `tasks.md`
  - Dépend de : T-160
  - Fait le 14/11/2026 : ce fichier et [`plan.md`](plan.md)
- [x] T-162 — Thème, polices, fonds et accueil
  - Résultat vérifiable : `echo_theme.tres` généré, polices dans `assets/fonts/` et `CREDITS.md`, images de fond capturées ; `MenuBackdrop`, `MenuList` ; accueil et choix du rôle au style A, au clavier et à la souris ; tests GUT
  - Dépend de : T-161
  - Fait le 14/11/2026 : `MenuStyle` (couleurs, polices, tailles) et `tools/godot/build_menu_theme.gd` qui génère `game/ui/theme/echo_theme.tres` ; Barlow, Barlow Condensed et VT323 (OFL) ; quatre fonds capturés et étalonnés par `tools/godot/capture_menu_backgrounds.tscn` (environ 85 Ko chacun) ; `MenuItem`, `MenuList`, `MenuBackdrop` ; accueil (Jouer seul, Jouer en ligne) et choix du rôle avec l'objectif et les commandes du rôle sous le curseur ; un test vérifie que le thème n'utilise jamais l'orange du bruit ; 13 tests GUT
- [x] T-169 — Jouer en ligne : digicode et interphone
  - Résultat vérifiable : `LobbyMenu` en scène, `Digicode` et `Intercom` ; tous les tests du salon passent ; test à 4 clients de la CI inchangé
  - Dépend de : T-162
  - Fait le 14/11/2026 : `lobby_menu.tscn` remplace la construction dans le code ; `Digicode` (22 lettres de `RoomCode`, clavier physique, envoi à la 4e lettre ou sur OK) et `Intercom` (étiquette par place, voyant allumé quand le joueur est prêt, ligne cliquable pour prendre ou échanger une place) ; code en grand dans le salon, liste Je suis prêt / Lancer la partie / Quitter ; Échap revient en arrière ; 7 tests GUT, ceux du salon inchangés
- [x] T-164 — Pause et menus en partie
  - Résultat vérifiable : pause au style A ; en solo la partie s'arrête, en ligne elle continue avec des commandes neutres ; quitter proprement
  - Dépend de : T-162
  - Fait le 14/11/2026 : bandeau sur toute la largeur, Reprendre / Revenir au menu et les commandes du rôle toujours affichées ; en ligne la partie continue (`LocalControls.frozen` : personnage immobile, aucune action) et « Quitter la partie » ferme la connexion ; « Options » s'ajoute avec T-163 ; 10 tests GUT
- [ ] T-163 — Options
  - Résultat vérifiable : `UserSettings` (autoload `Settings`), écran Options à quatre onglets depuis l'accueil et la pause ; volumes par bus, sensibilité, inversion, champ de vision, luminosité, qualité (brouillard, ombres), clavier AZERTY ou QWERTY et touches modifiables ; enregistrés dans `user://` ; tests GUT
  - Dépend de : T-162
- [ ] T-165 — HUD final
  - Résultat vérifiable : HUD des deux rôles repris sur la base 640 × 360 (D-011), lisible à toutes les tailles d'écran
  - Dépend de : T-161
- [ ] T-166 — Écran de chargement et premiers pas
  - Résultat vérifiable : chargement sous 10 s affiché avec une progression ; conseils de premier lancement pour chaque rôle
  - Dépend de : T-162
- [ ] T-167 — Crédits en jeu
  - Résultat vérifiable : contenu de `CREDITS.md` affiché dans le jeu
  - Dépend de : T-162
- [ ] T-168 — Vérification finale de S-013
  - Résultat vérifiable : critères cochés, spec livrée
  - Dépend de : T-163, T-164, T-165, T-166, T-167, T-169
