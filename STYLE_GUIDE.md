# Stilguide: Trees With Teeth

Spillets eget udseende: **en uhyggelig billedbog**. Farver, modeller, skrift og idéer er vores egne.

## 1. Grundidé
En billedbog, der går galt. Det begynder som en bleg, stille morgen og bliver mørkere for hver zone.
Modellerne er kantede og chunky med skrå kanter, men farverne er dæmpede, og tågen gør det fjerne blødt.

Spillet skal kunne kendes på ét billede: **tænder**. Titelskærmen ses indefra en mund, og træerne bider.

Uhyggen er tegneserie-uhygge: gys og grin, ingen blod og ikke noget ubehageligt. Yngre spillere skal kunne være med.

## 2. Farver
| Hvad | Farve (RGB) |
|---|---|
| Græs, Pale Pines | 112, 134, 84 (pletter 128, 148, 94 / 100, 120, 78 / 146, 152, 100) |
| Blade, Pale Pines | 112, 138, 92 / 128, 150, 100 / 146, 164, 112 |
| Blade, sjældne | rust 150, 84, 52 / gammelt guld 190, 152, 82 / bleg 176, 180, 156 |
| Grantræer | 58, 92, 68 / 70, 104, 76 / 84, 116, 84 |
| Stammer | 104, 82, 66 / 116, 92, 72 / 94, 76, 62 |
| Birk | 226, 222, 208 med mørke mærker 45, 42, 40 |
| Træets inderside (hak, stub-top, log-ender) | 235, 200, 150 |
| Vand | 110, 146, 160 |
| Knogle (tænder, titel) | 240, 232, 205 |
| Bid (ordet TEETH) | 255, 107, 92 |
| Mørk lilla (tandkød, paneler, omrids) | 26, 20, 42 |
| Cursed-træer, glød | 120, 70, 240 |

Ingen skrigende grøn og ingen varm pink.

## 3. Zonerne
Samme kantede stil hele vejen, bare mørkere. Skiftet sker blødt, når man går gennem en port.
- **Pale Pines:** bleg, tåget morgen. Lav sol, lange skygger, dæmpede farver, og de fjerne træer forsvinder i disen.
- **Fog Hollow:** tyk grå tåge, tunge skyer, selvlysende svampe og dryp.
- **Graveyard Grove:** lilla skumring, næsten sorte stammer, orange lygter og den mørkeste stemning.

## 4. Skrift
- **Creepster** til store ord: titlen, skilte og "FOREST CLEARED!".
- **Fredoka One** til alt andet.
- Tekst har altid et mørkt omrids, så den kan læses på alt. Aldrig grå tekst på grå bokse.

## 5. Titelskærmen
Man kigger ud fra en mund: en række tænder foroven og forneden, med mørkt tandkød og en mørkerød læbe.
Titlen er knoglehvid, og ordet TEETH er rødt. Når man trykker PLAY, bider tænderne sammen med et chomp,
og de åbner sig igen på spillet.

## 6. Hug-effekter
- **Hak i stammen:** hvert slag bider en ru bid ud af stammen, der hvor man sigter.
- **Træflis:** små kuber og splinter, der flyver ud og falder til jorden.
- **Glød og savsmuld:** et varmt lysglimt fra hakket og fint savsmuld, der daler.
- **Logs:** firkantede klodser med lyse ender. De flyver til dig, når du går hen over dem.
- Lidt kamerarystelse ved hvert slag.
- HP-bar under sigtekornet og "TIMBER!" findes, men er slået fra (se Config).

## 7. UI
HUD'en bygger på Theos eget lilla design ("Haunted forest game design"):
- **Øverst til venstre:** liv og mod.
- **Øverst til højre:** logs, Embers og mønter, og quests under dem.
- **Øverst i midten:** zone, fremskridt, tid, dag og nat, og beskeder.
- **Til højre:** små knapper til SHOP og UPGRADES.
- **Nederst i midten:** nummererede lilla værktøjspladser med 3D-billeder af værktøjerne.
- **Telefoner:** CHOP og SELL nederst til højre. Intet under tommelfingerens joystick.
- **Farver:** mørk lilla paneler 26, 20, 42 med kant 59, 47, 89. Menuer er i samme lilla.
- **Knapper:** runde hjørner og tyk kant, og de "popper" lidt, når man trykker.

## 8. Lejren og bygningerne
Lejren er det første, man ser, så den skal have sine egne idéer:
- **Savværket:** Gnawbert, en lænket stub-mimic, æder dine logs og bøvser mønter op.
- **Værktøjsskuret:** værktøjerne drejer langsomt på stubbe under lanterner, med efterlysninger af mimics på væggene og et spøgelse bag disken.
- **Ved savværket:** en gammel handelsvogn åbner SHOP-menuen.
- **Mr. Graves** står ved sin bankboks.

## 9. Blender-modeller
- Modellerne bygges af Python-scripts i `blender/` (se README, "Blender models"), i samme kantede stil:
  kasser med skrå kanter (bevel), ingen kugler eller runde stammer.
- **Én farve pr. del:** hver farve er sin egen del, og spillet farver selv delene (tilfældige bladfarver,
  Cursed-træer, mimic-tell'en "Tint"). Farverne i Blender er kun til preview-billederne.
- **Navne spillet leder efter:** `Trunk`, `Root`, `Branch`, `Leaves` (den største blad-klump),
  `LeafBlock`, `Rock`, `Moss`, `Hedge`, `Twig`, `Stone`, `Log`, `Roof`, `Sign`, `Lamp`, `Iron`,
  `Mountain`, `Snow`, `Hill`, `Grove`.
  Nummerér med `_1`, `_2`...
- **Stammen er altid en firkantet, lige blok** med bark-riller, så hakket kan skæres i den.
- **Træerne:** to former af hver slags (eg, gran, birk) i Pale Pines, piletræer med lange hængende
  grene i Fog Hollow og døde, forgrenede ege med få mørke blade i Graveyard Grove. Hvert træ er op
  til 15% større eller mindre. Træerne står tættere i lunde og tyndere imellem, med et par åbne
  lysninger, og ting langs stien står i små grupper med tomme stykker imellem.
- **Små ting på jorden:** græstotter og blomster i Pale Pines, bregner og selvlysende svampe i Fog
  Hollow, visne blade og et par knogler i Graveyard Grove. Man går igennem dem. Props (buske,
  stammer, lygtepæle, hegn, græskar, gravsten, siv, åkander) er Blender-modeller i samme størrelse
  som Parts-versionerne.
- **Landemærker og lejren:** telte, bådebro, robåd, vindmølle (vingerne drejer), gravpladsens
  jernhegn, krypten, ringstenene om bossen, broen, brønden, opslagstavlen, bålet, bænkene og
  vejviseren er Blender-modeller. Hvor man går på dem (broen, bådebroen) ligger de præcise
  Parts-gulve usynligt under modellen.
- **Stammer, stubbe og bossen:** stammerne på jorden, stubbene og Elder Hollows stamme, krone og
  rødder er Blender-modeller med bark-riller. De har præcis samme størrelse som de gamle blokke, så
  ringene på enderne og alt spillet gør med dem (samle op, rødder der bliver tyndere) virker som før.
- **Værktøjsskuret og savværkerne:** Blender-modeller med bjælkevægge, tagspån, skorsten, vinduer med
  blomsterkasser og møbler. De gamle Parts ligger usynligt under og klarer kollisioner, lys og røg.
  De slidte savværker i zone 2 og 3 er de samme modeller i mørkere farver.
- **Jorden:** bløde pletter (`Patch`) i lysere/mørkere græs, mos, mudder og visne blade, og ved
  zone-grænserne fletter de to zoners farver ind i hinanden. Stien har en mørkere jordkant og småsten.
  Floden har sandbanker med sten, en mørkere bund, siv og åkander.
- **Kanterne:** væggene er usynlige. Man ser en tyk, ujævn hæk med sten for foden (grågrøn, så mere
  grå, så næsten sort med tørre kviste i zone 3), og to rækker store træer bag den. Mellem zone 1 og 2
  står en klippe-ryg med små træer og et port-hus af bjælker; mellem zone 2 og 3 en smuldrende stenmur
  med døde træer og et port-hus af sten med jernbue og blafrende orange lygter.
- **Udsigten:** bag træerne bølgende bakker med små træer, og to ringe af kantede bjerge med sne på
  toppen; den bageste ring er lysere og mere blå, så den ser langt væk ud. Himlen har rigtige skyer
  og bløde solstråler, der skifter med zonen.
- Mangler en model i Studio, bygger spillet den gamle Parts-version i stedet.

## 10. Hvad vi ikke gør
Vi efterligner ikke andre spil: ikke deres look, layouts, navne, ikoner, lyde eller figurer. At hugge
træer, sælge logs og opgradere værktøj er en genre, så det må vi gerne. Måden det ser ud på skal være vores egen.
