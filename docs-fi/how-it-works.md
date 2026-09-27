---
# SPDX-License-Identifier: 0BSD
title: Toimintaperiaate
description: Mitä Wine, Rosetta, pullot ja grafiikkataustat tarkoittavat Mallow'ssa, ja mitkä osat ovat vielä suunnitteilla.
---

# Miten Mallow toimii?

Mallow'n tavoitteena on yhdistää Windows-yhteensopivuus, natiivi Mac-käyttöliittymä ja rajattu suoritusympäristö. Tämänhetkinen versio toteuttaa vasta ajoympäristön asennuksen ja tarkistuksen. Alla kuvattu Windows-ohjelmien suoritusketju on vielä suunnitelma.

**Wine** toteuttaa Windowsin ohjelmointirajapintoja macOS:n päällä. Se ei asenna Windows-käyttöjärjestelmää eikä itsessään muodosta tietoturvahiekkalaatikkoa.

**Rosetta 2** mahdollistaa Intel-koodin ajamisen Apple Silicon -Macilla. Mallow pyytää Rosettan asennusta Applen omalla työkalulla vain lisenssin hyväksymisen jälkeen.

**Pullo** tarkoittaa erillistä Wine-ympäristöä, jolla on oma C-asema, rekisteri ja asetukset. Pullojen luonti ja hallinta ovat vielä toteuttamatta.

**Grafiikkatausta** muuntaa Windows-ohjelman grafiikkakutsut Macille sopiviksi. Suunniteltuja vaihtoehtoja ovat WineD3D, DXMT, DXVK ja käyttäjän omasta Applen työkalupaketista tuotu D3DMetal. Nykyinen Mallow-versio ei vielä määritä näitä pelikohtaisesti.

**Ytimen hiekkalaatikko** on suunniteltu suojaamaan Macin muita tiedostoja Windows-ohjelmalta. Asennuksen tarkistussumma tai erillinen kansio ei korvaa tätä suojausta. Windows-ohjelmien käynnistystä ei ole vielä otettu käyttöön.

## Asennus nyt

Hyväksytty lataus → tarkistettu yksityinen pakettikopio → rajattu arkiston purku → tiedostoluettelo tiivisteineen → valmiin Wine-hakemiston rekisteröinti.

Käyttöliittymä ja komentorivityökalu käyttävät samaa MallowKit-kirjastoa. Pitkät työvaiheet erotetaan käyttöliittymästä, ja niiden tilaa näytetään ilman keinotekoista odotusta.

[Tekninen suunnitelma englanniksi](https://mixutin.github.io/Mallow/DESIGN/) sisältää koko tavoitearkkitehtuurin. [Kehityssuunnitelma](roadmap.md) kertoo tämänhetkisen edistymisen.
