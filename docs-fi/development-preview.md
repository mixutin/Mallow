---
# SPDX-License-Identifier: 0BSD
title: Kehitysversioiden testaus
description: Mallow'n todellinen Mac-testaus, asennuksen ja suorituskyvyn tarkistuslista sekä virheiden raportointi.
---

# Kehitysversioiden testaus

Automaattiset testit, julkaistu sovelluspaketti ja toimivuus omalla Macillasi ovat eri asioita. Ilmoita aina julkaisun tunniste, macOS-versio ja Macin malli. **Copy test report** kopioi sovelluksen lähdekoodiversion, edellytysten tilan ja viimeisimmän eheystarkistuksen tuloksen.

## Nykyinen testattava kokonaisuus

Wine-asennus, tiedostojen eheystarkistus, tumma pinkki käyttöliittymä, kukkalogo ja työvaiheiden latausilmaisimet. Windows-ohjelmien käynnistystä tai pelien FPS-lukemia ei vielä testata tällä versiolla.

Edellisen kehitysversion käyttäjä ilmoitti onnistuneesta Wine-paketin latauksesta ja SHA-256-tarkistuksesta. Se on käyttäjän raportoima lataustulos, ei näyttö uuden asentimen tai pelien toimivuudesta.

## Tarkistuslista omalle Macille

- [ ] Sovellus avautuu, logo näkyy ja teksti on luettavaa pienimmässä ikkunakoossa.
- [ ] Macin ja Rosettan tila on oikein; mitään ei asenneta ennen hyväksyntää.
- [ ] Aiemmin ladattu Wine-paketti käytetään uudelleen, tai uusi lataus valmistuu.
- [ ] Asennus päättyy tilaan **Installed**, ja Finder-painike näyttää oikean hakemiston.
- [ ] **Verify runtime** valmistuu ilman ongelmia ja raportoi tiedostomäärän sekä kuluneen ajan.
- [ ] Ikkunan siirto, vieritys ja peruutus pysyvät toimivina latauksen ja tarkistuksen aikana.
- [ ] Uudelleenkäynnistys ei lataa pakettia eikä tee automaattisesti koko asennuksen tiivistetarkistusta.
- [ ] Liikkeen vähentäminen macOS:n käyttöapu-asetuksissa pysäyttää pyörivän latausanimaation.
- [ ] Virhe tai peruutus lopettaa latausilmaisimen; epäonnistunutta asennusta ei näytetä valmiina.

Älä muokkaa varsinaista Wine-asennustasi vain tarkistuksen testaamiseksi. Automaattinen testaus käyttää siihen erillistä väliaikaista asennusta.

## Raportoi tulos

Liitä kopioitu raportti [tehtävään #44](https://github.com/mixutin/Mallow/issues/44). Kerro mitä painoit, mitä odotit ja mitä tapahtui. Kuvakaappaus auttaa käyttöliittymäongelmissa. Älä julkaise salasanoja, henkilökohtaisia hakemistosisältöjä tai muita yksityisiä tietoja.

Tietoturvaongelmat ilmoitetaan [yksityisesti](https://github.com/mixutin/Mallow/security/advisories/new), ei julkisena kommenttina.

## Komentorivin tarkistukset

Sovelluksen mukana tuleva komentorivityökalu sijaitsee polussa `Mallow.app/Contents/Helpers/mallow`.

```sh
mallow doctor --json
mallow runtime verify --json
mallow runtime path
```

`doctor` tarkistaa oletuksena vain metatiedot. `doctor --verify-archive --json` tarkistaa lisäksi välimuistissa olevan paketin tiivisteen. Täysi tiedostotarkistus tehdään komennolla `runtime verify`; ongelmista ilmoitetaan poistumiskoodilla 4.


[Mac-testien opas](mac-client-testing.md) kertoo uusista **Run client checks**- ja **Export report…** -toiminnoista, debug-versiosta ja testipaketista. Ne eivät todista Windows-yhteensopivuutta.
