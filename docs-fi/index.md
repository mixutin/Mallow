---
# SPDX-License-Identifier: 0BSD
title: Etusivu
description: Mallow-kehitysversio Apple Silicon -Maceille. Asenna Wine, tarkista tiedostojen eheys ja seuraa matkaa kohti Windows-ohjelmien suorittamista.
hide:
  - navigation
  - toc
---

<div class="mallow-hero" markdown>

<span class="mallow-status">Kehitysversio · Wine-asennus ja eheystarkistus</span>

# Mallow

<p class="mallow-hero__tagline">Rakennamme avointa tapaa käyttää Windows-ohjelmia ja pelejä Apple Silicon -Macilla.</p>

[Lataa kehitysversio](https://github.com/mixutin/Mallow/releases){ .md-button .md-button--primary }
[Käyttöönotto](getting-started.md){ .md-button }
[Kehityssuunnitelma](roadmap.md){ .md-button }

</div>

!!! warning "Ei vielä Windows-ohjelmien käynnistystä"

    Mallow asentaa ja rekisteröi nyt tarkistetun Wine-ajoympäristön. Pullojen luonti, Windows-ohjelmien käynnistyspolku ja ytimen hiekkalaatikko puuttuvat vielä. Asennettu Wine ei tarkoita, että koko sovellus olisi valmis.

## Mitä voit kokeilla nyt?

Mac-sovelluksessa on tumma pinkki ulkoasu ja sivustolta tuttu kukkalogo. Käyttöönotto tarkistaa Macin ja Rosettan, pyytää hyväksynnän tarvittaville asennuksille, käyttää jo ladattua Wine-pakettia uudelleen ja asentaa sen Mallow'n omaan hakemistoon. Työvaiheet näkyvät latausilmaisimessa. Mitään ei asenneta pelkällä sovelluksen avaamisella.

Asennuksen jälkeen **Verify runtime** tarkistaa tiedostojen eheyden. Tavallinen käynnistys tekee kevyen tilatarkistuksen eikä lue koko Wine-asennusta uudelleen. Tämä erottaa nopean käynnistyksen ja perusteellisen tarkistuksen toisistaan.

## Suorituskyky ja tietoturva

Tiedostoja käsitellään rajatuissa lohkoissa käyttöliittymän ulkopuolella. Asennus julkaistaan käyttöön vasta, kun purku ja tarkistukset ovat valmistuneet. Virheellisiä tarkistussummia, vaarallisia arkistopolkuja ja hakemiston ulkopuolelle johtavia linkkejä ei hyväksytä. Nämä suojaukset eivät vielä muodosta Windows-ohjelmien hiekkalaatikkoa.

[Katso testausohjeet](development-preview.md) ja [tietoturvan nykyiset rajat](security.md). Pelien suorituskyvystä ei vielä esitetä mittaustuloksia.

## Kielet ja dokumentaatio

Tärkeimmät käyttäjäsivut ovat saatavilla suomeksi. Sovelluksen käyttöliittymä, laaja tekninen suunnitelma ja vanhat kehityspäiväkirjamerkinnät ovat toistaiseksi englanniksi. Sivuston kielivalikosta pääset [englanninkieliselle sivustolle](https://mixutin.github.io/Mallow/).

Mallow'n oma koodi ja dokumentaatio julkaistaan 0BSD-lisenssillä. Hanke ei ole Applen, Microsoftin, Valven tai CodeWeaversin virallinen tuote.
