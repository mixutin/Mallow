---
# SPDX-License-Identifier: 0BSD
title: Tietoturva
description: Mallow'n asennuksen nykyiset suojaukset, eheyden tarkistuksen rajat ja vielä toteuttamaton Windows-hiekkalaatikko.
---

# Tietoturva

**Nykyinen kehitysversio ei käynnistä Windows-ohjelmia eikä toteuta niiden ytimen hiekkalaatikkoa.** Wine itsessään ei ole hiekkalaatikko. Mallow'n tavoitteena oleva suojaus ei ole valmis ominaisuus ennen sen toteutusta ja testausta.

## Mitä asennus tarkistaa?

Latauksen lähde, sallittu HTTPS-uudelleenohjaus, tiedoston koko ja ennalta määritetty SHA-256-tiiviste tarkistetaan. Asennin käyttää yksityistä pakettikopiota ja purkaa vain tuettuja tiedostoja, hakemistoja sekä asennuspuun sisälle rajattuja linkkejä. Arkiston omia omistajia, ACL-oikeuksia ja laajennettuja attribuutteja ei palauteta.

Purku hylkää muun muassa hakemistosta ulos johtavat polut, erikoistiedostot, päällekkäiset nimet ja liian suuren laajennetun sisällön. Linkit luodaan vasta tavallisten tiedostojen jälkeen. Asennushakemisto tuodaan lopulliseen sijaintiin vasta tarkistusten valmistuttua.

Asennus ei muokkaa Gatekeeperin yleisiä asetuksia, asenna Homebrew'ta eikä hanki D3DMetalia. Wine-ohjelmia ei suoriteta asennuksen aikana.

## Mitä eheystarkistus todistaa?

Tarkistus vertaa tiedostoja asennushetkellä muodostettuun paikalliseen luetteloon. Se auttaa löytämään vioittuneet, puuttuvat ja ylimääräiset tiedostot. Luettelo ei ole allekirjoitettu luottamusjuuri: samalla käyttäjätilillä jo toimiva haitallinen ohjelma voi mahdollisesti muuttaa sekä tiedostoja että luetteloa. Älä tulkitse onnistunutta tarkistusta haittaohjelmien tunnistukseksi.

Tavallinen käynnistystarkistus lukee metatiedot eikä tiivistä koko asennusta. **Installed** tarkoittaa tunnistettua asennusta, ei juuri tehtyä täyttä eheystarkistusta eikä Windows-ohjelman suoritusvalmiutta.

## Mitä on vielä tehtävä?

Testattu prosessien eristäminen, pullojen turvalliset oletukset, GStreamer ja muut riippuvuudet, ajoympäristön ominaisuuksien tunnistus, allekirjoitettu komponenttiluettelo sekä riippumaton tietoturva-arviointi ovat kesken. Myöskään sähkökatkon aikaista täydellistä levytallennuksen kestävyyttä ei ole todistettu.

Täysi [tietoturvamalli](https://mixutin.github.io/Mallow/SECURITY_MODEL/) ja [asentimen tekninen kuvaus](https://mixutin.github.io/Mallow/runtime-installation/) ovat englanniksi.

## Ilmoita ongelmasta yksityisesti

Käytä [GitHubin yksityistä tietoturvailmoitusta](https://github.com/mixutin/Mallow/security/advisories/new). Tavalliset käyttöliittymä- ja asennusvirheet voi ilmoittaa julkisena tehtävänä, kun raportissa ei ole salaisuuksia tai julkaisemattoman haavoittuvuuden yksityiskohtia.
