# S-010 — Multijoueur en ligne

**Statut** : proposée (13/11/2026), en attente de Maxime pour Q1 à Q4
**Piliers servis** : P1 (le son trahit), P2 (le dilemme permanent), P3 (asymétrie) — à plusieurs, avec de vrais adversaires
**Phase** : 10 — Multijoueur en ligne (voir `specs/BACKLOG.md`)
**Architecture** : serveur dédié Godot en WebSocket chez Hetzner (D-015, `etude-reseau.md`)

## Pourquoi
Depuis S-008, une partie complète se joue seul contre une IA, dans les deux rôles. Le jeu est pensé pour 1 monstre contre plusieurs chassés : le bruit des uns attire le monstre vers les autres, et un chassé peut faire diversion pour un coéquipier. Cette spec fait jouer 1 monstre et jusqu'à 3 chassés ensemble, chacun dans son navigateur, sur un serveur qui fait autorité et garde le bruit secret. Les places vides sont prises par des IA, pour qu'on puisse jouer à 2.

## Ce que vit le joueur
**Maxime** ouvre le lien itch.io et clique sur « Créer une partie ». Le jeu lui donne un code de 4 lettres, par exemple **KRBX**, qu'il envoie à trois amis. Chacun ouvre le lien, clique sur « Rejoindre », tape le code et arrive dans le **salon** : quatre places, une pour le monstre et trois pour les chassés. Maxime prend le monstre, ses amis les chassés ; une place restée vide affiche « IA ». Chacun clique sur « Prêt », Maxime lance.

Les chassés apparaissent à des endroits différents de la cité. Léa entend un chien aboyer et, au loin, une bouteille se briser : c'est Tom qui fait diversion, mais elle ne le sait pas, elle ne voit ni son bruit ni sa position. Le monstre, lui, voit l'orange de la bouteille et y court. Léa en profite pour prendre un fusible au centre social. Tom se fait attraper près du parking. Sami, caché dans un placard tout près, hésite : aller le libérer fait du bruit (voir Q2). Les fusibles posés, la sirène hurle ; Léa sort par le tunnel : les chassés gagnent. Chacun voit l'écran de fin, puis revient au salon pour rejouer.

## Récits utilisateur
- En tant que joueur, je veux créer une partie et donner un code à mes amis, afin de jouer ensemble sans compte ni inscription.
- En tant que joueur, je veux choisir mon rôle dans un salon et voir qui est prêt, afin de lancer quand tout le monde l'est.
- En tant que chassé, je veux ne rien savoir des autres que ce que je vois et entends, afin que le bruit reste le cœur du jeu (P1).
- En tant que monstre, je veux entendre les bruits de tous les chassés, afin de traquer à plusieurs proies.
- En tant que chassé, je veux pouvoir aider un coéquipier (diversion, et peut-être le libérer), afin que jouer à plusieurs change la façon de jouer (P2).
- En tant que joueur, je veux qu'une place vide ou un joueur parti soit pris par une IA, afin que la partie continue.
- En tant que Maxime, je veux un test automatique d'une partie à 4 clients, afin que chaque changement ne casse pas le réseau.

## Clarifications
- Q1 (Q-002) : Combien de chassés ? → Proposition : **3 chassés** contre 1 monstre (4 joueurs), comme dans la section 6.1. La cité fait 220 × 220 m : à 4 chassés, le monstre serait débordé ; à 3, chaque bruit compte. → R : en attente de Maxime.
- Q2 (Q-003) : Un chassé attrapé est-il éliminé, ou sauvable ? → Proposition : **sauvable une fois**. Le chassé attrapé est enfermé sur place, à genoux, et appelle à l'aide (un bruit faible et régulier que le monstre entend aussi). Un coéquipier qui le rejoint et **maintient E pendant 4 s** le libère, en faisant un bruit moyen. Attrapé une deuxième fois, il est éliminé et devient spectateur. Cela crée le dilemme « je l'aide ou je fuis ? » (P2) et un piège pour le monstre, qui peut attendre près du prisonnier. Autre option : éliminé dès la première prise (plus simple, parties plus courtes). → R : en attente de Maxime.
- Q3 (Q-005) : Parties entre amis seulement, ou matchmaking public ? → Proposition : **entre amis seulement**, avec un code de partie. Pas de liste publique ni d'appariement automatique dans cette spec : moins de travail, pas de modération, et il faudrait beaucoup de joueurs en ligne pour que le matchmaking fonctionne. On pourra l'ajouter à la sortie (S-015). → R : en attente de Maxime.
- Q4 (Q-010) : Les chassés peuvent-ils se parler en jeu ? → Proposition : **pas de voix dans le jeu** pour l'instant ; les amis utilisent Discord ou un autre outil s'ils le veulent. Une voix de proximité qui fait du bruit serait très dans l'esprit du jeu (P1), mais demande le micro du navigateur, un relais audio et beaucoup de réglages : c'est une spec à part, à décider après les premières parties à 4. → R : en attente de Maxime.
- Q5 : Qui fait autorité et qui reçoit quoi ? → Proposition : le **serveur** simule toute la partie (physique, IA, fusibles, bruits, captures). Chaque client envoie ses entrées (déplacement, regard, actions) 30 fois par seconde et affiche ce que le serveur lui renvoie 20 fois par seconde, avec interpolation. Le monstre reçoit les bruits de tous (avec leur position) ; un chassé ne reçoit que ce qui est dans son champ de vision ou à portée de ses oreilles, comme un joueur l'entendrait : jamais la position d'un autre qu'il ne voit pas. → R : proposition de Claude.
- Q6 : Comment rejoindre ? → Proposition : un **code de 4 lettres** (sans lettres ambiguës), valable tant que le salon existe. Le créateur est le « chef » : il lance la partie et peut changer les rôles. Une partie lancée ne peut plus être rejointe. → R : proposition de Claude.
- Q7 : Que se passe-t-il quand un joueur part ou perd la connexion ? → Proposition : sa place est prise par une **IA** au bout de 10 s ; s'il revient avec le même code avant la fin, il reprend sa place. Si tous les humains partent, la partie s'arrête. → R : proposition de Claude.
- Q8 : Quel ping vise-t-on ? → Proposition : jeu fluide **jusqu'à 150 ms** de ping (serveur en Allemagne ou en Finlande, joueurs en Europe). Le ping s'affiche avec F3. Le chassé voit son propre personnage bouger tout de suite (prédiction locale), corrigé en douceur si le serveur n'est pas d'accord. → R : proposition de Claude.
- Q9 : Jouer seul reste-t-il possible ? → Proposition : **oui**, « Jouer seul » lance la partie dans le navigateur, sans serveur, comme aujourd'hui (monstre IA ou proie IA). Le serveur n'est utilisé que pour « Créer » et « Rejoindre ». → R : proposition de Claude.

## Hors périmètre
- Le matchmaking public, les comptes, les amis, les classements (S-015 au plus tôt).
- La voix en jeu (Q4).
- Les personnages animés : les chassés restent des silhouettes simples jusqu'à S-011.
- L'hôpital (S-014) : une seule map, la cité des Tilleuls.
- La lutte contre la triche au-delà du serveur qui fait autorité.

## Critères d'acceptation (vérifiables à la main)
- [ ] « Créer une partie » donne un code ; 3 autres navigateurs le rejoignent ; le salon montre les rôles, « Prêt » et les places IA.
- [ ] 1 monstre et 3 chassés jouent une partie complète depuis 4 navigateurs, sur des connexions différentes (T-104).
- [ ] Un chassé ne reçoit jamais la position d'un joueur qu'il ne voit pas (vérifié par un test sur les messages envoyés).
- [ ] Le monstre voit les bruits de tous les chassés ; le scan, les lumières qui vacillent et les captures sont les mêmes pour tous.
- [ ] La règle de capture choisie (Q2) fonctionne, avec la vue spectateur pour un chassé éliminé.
- [ ] Une place vide est jouée par une IA ; un joueur qui part est remplacé par une IA et peut revenir.
- [ ] Jusqu'à 150 ms de ping, les déplacements restent fluides (test avec latence simulée).
- [ ] La CI lance le serveur et 4 clients sans affichage et joue une partie scriptée de bout en bout.
- [ ] « Jouer seul » marche toujours sans serveur.
- [ ] Le budget de performance tient avec 4 joueurs (60 images/s sur la machine de référence).

## Notes de playtest
