# Tâches — S-016

Chaque tâche est vérifiée par Claude (tests GUT, lint, import et export web, simulations, captures). Seuls les rendus du mobilier et les sons sont montrés à Maxime.

- [x] T-230 — Spec S-016
  - Résultat vérifiable : spec validée par Maxime
  - Dépend de : —
- [x] T-231 — Plan et tâches de S-016
  - Résultat vérifiable : `plan.md` et `tasks.md`
  - Dépend de : T-230
- [x] T-232 — Portes mobiles
  - Résultat vérifiable : entité `Door`, `DoorSettings`, bruit `DOOR` (6 m debout, 2 m accroupi en 1 s), porte fermée qui coupe la vue et atténue le bruit, monstre qui ouvre et défonce en courant (12 m), quelques portes dans la greybox ; tests GUT. Reprend T-185 (S-014)
  - Dépend de : T-231
- [x] T-233 — Portes, IA et réseau
  - Résultat vérifiable : `DoorPath` ; le monstre IA ouvre et défonce, la proie IA ouvre et referme en fuite ; état des portes dans `NetWorld` ; tests GUT et `net_walk` étendu
  - Dépend de : T-232
- [ ] T-234 — Coupe-feu, issues de secours, métal et échelles
  - Résultat vérifiable : portes `FIRE` et `EMERGENCY`, surface métal (marche 6 m, course 18 m), entité `Ladder` avec lien de navigation ; tests GUT
  - Dépend de : T-232
- [ ] T-235 — Nouvelles familles de cachettes
  - Résultat vérifiable : `HidingSpot.family` (basse, de fortune, en métal), règle « vue à 2 m », proie et monstre IA ; tests GUT
  - Dépend de : T-231
- [ ] T-236 — La tour
  - Résultat vérifiable : 4 appartements par étage avec portes, trou dans la cloison, escalier de secours extérieur, coupe-feu, escalier des caves, cabine d'ascenseur ; IA qui montent et ressortent par chaque issue ; tests GUT
  - Dépend de : T-233, T-234, T-235
- [ ] T-237 — Le centre social
  - Résultat vérifiable : cuisine et passe-plat, bureaux communicants, issue de secours, scène et coulisses ; plus de cul-de-sac ; tests GUT
  - Dépend de : T-236
- [ ] T-238 — La galerie
  - Résultat vérifiable : 5 boutiques ouvertes, réserves, couloir ouvert aux deux bouts, rideau à lever (12 m), clochette, toit par échelles ; tests GUT
  - Dépend de : T-236
- [ ] T-239 — Le parking et le couloir des caves
  - Résultat vérifiable : escalier nord, couloir des caves vers la tour avec caves grillagées, scan étendu ; IA qui empruntent le couloir ; tests GUT
  - Dépend de : T-236
- [ ] T-240 — Mobilier et portes en 3D
  - Résultat vérifiable : `tools/blender/interiors.py`, rendus montrés à Maxime puis intégrés
  - Dépend de : T-231
- [ ] T-241 — Habillage, éclairage et performance
  - Résultat vérifiable : intérieurs meublés, éclairage précalculé, 300 appels de dessin au pire endroit
  - Dépend de : T-237, T-238, T-239, T-240
- [ ] T-242 — Sons des intérieurs
  - Résultat vérifiable : `tools/audio/interior_sounds.py`, sons montrés à Maxime puis intégrés
  - Dépend de : T-232
- [ ] T-243 — Fusibles, ruses et équilibre
  - Résultat vérifiable : 6 emplacements de fusible par bâtiment, cachettes et ruses replacées (environ 40 cachettes), 20 parties simulées sans blocage, durée non réduite
  - Dépend de : T-241
- [ ] T-244 — Vérification finale de S-016
  - Résultat vérifiable : critères cochés, performance et export web vérifiés, spec livrée
  - Dépend de : T-242, T-243

## Compte rendu
- T-230 (15/11/2026) : spec validée par Maxime (« Tout valider »), PR #117.
- T-231 (15/11/2026) : plan et tâches, PR #117. Les portes reprennent T-185 (S-014).
- T-232 (15/11/2026) : `Door` (`game/entities/door/`), `DoorSettings`, bruit `DOOR`. Le battant fermé est sur la couche des murs : il coupe la vue et compte comme un mur pour le bruit, sans code de plus ; ouvert, il n'a plus de collision (plan B du plan, retenu d'emblée pour que rien n'accroche). Debout 6 m d'un coup, accroupi ou en rôdant 1 s pour 2 m, le monstre qui court la défonce (12 m). La porte s'ouvre du côté opposé à celui qui l'ouvre. Pas de marque de surbrillance sur les portes. Les IA ouvrent déjà les portes sur leur chemin (`Door.closed_ahead`), testées en T-233. Pas de porte dans la greybox : les tests en posent une. 10 tests GUT.
- T-233 (15/11/2026) : le monstre IA ouvre les portes sur son chemin (il les défonce en poursuite), la proie IA les ouvre et, en fuite, referme derrière elle la porte qu'elle vient de passer si le monstre ne la voit pas (`close_behind_distance` 2 m). `NetWorld` liste les portes et envoie leur état (`state()[5]`) ; le client les fait bouger avec leur son, sans bruit dans `NoiseBus`. Le maillage passe par les baies, porte ouverte ou fermée. 5 tests GUT dans la greybox.
