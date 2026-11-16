# Generates specs/S-014-hopital/plan-hopital.svg (T-181). 1 unit = 1 m.
import sys
out = sys.argv[1]
S = 4.0  # px per m in floor plans
X0, Y0, W, H = 10, 56, 22, 76  # hospital footprint on the cité plan
def rx(x): return (x - X0) * S
def ry(y): return (y - Y0) * S
rooms = {
 "Sous-sol (−3,5 m)": [
  (10,56,9.5,18,"Morgue","#3b4a44","tiroirs = cachettes métal"),
  (10,74,9.5,12,"Autopsie","#3b4a44",""),
  (10,86,9.5,10,"Quai","#4a4436","rampe vers l'allée"),
  (10,96,9.5,29,"Chaufferie","#2f3e52","VENTILATION"),
  (10,125,9.5,7,"Esc. S","#555","") ,
  (22.5,56,9.5,7,"Esc. N","#555",""),
  (22.5,63,9.5,24,"Isolement","#4b3b45","4 cellules capitonnées"),
  (22.5,87,9.5,13,"Lingerie","#3f4450",""),
  (22.5,100,9.5,24,"Archives","#3f4450","rayonnages en labyrinthe"),
  (22.5,124,9.5,8,"Technique","#3f4450","relais"),
 ],
 "Rez-de-chaussée": [
  (10,56,9.5,12,"Radio 1","#3f4450",""),
  (10,68,9.5,12,"Radio 2","#3f4450","porte plombée"),
  (10,80,9.5,12,"Pharmacie","#3f4450","porte arrière"),
  (10,92,9.5,12,"Attente","#44403a","chaises"),
  (10,104,9.5,21,"Box urgences","#4b3b45","rideaux = fortune"),
  (10,125,9.5,7,"Esc. S","#555",""),
  (22.5,56,9.5,7,"Esc. N","#555",""),
  (22.5,63,9.5,12,"Entrées","#3f4450",""),
  (22.5,75,9.5,13,"Accueil","#44403a","appel sonore"),
  (22.5,88,9.5,12,"Hall","#4a4436","entrée principale"),
  (22.5,100,9.5,12,"Sas urgences","#4a4436","sous l'auvent"),
  (22.5,112,9.5,12,"Soins","#3f4450",""),
  (22.5,124,9.5,8,"Local","#3f4450",""),
 ],
 "1er étage": [
  (10,56,9.5,12,"Ch. 101","#3f4450",""),(10,68,9.5,12,"Ch. 103","#3f4450",""),
  (10,80,9.5,12,"Ch. 105","#3f4450",""),(10,92,9.5,12,"Sanitaires","#3f4450","rideau de douche"),
  (10,104,9.5,10.5,"Ch. 107","#3f4450",""),(10,114.5,9.5,10.5,"Ch. 109","#3f4450",""),
  (10,125,9.5,7,"Esc. S","#555",""),
  (22.5,56,9.5,7,"Esc. N","#555",""),
  (22.5,63,9.5,12.5,"Ch. 102","#3f4450",""),(22.5,75.5,9.5,12.5,"Ch. 104","#3f4450",""),
  (22.5,88,9.5,8,"Poste soins","#2f4f3f","terminal"),
  (22.5,96,9.5,14,"Ch. 106","#3f4450",""),(22.5,110,9.5,14,"Ch. 108","#3f4450",""),
  (22.5,124,9.5,8,"Linge","#3f4450",""),
 ],
 "2e étage": [
  (10,56,9.5,14,"Stérilisation","#3f4450",""),
  (10,70,9.5,15,"Bloc 1","#2f4f3f","portes battantes"),
  (10,85,9.5,15,"Bloc 2","#2f4f3f",""),
  (10,100,9.5,25,"Réanimation","#4b3b45","moniteurs"),
  (10,125,9.5,7,"Esc. S","#555",""),
  (22.5,56,9.5,7,"Esc. N","#555",""),
  (22.5,63,9.5,12,"Sas du bloc","#3f4450",""),
  (22.5,75,9.5,13,"Repos","#3f4450",""),
  (22.5,88,9.5,8,"Lift (bloqué)","#555","cachette métal"),
  (22.5,96,9.5,28,"Réa (box vitrés)","#4b3b45",""),
  (22.5,124,9.5,8,"Réserve","#3f4450",""),
 ],
}
# doors in the corridor's fire doors per level (y), exits (x,y,label)
fire = {"Sous-sol (−3,5 m)":[87,100], "Rez-de-chaussée":[], "1er étage":[80,108], "2e étage":[75,100]}
exits = {
 "Sous-sol (−3,5 m)":[(10,91,"rampe")],
 "Rez-de-chaussée":[(32,94,"entrée"),(32,106,"urgences"),(21,56,"nord"),(21,132,"sud"),(10,86,"arrière")],
 "1er étage":[],
 "2e étage":[(21,132,"escalier de secours (métal)")],
}
fuses = {"Sous-sol (−3,5 m)":[(14,62),(27,112)], "Rez-de-chaussée":[(14,86),(27,118)], "1er étage":[(27,90)], "2e étage":[(14,77)]}
hides = {"Sous-sol (−3,5 m)":[(12,58),(12,64),(25,67),(27,104)],
 "Rez-de-chaussée":[(13,108),(13,116),(26,66)],
 "1er étage":[(14,60),(14,108),(28,80),(13,96),(28,114)],
 "2e étage":[(27,92),(14,104),(28,100)]}
PW = W*S + 70
pw_total = 4*PW + 330
ph = H*S + 230
o = []
o.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {pw_total} {ph}" width="{pw_total*1.5:.0f}" height="{ph*1.5:.0f}" font-family="Helvetica, Arial, sans-serif">')
o.append(f'<!-- Plan sur papier de l\'hôpital Saint-Roch (S-014, T-181). Généré par tools/plans/make_hospital_plan.py. 1 m = {S} px. Nord en haut. -->')
o.append(f'<rect width="{pw_total}" height="{ph}" fill="#1b1d22"/>')
o.append(f'<text x="14" y="26" font-size="17" fill="#e8eaee" font-weight="bold">Hôpital Saint-Roch — plan sur papier (S-014, proposition)</text>')
o.append(f'<text x="14" y="44" font-size="10" fill="#aab0ba">22 × 76 m, 4 niveaux visitables (sous-sol, RDC, 1er, 2e) ; 3e à 5e condamnés (façade). Le couloir central fait 74 m : la vue porte loin, le brouillard intérieur cache le bout.</text>')
# site inset: the cité, 1.2 px/m
sx, sy, k = 14, 64, 1.2
o.append(f'<g transform="translate({sx},{sy})">')
o.append(f'<rect width="{220*k}" height="{220*k}" fill="#2b2e35" stroke="#8a8f99" stroke-width="0.6"/>')
for p in ["M155 12 V50 H105 V185 H40","M105 120 H200 V200","M40 50 H105","M40 50 V185"]:
    o.append(f'<path d="{p}" transform="scale({k})" stroke="#454a54" stroke-width="5" fill="none"/>')
bars = [(15,22,70,12),(125,22,70,12),(185,55,12,55),(45,192,55,12),(125,160,12,40),(150,145,45,10)]
for b in bars:
    o.append(f'<rect x="{b[0]*k}" y="{b[1]*k}" width="{b[2]*k}" height="{b[3]*k}" fill="#5d626d"/>')
o.append(f'<rect x="{15*k}" y="{60*k}" width="{12*k}" height="{70*k}" fill="none" stroke="#c94040" stroke-width="0.8" stroke-dasharray="2 1.5"/>')
for b in [(92,88,24,24),(140,60,38,24),(45,135,42,14),(140,95,40,22)]:
    o.append(f'<rect x="{b[0]*k}" y="{b[1]*k}" width="{b[2]*k}" height="{b[3]*k}" fill="#7a5a2a" stroke="#f0c070" stroke-width="0.6"/>')
o.append(f'<rect x="{X0*k}" y="{Y0*k}" width="{W*k}" height="{H*k}" fill="#2f6b4a" stroke="#7fd6a5" stroke-width="1"/>')
o.append(f'<rect x="{32*k}" y="{88*k}" width="{6*k}" height="{24*k}" fill="none" stroke="#7fd6a5" stroke-width="0.6"/>')
o.append(f'<text x="{21*k}" y="{97*k}" font-size="7" fill="#d9ffe9" text-anchor="middle" transform="rotate(-90 {21*k} {97*k})">Hôpital</text>')
o.append(f'<text x="{110*k}" y="{232*k}" font-size="8" fill="#c8ccd4" text-anchor="middle">La cité : l\'hôpital (vert) remplace la barre C (pointillés rouges)</text>')
o.append(f'<text x="{110*k}" y="{243*k}" font-size="8" fill="#c8ccd4" text-anchor="middle">Allée de service de 4 m derrière, parvis et auvent des urgences devant</text>')
o.append('</g>')
# legend
lx, ly = 14, 64 + 320
leg = [("#e2c84a","circle","Emplacement de fusible (6)"),("#9fd0ff","rect","Cachette"),("#7fd6a5","line","Issue"),("#d26b6b","fire","Porte coupe-feu"),("#2f3e52","box","Zone de ventilation")]
for i,(c,kind,t) in enumerate(leg):
    yy = ly + i*18
    if kind=="circle": o.append(f'<circle cx="{lx+6}" cy="{yy}" r="4" fill="{c}"/>')
    elif kind=="rect": o.append(f'<rect x="{lx+2}" y="{yy-4}" width="8" height="8" fill="{c}"/>')
    elif kind=="line": o.append(f'<path d="M{lx} {yy} h12" stroke="{c}" stroke-width="3"/>')
    elif kind=="fire": o.append(f'<path d="M{lx} {yy} h12" stroke="{c}" stroke-width="3" stroke-dasharray="3 2"/>')
    else: o.append(f'<rect x="{lx}" y="{yy-5}" width="12" height="10" fill="{c}" stroke="#6fa8ff" stroke-width="0.8"/>')
    o.append(f'<text x="{lx+20}" y="{yy+4}" font-size="10" fill="#d0d4da">{t}</text>')
for i,lv in enumerate(rooms):
    ox = 330 + i*PW
    oy = 70
    o.append(f'<g transform="translate({ox},{oy})">')
    o.append(f'<text x="{W*S/2}" y="-8" font-size="13" fill="#ffe6b0" text-anchor="middle" font-weight="bold">{lv}</text>')
    o.append(f'<rect x="0" y="0" width="{W*S}" height="{H*S}" fill="#24272d" stroke="#c8ccd4" stroke-width="1.2"/>')
    o.append(f'<rect x="{rx(19.5)}" y="{ry(57)}" width="{3*S}" height="{74*S}" fill="#33373f"/>')
    for (x,y,w,h,name,col,note) in rooms[lv]:
        o.append(f'<rect x="{rx(x)}" y="{ry(y)}" width="{w*S}" height="{h*S}" fill="{col}" stroke="#9aa0aa" stroke-width="0.6"/>')
        cx, cy = rx(x)+w*S/2, ry(y)+h*S/2
        o.append(f'<text x="{cx}" y="{cy}" font-size="7" fill="#eef0f3" text-anchor="middle">{name}</text>')
        if note: o.append(f'<text x="{cx}" y="{cy+8}" font-size="5.2" fill="#b9c0ca" text-anchor="middle">{note}</text>')
        if col=="#2f3e52": o.append(f'<rect x="{rx(x)}" y="{ry(y)}" width="{w*S}" height="{h*S}" fill="none" stroke="#6fa8ff" stroke-width="1.4"/>')
    for y in fire[lv]:
        o.append(f'<path d="M{rx(19.5)} {ry(y)} H{rx(22.5)}" stroke="#d26b6b" stroke-width="2.4" stroke-dasharray="3 2"/>')
    for (x,y,t) in exits[lv]:
        if x in (10,32):
            o.append(f'<path d="M{rx(x)} {ry(y)-5} V{ry(y)+5}" stroke="#7fd6a5" stroke-width="4"/>')
            ax = rx(x) + (-6 if x==10 else 6)
            o.append(f'<text x="{ax}" y="{ry(y)+2}" font-size="6" fill="#7fd6a5" text-anchor="{"end" if x==10 else "start"}">{t}</text>')
        else:
            o.append(f'<path d="M{rx(x)-6} {ry(y)} H{rx(x)+6}" stroke="#7fd6a5" stroke-width="4"/>')
            o.append(f'<text x="{rx(x)}" y="{ry(y)+(-5 if y==56 else 24)}" font-size="6" fill="#7fd6a5" text-anchor="middle">{t}</text>')
    for (x,y) in fuses[lv]:
        o.append(f'<circle cx="{rx(x)}" cy="{ry(y)}" r="3.2" fill="#e2c84a"/>')
    for (x,y) in hides[lv]:
        o.append(f'<rect x="{rx(x)-3}" y="{ry(y)-3}" width="6" height="6" fill="#9fd0ff"/>')
    if lv=="Rez-de-chaussée":
        o.append(f'<rect x="{W*S}" y="{ry(88)}" width="{6*S}" height="{24*S}" fill="none" stroke="#7fd6a5" stroke-width="0.8" stroke-dasharray="3 2"/>')
        o.append(f'<text x="{W*S+3*S}" y="{ry(100)}" font-size="6" fill="#7fd6a5" text-anchor="middle" transform="rotate(90 {W*S+3*S} {ry(100)})">auvent + ambulance (alarme)</text>')
        o.append(f'<path d="M-{4*S} 0 V{H*S}" stroke="#555a63" stroke-width="{4*S}" opacity="0.5"/>')
        o.append(f'<text x="-{2*S}" y="{ry(110)}" font-size="6" fill="#c8ccd4" text-anchor="middle" transform="rotate(-90 -{2*S} {ry(110)})">allée de service</text>')
    if lv=="Sous-sol (−3,5 m)":
        o.append(f'<path d="M-{2*S} {ry(96)} V{ry(80)}" stroke="#7fd6a5" stroke-width="3" marker-end="url(#a)"/>')
    o.append(f'<text x="{W*S/2}" y="{H*S+14}" font-size="6.5" fill="#aab0ba" text-anchor="middle">Couloir central 3 m × 74 m</text>')
    o.append('</g>')
o.append('<defs><marker id="a" markerWidth="6" markerHeight="6" refX="3" refY="3" orient="auto"><path d="M0 0 L6 3 L0 6z" fill="#7fd6a5"/></marker></defs>')
o.append('</svg>')
open(out,"w").write("\n".join(o))
