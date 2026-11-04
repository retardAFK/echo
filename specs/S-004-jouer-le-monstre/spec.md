# S-004 — Jouer le monstre

**Statut** : brouillon (04/11/2026), en attente des réponses de Maxime
**Piliers servis** : P1 (le son trahit), P2 (le dilemme permanent)
**Phase** : 4 — Jouer le monstre

## Pourquoi
Jouer le monstre doit être aussi amusant que jouer le chassé. Son atout, ce sont les bruits (D-008) : chaque bruit qu'il entend s'affiche avec sa distance, et le scan de bâtiment lui permet d'écouter tout un bâtiment en direct, pour un temps limité (D-009). Cette spec rend le monstre jouable dans la greybox, face à une proie contrôlée par l'ordinateur, pour tester seul la boucle « entendre, s'approcher, scanner, attraper ».

## Ce que vit le joueur
Au lancement, je choisis « Chassé » ou « Monstre ». Je prends le monstre. Je vois la greybox normalement, de plus haut que le chassé. Une proie se promène quelque part. Un rond orange s'allume au loin, avec « 11 m » à côté : elle a marché. Je m'approche en rôdant, sans bruit. Le rond s'efface. Je vise le petit bâtiment et je maintiens le clic droit : après une seconde de concentration, j'entends tout ce qui se passe dedans. Rien. La jauge de concentration baisse. Je relâche. Plus tard, un rond orange bouge vite derrière un mur : elle court. Elle m'a entendu marcher. Je cours aussi, elle entre dans le bâtiment et se tait. Je scanne : elle est essoufflée, son souffle apparaît dans la deuxième pièce. J'y vais et je l'attrape. « Attrapée » s'affiche, et la proie réapparaît ailleurs.

- Le chassé contrôlé par un humain face au monstre contrôlé par un humain (réseau) : phase 6.
- Les quêtes du chassé (tableau électrique, porte à forcer) et la perte de progression quand il les lâche : phase 7.
- La vraie map (l'hôpital) : plus tard. On reste dans la greybox.

## Clarifications
- Q1 : Comment choisir son rôle ? → Proposition : un petit écran de démarrage avec deux boutons, « Chassé » et « Monstre ». Il fonctionne dans le build web, où on ne peut pas changer de scène autrement. Échap revient à cet écran. → R : en attente.
- Q2 : Comment s'affichent les bruits ? → Proposition : chaque bruit que le monstre entend (portées de 6.2, murs compris) apparaît comme un rond orange à sa position, visible à travers les murs, avec sa distance en mètres arrondie (« 11 m »). Il s'efface en 3 s. Les bruits du monstre lui-même ne s'affichent pas. → R : en attente.
- Q3 : Comment marche le scan ? → Proposition : je vise un bâtiment à moins de 30 m et je maintiens le clic droit. Je ne peux plus bouger, mais je peux encore tourner la tête. Après 1 s, tous les bruits du bâtiment s'affichent, même trop faibles pour m'arriver. La jauge (8 s de scan, recharge complète en 45 s, impossible sous 25 %) est une barre pâle en bas de l'écran, pas orange, car l'orange est réservé au bruit. → R : en attente.
- Q4 : Comment se comporte la proie ? → Proposition : elle se promène en marchant entre des points, dedans et dehors (bruits de 4 m). Si elle entend le monstre (3 m en marchant, 12 m en courant, D-009) ou le voit à moins de 15 m, elle court vers la cachette la plus éloignée de lui (bruits de 14 m), puis s'accroupit et se tait 20 s. Après une course, elle est essoufflée 10 s : son souffle n'est audible que par le scan. → R : en attente.
- Q5 : Que fait la proie quand les lumières vacillent (alerte du scan) ? → Proposition : si elle est dans le bâtiment scanné et qu'elle marche, elle se fige et se tait jusqu'à la fin du scan. Elle ne remarque l'alerte qu'une fois sur deux, comme un humain qui regarde ailleurs. → R : en attente.
- Q6 : Comment le monstre attrape-t-il la proie ? → Proposition : au contact, à moins de 1,2 m, comme le monstre IA. « Attrapée » s'affiche 2 s, la proie réapparaît au point le plus éloigné du monstre, et un compteur de captures s'affiche avec F3. Les commandes sont celles du chassé : marcher par défaut (3,5 m/s), Maj pour courir (6 m/s), Ctrl pour rôder sans bruit (1,5 m/s). → R : en attente.

## Notes de playtest
- (à remplir)

## Critères d'acceptation (vérifiables à la main)
- [ ] Depuis l'écran de démarrage, je peux lancer le chassé ou le monstre, dans l'éditeur comme dans le build web.
- [ ] En monstre, chaque bruit de la proie que j'entends s'affiche en orange à sa position avec sa distance, et s'efface en 3 s. Un bruit trop loin ou étouffé par les murs ne s'affiche pas.
- [ ] Je peux scanner le bâtiment : immobile, j'y vois tous les bruits en direct, la jauge se vide en 8 s, se recharge en 45 s et refuse de démarrer sous 25 %.
- [ ] Pendant un scan, les lumières du bâtiment scanné vacillent, sans aucun message à l'écran.
- [ ] Le scan révèle le souffle d'une proie cachée qui vient de courir, mais pas celui d'une proie reposée.
- [ ] En rôdant, je peux m'approcher de la proie sans qu'elle m'entende. En courant, elle m'entend de loin et s'enfuit.
- [ ] Je peux traquer et attraper la proie grâce aux bruits et au scan.
- [ ] 60 images par seconde dans Chrome en jouant le monstre.
