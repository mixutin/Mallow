---
# SPDX-License-Identifier: 0BSD
title: Osallistu
description: Mallow'n rakentaminen, testaaminen, suomennosten ylläpito ja suorituskyvyn sekä tietoturvan todentaminen.
---

# Osallistu Mallow'n kehitykseen

Tällä hetkellä hyödyllisiä tehtäviä ovat asentimen testaus oikealla Macilla, jäljellä olevien tietomallien toteutus, virhetilanteiden testit ja dokumentaation ylläpito. [Englanninkielinen osallistumisohje](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md) sisältää koko prosessin ja lisenssisäännöt.

## Rakenna ja testaa

Tarvitset Swift 6.2:n tai uudemman. Mac-sovelluksen rakentamiseen tarvitaan Apple Silicon -Mac; koko suunnitelman tavoitetyökalu on Swift 6.3. Linuxissa kirjaston testaus tarvitsee järjestelmän libarchive-kehitystiedostot. Mac-versio linkittää käyttöjärjestelmän libarchive-kirjastoon.

```sh
git clone https://github.com/mixutin/Mallow.git
cd Mallow
swift build
scripts/test.sh
scripts/build-app.sh
```

Tavalliset yksikkötestit eivät käytä verkkoa tai suorita Winea. `scripts/test-runtime-install.sh` on erikseen ajettava verkkotesti, joka lataa oikean lukitun paketin erilliseen väliaikaishakemistoon, asentaa ja tarkistaa sen sekä varmistaa muutetun tiedoston tunnistuksen. Sekään ei suorita Winea.

## Päivitä molemmat kielet

Englanninkieliset sivut ovat hakemistossa `docs/`, suomenkieliset hakemistossa `docs-fi/`. Tarkista README, CHANGELOG, ROADMAP ja molempien kielten asiaankuuluvat sivut jokaisen toiminnallisen muutoksen yhteydessä. Suomenkielinen kehityssuunnitelma on yhteenveto, joten se päivitetään samassa muutoksessa englanninkielisen pääluettelon kanssa.

```sh
python3 -m pip install -r requirements-docs.txt
scripts/build-docs.sh
```

Skriptin molemmat tiukat sivustokäännökset ja HTML-tarkistukset on saatava läpi. Sivuston julkaiseminen on erillinen vaihe, jonka tila tarkistetaan GitHub Actionsista.

## Laadun periaatteet

Mittaa suorituskykyä ennen optimointiväitteitä. Pidä pitkät tiedostotyöt pois käyttöliittymän säikeeltä ja vältä tarpeettomia latauksia. Älä kierrä tietoturvatarkistuksia nopeuden vuoksi. Merkitse tehtävä valmiiksi vasta, kun kyseinen toteutus ja sovitut testit todella ovat olemassa.

Noudata DCO-käytäntöä ja puhtaan toteutuksen sääntöjä: Mallow'n 0BSD-koodiin ei kopioida GPL-käyttöliittymien tai CrossOverin suljettua toteutusta. Turvallisuuskriittisissä muutoksissa hyväksynnät ja testien rajat ilmoitetaan rehellisesti.
