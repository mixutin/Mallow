---
# SPDX-License-Identifier: 0BSD
title: Käyttöönotto
description: Mallow-kehitysversion lataaminen, Wine-ajoympäristön asennus ja tiedostojen eheystarkistus Macilla.
---

# Käyttöönotto

Tarvitset Apple Silicon -Macin, macOS 15:n tai uudemman sekä vähintään 2 Gt vapaata tilaa asennuksen väliaikaisia tiedostoja varten. Wine-paketin latauskoko on noin 185 Mt. Kehitysversio ei vielä käynnistä Windows-ohjelmia.

## Lataa ja avaa Mallow

Valitse [GitHub Releases -sivulta](https://github.com/mixutin/Mallow/releases) uusin `dev-…`-kehitysversio. Lataa samasta julkaisusta `Mallow-macos-arm64.zip` ja `SHA256SUMS`.

Tarkista tiedosto Päätteessä siinä hakemistossa, johon latasit molemmat:

```sh
shasum -a 256 -c SHA256SUMS
```

Pura ZIP ja siirrä `Mallow.app` Ohjelmat-kansioon. Tämä kehitysversio on ad hoc -allekirjoitettu, mutta sillä ei ole Developer ID -allekirjoitusta eikä Applen notarisointia. macOS voi pyytää hyväksymään juuri tämän sovelluksen kohdassa **Järjestelmäasetukset → Tietosuoja ja suojaus**. Älä poista Gatekeeperia käytöstä koko koneessa.

## Asenna ajoympäristö

Avaa sovellus ja odota Macin tietojen tarkistusta. Valitse **Install Wine 11.0_1**, tutustu lähteeseen ja lisenssiin sekä hyväksy lataus ja asennus. Jos Rosetta puuttuu, voit valita sen asennuksen ja hyväksyä Applen lisenssin erikseen. Paina **Install selected dependencies**.

Mallow lataa paketin tarvittaessa. Aiemman version lataama paketti tarkistetaan ja käytetään uudelleen. Asennus tarkistaa SHA-256-tiivisteen myös yksityiseen väliaikaishakemistoon kopioidusta paketista, purkaa sen, tarkistaa tiedostot ja rekisteröi valmiin Wine-ajoympäristön. Alkuperäinen `Wine Stable.app` -hakemistorakenne säilytetään.

Asennus sijaitsee oletuksena hakemistossa:

```text
~/Library/Application Support/Mallow/Runtimes/standard-wine-stable-11.0_1/
```

**Show runtime in Finder** avaa sijainnin Finderissa. **Verify runtime** tarkistaa asennetut tiedostot ja raportoi puuttuvat, muuttuneet tai ylimääräiset tiedostot. Vaurioitunutta asennusta ei korvata hiljaisesti; automaattinen korjaus on vielä tekemättä.

## Mitä vielä puuttuu?

GStreamerin käyttöönotto, pullojen luonti, grafiikkataustojen määritys ja testattu hiekkalaatikko ovat kesken. Siksi Windows-ohjelmien käynnistys ei ole käytössä. D3DMetalia ei ladata tai toimiteta sovelluksen mukana.

[Testaa kehitysversiota](development-preview.md) ja ilmoita tulos **Copy test report** -painikkeella kopioidun raportin kanssa.
