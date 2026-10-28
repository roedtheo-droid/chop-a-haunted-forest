# Stilguide: Chop a Haunted Forest i "Chop a Forest"-stil

Lavet ud fra Theos to optagelser af Chop a Forest (traileren og 2,5 min gameplay).
Vi kopierer **looket**, ikke deres filer: alt bygges med vores egne Parts, farver og Roblox' indbyggede fonte.

## 1. Grundidé
Lyst, solrigt "legetøjs"-look. Alt er **kantet og blokket** (ingen kugler eller runde stammer),
mættede farver, bløde skygger og tydelige omrids på tekst. Det skal ligne en tegnefilm-skov.

**Haunted-twist:** Zone 1 ligner Chop a Forest 1:1 (sol, grønt, glad). Jo længere ind man kommer,
jo mere uhyggeligt: Zone 2 får tåge og gråligere grøn, Zone 3 får lilla skumring, døde træer og orange glød.
Samme kantede stil hele vejen, bare mørkere.

## 2. Farver
| Hvad | Farve (RGB) |
|---|---|
| Græs | 90, 170, 60 (lysere pletter 110, 190, 70) |
| Blade, grøn (3 nuancer) | 60, 130, 45 / 75, 150, 55 / 95, 165, 60 |
| Blade, efterår (sjældne) | rød 200, 60, 45 / orange 230, 140, 50 / pink 235, 150, 185 |
| Egestamme | 120, 75, 45 |
| Birkestamme | 235, 232, 222 med små sorte striber 40, 40, 40 |
| Træets inderside (hak, stub-top, log-ender) | 235, 200, 150 |
| Træflis | 225, 185, 130 |
| UI-træpanel | 160, 105, 60 med kant 95, 60, 30 |
| Køb-knap | grøn 90, 200, 70 |
| Luk-knap | rød 220, 50, 50 |
| Sælg-pad kant | gul 250, 210, 30 / sort 30, 30, 30 striber |
| Mønter | guld 255, 200, 40 |

## 3. Træer
- **Stamme:** firkantet blok (ikke cylinder), med 3-4 små skrå "rod"-blokke ved foden.
- **Krone:** 3-5 kuber i forskellig størrelse, lidt drejet og overlappende, i 2-3 grønne nuancer.
- **Birk:** hvid, høj og smal stamme med sorte striber, lille krone.
- **Materialer:** SmoothPlastic på blade, Wood på stammer. Ingen Neon undtagen Cursed-træer.
- **Stub:** firkantet stub med lys top (træets inderside).
- **Haunted:** Zone 3-træer har få eller ingen blade, mørk stamme, skæve grene (skrå blokke).

## 4. Lys og himmel
- Zone 1: middagssol (ClockTime ca. 13), bløde skygger, svag Bloom, let varm ColorCorrection, ingen tåge.
- Baggrund: grå bjerge med hvide toppe (store kiler/kegler bag skovens mure).
- Zone 2: Atmosphere-tåge, lidt koldere farver.
- Zone 3: lilla/orange skumring, tættere tåge, mørkere.
- Skiftet sker blødt (tween), når man går gennem en port.

## 5. Hug-effekter ("juice")
- **Hak i stammen:** et lyst hak vokser ind i stammen for hvert slag (som i traileren).
- **Træflis:** små **kuber** der springer ud og falder til jorden (ikke runde prikker).
- **Puf:** et kort hvidt/beige støvpuf og lille flash ved slaget.
- **HP-bar over træet:** navn ("Oak") og "12/30 HP" i en mørk, afrundet bar med rød fyld.
- **"TIMBER!"** i stor gul/orange tekst med sort kant, når træet vælter.
- **Logs:** firkantede klodser med lyse ender (årringe-farve).
- Lidt kamerarystelse ved hvert slag.

## 6. UI
- **Font:** Fredoka One til alt (Luckiest Guy til store overskrifter som "TIMBER!" og "FOREST CLEARED!").
- **Tekst:** hvid med tyk sort kant (UIStroke 2-3 px). Aldrig grå tekst på grå bokse.
- **Venstre side:** store mønt- og Ember-ikoner med tal ved siden af.
- **Nederst venstre:** rygsæk-ikon og "0/5" (rød når fuld).
- **Øverst venstre:** quest med navn og grøn progress-bar i mørk, afrundet ramme.
- **Øverst højre:** zonenavn, "AREA 1/3", bar med "% cleared" og en lille tekst under.
- **Menuer (Tool Shed):** brunt træpanel med mørk kant og runde hjørner, faner øverst,
  kort med farvet baggrund, niveau-prikker, grøn KØB-knap, rød X i hjørnet.
- **Knapper:** runde/afrundede, tyk kant, "popper" lidt når man trykker (tween).
- **Beskeder:** mørk afrundet stribe nederst i midten ("Sold 5 logs for 74 coins!"), tal i gul.

## 7. Bygninger
- **Sawmill-pad:** træplanker med gul/sort fareskiltkant og et stort "SELL LOGS"-skilt.
- **Tool Shed:** bjælkehytte (brune vandrette bjælker, skråt tag, skilt med "TOOL SHED").
- **Porte:** træporte med bjælker, ikke grå blokke.

## 8. Blender-modeller
- Modellerne bygges af Python-scripts i `blender/` (se README, "Blender models"), i samme kantede stil:
  kasser med skrå kanter (bevel), ingen kugler eller runde stammer.
- **Én farve pr. del:** hver farve er sin egen del, og spillet farver selv delene (tilfældige bladfarver,
  lilla Cursed-træer, mimic-tell'en "Tint"). Farverne i Blender er kun til preview-billederne.
- **Navne spillet leder efter:** `Trunk`, `Root`, `Branch`, `Leaves` (den største blad-klump),
  `LeafBlock`, `Rock`, `Moss`, `Hedge`, `Twig`, `Stone`, `Log`, `Roof`, `Sign`, `Lamp`, `Iron`,
  `Mountain`, `Snow`, `Hill`, `Grove`.
  Nummerér med `_1`, `_2`...
- **Stammen er altid en firkantet, lige blok** med bark-riller, så hakket kan skæres i den.
- **Jorden:** bløde pletter (`Patch`) i lysere/mørkere græs, mos, mudder og visne blade, og ved
  zone-grænserne fletter de to zoners farver ind i hinanden. Stien har en mørkere jordkant og småsten.
  Floden har sandbanker med sten, en mørkere bund, siv og åkander.
- **Kanterne:** væggene er usynlige. Man ser en tyk, ujævn hæk med sten for foden (grøn, så grå-grøn,
  så næsten sort med tørre kviste i zone 3), og to rækker store træer bag den. Mellem zone 1 og 2 står
  en klippe-ryg med små træer og et port-hus af bjælker; mellem zone 2 og 3 en smuldrende stenmur med
  døde træer og et port-hus af sten med jernbue og blafrende orange lygter.
- **Udsigten:** bag træerne bølgende bakker med små træer, og to ringe af kantede bjerge med sne på
  toppen; den bageste ring er lysere og mere blå, så den ser langt væk ud. Himlen har rigtige skyer
  og bløde solstråler, der skifter med zonen (hvide skyer, tunge grå skyer, lilla skumrings-skyer).
- Mangler en model i Studio, bygger spillet den gamle Parts-version i stedet.

## Hvad vi IKKE kopierer
Deres logo, ikoner, billeder, meshes, lyde og navne (fx "Old Barkback"). Vi laver vores egne med Parts, tekst og vores egne Blender-modeller.
