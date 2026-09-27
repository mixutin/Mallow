---
# SPDX-License-Identifier: 0BSD
title: Mac-asiakasohjelman testaus
description: Mallow-ohjelman paikalliset testit, tietoja rajaava vianmääritysraportti ja debug-version käyttö.
---

# Ensimmäiset Mac-testit

Tämä kehitysversio valmistelee asiakasohjelman testausta. **Windows-ohjelmien käynnistys ja ytimen hiekkalaatikko eivät vielä ole toteutettuja.** [Tehtävä #48](https://github.com/mixutin/Mallow/issues/48) kokoaa oikeilla Maceilla tehdyt havainnot. Automaattinen CI-testi ei korvaa omaa testaustasi.

## Valitse oikea versio

Lataa saman `dev-…`-julkaisun tiedostot [GitHub Releases -sivulta](https://github.com/mixutin/Mallow/releases). `Mallow-macos-arm64.zip` on optimoitu versio tavalliseen testaukseen. `Mallow-debug-macos-arm64.zip` on erillinen, optimoimaton debug-versio koodin vaiheittaiseen tutkimiseen. Molemmissa on `Mallow.app`: käytä vain yhtä kerrallaan. Debug-version nopeus ei kuvaa julkaisuversiota.

Kummallakin on oma `…-symbols.zip`, jonka virheenjäljitystietojen UUID-tunnisteet tarkistetaan vastaamaan täsmälleen kyseisiä ohjelmatiedostoja. `Mallow-source.tar.gz` sisältää saman version lähdekoodin. `Mallow-test-kit.zip` sisältää testiskriptin ja englanninkielisen oppaan. Koontitiedot ovat tiedostoissa `build-info.json` ja `debug-build-info.json`.

`SHA256SUMS` kattaa kaikki julkaisutiedostot. Tarkista kaikki ladatut tiedostot komennolla `shasum -a 256 -c SHA256SUMS`. Puuttuvista tiedostoista tulee ilmoitus. Vain tavallisen sovelluksen tarkistus: `grep '  Mallow-macos-arm64.zip$' SHA256SUMS | shasum -a 256 -c -`.

Sovellus on ad hoc -allekirjoitettu, ei Applen notarisoima. Hyväksy tarvittaessa vain tämä sovellus macOS:n tietosuoja- ja suojausasetuksissa. Älä poista Gatekeeperiä tai SIP-suojausta käytöstä äläkä sivuuta haittaohjelmavaroitusta.

## Testaus sovelluksessa

Paina **Run client checks**. Tarkistukset erottavat tuetun käyttöjärjestelmän, Rosettan tunnisteen, Wine-asennuksen metatiedot, Wine- ja GStreamer-tiedostojen arkkitehtuuriotsakkeet sekä vielä puuttuvat toiminnot. Otsake ei todista kirjaston latautumista tai yhteensopivuutta.

Paikalliset testit tarkistavat JSON-tallennuksen atomisen korvaamisen, tiedostolukon, tunnetun SHA-256-testiarvon ja latausosoitteiden säännöt. Ne käyttävät pientä yksityistä tilapäishakemistoa. Ne eivät lataa mitään, suorita Wineä tai tutki henkilökohtaisia tiedostojasi. Normaalisti hakemisto siivotaan myös virheessä tai peruutuksessa; ohjelman äkillinen lopettaminen voi jättää sen jäljelle.

Tee raskas koko Wine-asennuksen eheystarkistus erikseen painikkeella **Verify runtime**. Paina sen jälkeen uudelleen **Run client checks**, jotta tuore raportti sisältää eheystarkistuksen ajan ja yhteenvetomäärät. Asennus tai tarkistus mitätöi vanhan raportin.

Tallenna raportti painikkeella **Export report…** tai kopioi se painikkeella **Copy test report**. Valitse uusi tiedostonimi: olemassa olevia tiedostoja ei korvata. Mitään ei lähetetä automaattisesti. Tarkista raportti ennen jakamista.

## Komentoriviltä

```sh
"/Applications/Mallow.app/Contents/Helpers/mallow" diagnostics --json
"/Applications/Mallow.app/Contents/Helpers/mallow" diagnostics --self-test --json --output "$HOME/Desktop/mallow-client-report.json"
"/Applications/Mallow.app/Contents/Helpers/mallow" runtime verify --json
```

Ensimmäinen komento vain lukee esitietoja. `--self-test` pyytää paikalliset tilapäistiedostoja käyttävät testit. Paluukoodi 0 ei tarkoita Windows-käynnistyksen olevan valmis: lue kunkin tarkistuksen tulos. Koodi 2 tarkoittaa virheellisiä argumentteja, 3 raportoinnin tai tallennuksen virhettä ja 4 sitä, etteivät kaikki pyydetyt testit läpäisseet tarkistusta.

Testipaketin `Run-Mallow-Client-Checks.command` tarkistaa sovelluksen allekirjoituksen, ajaa paikalliset testit ja avaa tuloskansion. Oletuspolku on `/Applications/Mallow.app`. Skripti ei asenna riippuvuuksia. Jaettava raportti on `report.json`; tarkista erilliset konsoli- ja virhetiedostot ennen niiden jakamista.

## Mittaukset ja yksityisyys

Raportti sisältää version, koontityypin, käyttöjärjestelmän, prosessorimäärän, RAM-kapasiteetin, tarkistukset, raportin keruuajan ja tämän prosessin elinkaaren suurimman fyysisen muistin määrän. Viimeiset enintään 32 toiminnon kestot säilyvät vain sovellusistunnossa. Mittaus ei kuvaa ensimmäisen ikkunan piirtämisaikaa, GPU-muistia, aliprosesseja tai pelien FPS-lukemia.

Raporttiin ei sisälly käyttäjänimeä, kotikansion polkua, sarjanumeroita, ympäristömuuttujia, raakalokeja, pelilistoja tai Wine-pullojen sisältöä. Eheysvirheistä viedään vain lukumäärä, ei tiedostonimiä. Testaa samalla optimoidulla versiolla ennen ja jälkeen muutoksen; älä merkitse tekemätöntä testiä valmiiksi.

Kirjaa Macin malli, macOS, lähdekoodiversio, toimenpide ja havainto. Kokeile ensikäynnistystä, välimuistin uudelleenkäyttöä, verkkoyhteydetöntä uudelleenavaamista, peruutusta, näppäimistöä, VoiceOveria ja liikkeen vähentämistä. [Englanninkielinen opas](https://mixutin.github.io/Mallow/mac-client-testing/) sisältää LLDB-ohjeet ja tarkemman raporttimuodon. Raaka kaatumis- tai debuggeriloki voi sisältää yksityisiä tietoja, joten tarkista se erikseen.
