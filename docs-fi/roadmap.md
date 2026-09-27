---
# SPDX-License-Identifier: 0BSD
title: Kehityssuunnitelma
description: Mallow'n toteutetut osat ja avoimet tehtävät matkalla ensimmäiseen Windows-ohjelman käynnistykseen. Suorituskyky ja tietoturva ovat keskeisiä tavoitteita.
---

# Kehityssuunnitelma

**Päivitetty 27.9.2026.** Tämä on käyttäjille tarkoitettu suomenkielinen yhteenveto. [Koko kehityssuunnitelma](https://mixutin.github.io/Mallow/roadmap/) on englanniksi ja muodostaa yksityiskohtaisen tehtäväluettelon. Kumpaakaan virstanpylvästä v0.1 tai v0.3 ei ole merkitty valmiiksi.

## Toteutettu

- [x] MallowKit-kirjasto, ensimmäiset tietomallit ja testit sekä atominen JSON-tallennus.
- [x] Macin ja Rosettan tunnistus sekä erikseen hyväksyttävä Rosetta-asennuspyyntö.
- [x] Versioon lukitun Wine-paketin HTTPS-lataus, koko- ja SHA-256-tarkistus sekä välimuistin uudelleenkäyttö.
- [x] Wine-paketin purku yksityiseen väliaikaishakemistoon, tiedostojen tarkistus ja valmiin ajoympäristön rekisteröinti.
- [x] Mallow'n oman datahakemiston tunniste ja asennusta suojaava tiedostolukko.
- [x] Asennetun ajoympäristön eheystarkistus sovelluksesta ja komentoriviltä.
- [x] Tumma pinkki sovellus, yhteinen kukkalogo ja käyttöapu-asetukset huomioivat latausilmaisimet.
- [x] Automaattisesti muodostettavat Mac-kehitysversiot ja julkaisut lähdekoodiversion mukaan.
- [x] Keskeiset käyttäjäsivut suomeksi, kielivalinta ja sivuston kevyt latausilmaisin.

Toteutettu ominaisuus ei tarkoita kattavaa yhteensopivuustestausta kaikilla Maceilla. [Oman Macin testauslista](development-preview.md) säilyy erillisenä.

## Tie ensimmäiseen Windows-ohjelmaan

- [ ] Viimeistele WF0-tietomallit ja tiedostomuotojen skeemat.
- [ ] Lisää ajoympäristön ominaisuuksien tunnistus ja tarvittavien lisäriippuvuuksien, kuten GStreamerin, käyttöönotto.
- [ ] Toteuta pullojen tallennus, luonti ja asetukset ilman tietojen menettämistä.
- [ ] Lisää testikorvike Winelle, käynnistyssuunnittelija ja prosessien hallinta.
- [ ] Toteuta ja testaa ytimen hiekkalaatikko ja pullojen turvalliset oletukset.
- [ ] Käynnistä Notepad Apple Silicon -Macilla toistettavasti ja tallenna testitulokset.

## Suorituskyvyn ja tietoturvan hyväksymisehdot

Kevyt käynnistys ei saa muuttua koko Wine-asennuksen lukemiseksi. Tiivisteet ja purku käsitellään rajatuissa lohkoissa käyttöliittymän ulkopuolella. Latausanimaatioita ei ajeta valmiustilassa, eikä sivusto piilota sisältöä latausilmaisimen taakse.

Vastaavasti nopeus ei oikeuta tarkistussumman ohittamista, epäonnistuneen asennuksen hyväksymistä, tietoturva-asetusten hiljaista heikentämistä tai hiekkalaatikon puuttumisen peittelyä. Käynnistysajat, muistin käyttö ja myöhemmin pelien suorituskyky mitataan; FPS-parannuksia ei arvata.

## Myöhemmät kokonaisuudet

Oma julkisesti rakennettu Wine-ajoympäristö ja allekirjoitettu komponenttiluettelo, täydellinen pullo- ja ohjelmakäyttöliittymä, Steam ja riippuvuusreseptit, käyttäjän toimittama D3DMetal, diagnostiikka sekä allekirjoitettu ja notarisoitu jakelu ovat seuraavia suunniteltuja kokonaisuuksia. Julkaisupäiviä ei luvata.
