---
# SPDX-License-Identifier: 0BSD
title: Usein kysytyt kysymykset
description: Vastaukset Mallow-kehitysversion asennukseen, rajauksiin, latausilmaisimeen, kieliin ja turvallisuuteen.
---

# Usein kysytyt kysymykset

## Voinko jo pelata Windows-pelejä?

Et tällä versiolla. Mallow asentaa Wine-ajoympäristön, mutta pullojen luonti, Windows-käynnistys ja hiekkalaatikko puuttuvat vielä. Seuraava keskeinen tavoite on ensimmäinen toistettavasti toimiva Notepad-käynnistys, ei laaja peliyhteensopivuus.

## Mikä muuttui pelkkään lataukseen verrattuna?

Uusi **Install selected dependencies** -toiminto purkaa tarkistetun paketin ja rekisteröi ajoympäristön Mallow'n omaan datahakemistoon. Se ei jätä tehtävää pelkäksi ZIP- tai TAR-tiedostoksi välimuistiin. Aiemmin ladattu oikea paketti käytetään uudelleen.

## Miksi asennettu runtime ja valmis Windows-ympäristö ovat eri asioita?

Wine-tiedostojen lisäksi tarvitaan yhteensopivuuden tarkistus, puuttuvat riippuvuudet, erillinen pullo, oikea käynnistysympäristö ja suojaus. Sovellus ei ilmoita näitä tehdyiksi pelkän asennuksen perusteella.

## Onko Mallow ilmainen?

Mallow'n oma koodi ja dokumentaatio ovat 0BSD-lisenssillä, eikä kehitysversiossa ole maksullista tilausta. Wine ja muut erilliset komponentit säilyttävät omat lisenssinsä. Omat ohjelmasi ja pelisi ovat niiden omien käyttöehtojen alaisia.

## Miksi sovellus pyytää hyväksyntää?

Lataus ja asennus tehdään vasta hyväksymisen jälkeen. Rosettalla on lisäksi Applen lisenssi. Valintaruutua ei rastiteta käyttäjän puolesta, eikä pelkkä sovelluksen avaaminen aloita asennusta.

## Miksi pyörivää latausilmaisinta ei näy koko ajan?

Se näkyy vain todellisen työn aikana eikä lisää keinotekoista viivettä. macOS:n liikkeen vähentäminen pysäyttää animaation. Sivuston ilmaisin ei estä tekstin lukemista tai linkkien käyttöä ja poistuu sivun valmistuttua.

## Onko koko hanke suomeksi?

Keskeiset verkkosivut on käännetty suomeksi. Sovelluksen käyttöliittymä, historialliset blogikirjoitukset ja yksityiskohtaiset tekniset suunnitelmat ovat vielä englanniksi. Kielivalinta ei peitä tätä rajausta.

## Mitä teen, jos eheystarkistus epäonnistuu?

Älä käytä vaurioitunutta runtimea. Kopioi raportti ja ilmoita ongelma. Mallow säilyttää asennuksen eikä korvaa sitä hiljaisesti. Korjaus ja palautus aiempaan versioon ovat myöhempää kehitystyötä.

## Entä Intel-Mac, anti-cheat tai D3DMetal?

Tämä julkaisu on tarkoitettu Apple Silicon -Maceille. Anti-cheatin ohittamista ei toteuteta. D3DMetalia ei ladata, pakata tai jaella Mallow'n mukana; käyttäjän oman Applen työkalupaketin tuonti on tuleva ominaisuus.

## Todistaako onnistunut CI-ajo turvallisuuden?

Ei. Testit tarkistavat tiettyjä toimintoja ja virhetilanteita. Ne eivät korvaa oman Macin käyttöliittymätestausta, pelitestejä tai riippumatonta tietoturva-arviointia. [Tietoturvasivu](security.md) erottaa nykyiset suojaukset tulevasta hiekkalaatikosta.
