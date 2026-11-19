# Guild Market Tools

[English documentation](README.txt) · **Magyar útmutató**

Aukciós és szakmakezelő eszközök WoW Foreverhez. Az addon játékbeli felülete angol nyelvű; ez a dokumentum a magyar használati útmutató. Karakterspecifikus UI-t, billentyűkiosztást vagy táskabeállításokat nem tartalmaz.

## Letöltés és telepítés

**[A legújabb telepíthető kiadás letöltése](https://github.com/tDavid93/GuildMarketTools/releases/latest)**

1. A kiadás mellékletei közül a `GuildMarketTools-2.1.2.zip` fájlt töltsd le, ne a **Source code** ZIP-et.
2. Lépj ki a játékból, és csomagold ki az `_forever_/Interface/AddOns/` mappába.
3. Ellenőrizd, hogy ez az elérési út létezik: `Interface/AddOns/GuildMarketTools/GuildMarketTools.toc`.
4. Indítsd el a játékot, és engedélyezd a **Guild Market Tools** addont az AddOns listában.

Frissítéskor a játék bezárása után cseréld le az addon mappáját. A **WTF mappát tartsd meg**: abban vannak a saját beállításaid, ártörténeted és vásárlási naplód. A korábbi, azonos funkciójú market/vendor modulokat ne futtasd párhuzamosan ezzel az addonnal.

## Megnyitás

- **Minimap melletti érmeikon:** bal kattintásra Market Tools, jobb kattintásra Professions. Húzással áthelyezhető.
- **Az aukciós ház címsorában:** Market Tools gomb.
- **Parancsok:** `/gmtools` vagy `/guildmarket`; vendorajánlatokhoz `/gmvendor`; itemtooltip-beállításokhoz `/gmvalue`.

## Funkciók

- Piaci ajánlatok, vendorár alatti aukciók, ártörténet, figyelőlista és vásárlási napló.
- Az aktuális aukció árának és mennyiségének ellenőrzése a vendoros vétel előtt. A vásárláshoz felhasználói művelet kell.
- Piaci kínálat és áreloszlás: a betöltött ajánlatokat mutatja, nem a tényleges eladások számát.
- Receptszűrők és külön indítható, egymás után végzett AH-árfrissítések.
- Vendoros alapanyagok darabára, a kereskedőnél látott csomagméret figyelembevételével.
- Mind a 12 szakmát lefedő követelményadatbázis, 2493 receptazonosítóval.
- A szükséges eszközök és előkészítés költségének elosztása a tervezett craftok között.
- Kattintható alapanyagkeresés, nyitva maradó beszerzési panellel.
- Visszaigazolt AH-vásárlások naplózása és tényleges költségük hozzárendelése a kész gyártási tételekhez.

## Első használat és gyártás

1. Nyisd meg a szakmádat, majd kattints a **Read open profession** gombra. Ezt minden használt szakmánál végezd el.
2. Az AH-nál válassz receptet, és indítsd el a **Refresh prices** műveletet.
3. A **Buy materials** panelen add meg, hány craftot tervezel, majd nyomd meg az **Update plan** gombot.
4. A **Buy required setup** maradjon bekapcsolva, ha új eszközöket vagy tábori felszerelést veszel. Meglévő felszerelés használatakor kapcsold ki.
5. Az alapanyag linkjével keresd meg az ajánlatokat. Az AH saját vásárlófelületén vásárolj; a beszerzési panel nyitva marad.
6. Az elkészült craftok számát és a ténylegesen előállított mennyiséget a **Production costs** alatt rögzítsd.

Az aktív terv profitja a megadott craftszámmal osztja el az egyszeri előkészítési költséget. Terv nélküli recepteknél egy crafttal és új felszerelés beszerzésével számol.

A visszaigazolt AH-vásárlás mennyisége és ellenőrzött ára automatikusan naplózható. A kereskedőnél megfigyelt ár azonban **nem vásárlási bizonylat**. A korábban meglévő készlethez és a vendoros vásárlásokhoz kézi költségrögzítés is szükséges lehet. Az addon nem gyárt automatikusan.

## Függőségek

**Nincs kötelező másik addon.** Az opcionális kiegészítőkből WoW Foreverrel kompatibilis verziót használj.

| Addon | Szükséges? | Mire használjuk? | Mi történik nélküle? |
| --- | --- | --- | --- |
| Auctionator | Opcionális, ajánlott | Az itemtooltip AH-ára és az ár kora a nyilvános API-n keresztül | A vendorérték megmarad; a tooltip AH-összehasonlításához Auctionator-adat kell. A Market Tools saját AH-lekérdezései tovább működnek. |
| AtlasLootContinued | Opcionális, ajánlott | Minimális szakmaszint és a receptet tanító tárgy adatai | Az ismeretlen tanulási követelményű receptek kimaradnak a **Learnable now** szűrőből. A már elmentett adatok használhatók maradnak. |
| EllesmereUI, TSM, Baganator és más táskaaddonok | Nem | Nem függőségek | Az addon nélkülük is működik. |
| LibDBIcon / LibDataBroker | Nem | Nem függőségek | A minimapgomb beépített. |

A receptkövetelmény-adatbázis a csomag része. Az opcionális addonokat külön kell telepíteni; nem csomagoljuk őket a ZIP-be. A TOC fájlban `OptionalDeps` jelöli őket, nem kötelező `Dependencies`. Python és `lupa` csak a fejlesztői tesztekhez kell, játékosként nincs rájuk szükséged.

## Frissítések

Minden elkészült addonmódosításhoz frissül a GitHub-repo, és új verziózott ZIP készül változásjegyzékkel és ellenőrzőösszeggel. A guildben a **[legújabb kiadást](https://github.com/tDavid93/GuildMarketTools/releases/latest)** használjátok; a verzió a játék AddOns listájában ellenőrizhető.

A GitHubra feltöltés **nem frissíti automatikusan** a telepített példányokat. Minden játékosnak le kell töltenie az új ZIP-et, és bezárt játék mellett lecserélnie az addon mappáját.

## Kompatibilitás és korlátok

Az addon WoW Foreverhez, **16001-es interfészverzióhoz** készült. Más WoW-kliensek nem támogatottak.

A profit becslés: megfigyelt hirdetési árakon, a beállított AH-jutalékon és újralistázási tartalékon alapul. Nem garantált eladási bevétel. A hiányzó, elavult vagy ismeretlen adatokat külön jelöli. A cooldown idejéhez nem rendel kitalált goldköltséget; a közeli állomás tényleges elérhetőségét a szakmaablakban kell ellenőrizni. A követelményadatbázis a játék hotfixeihez képest késhet.

Új telepítésnél a személyes adatok üresek. Nincs beépített guildszinkronizáció vagy külső, folyamatos realmár-adatfolyam. A kiadások nem tartalmaznak fiókadatokat vagy játékosmentéseket.

Az automatikus tesztek Lua 5.1-et és szimulált WoW API-t használnak; nem helyettesítik a játékbeli próbát. Hibajelentéshez add meg az addon és a kliens verzióját, a reprodukció lépéseit és a Lua-hibát. Személyes SavedVariables fájlokat ne mellékelj nyilvánosan.

## Fejlesztés

```sh
python -m pip install -r requirements-dev.txt
python scripts/check.py
python scripts/package.py
```

A futó addon forrása a `GuildMarketTools/` könyvtárban van. A tesztek mesterséges adatokkal dolgoznak. A csomagoló csak az engedélyezett fájlokat teszi a `dist/` mappában létrejövő ZIP-be, egyetlen `GuildMarketTools/` gyökérmappával.

## Licenc és adatforrások

A saját kód MIT-licencű: [LICENSE](LICENSE).

A követelményadatok alapja az [ExcEssIv3/profit](https://github.com/ExcEssIv3/profit) adatbázisa, `1.60.1.70888` build, `bbf0b653f8c14544e77d261fc2cb8b4606656b69` commit. MIT-licence a csomag `LICENSE-Profit.txt` fájljában is megtalálható.

Kilenc gathering-recept követelményadata a [maf2414/wow-forever-talents](https://github.com/maf2414/wow-forever-talents/blob/bab6cc7556feb95978c11ecb64aaa403a1bf19dd/docs/professions-data.json) forrásból származik, `1.60.1.69876` buildből; a felületen külön forrásjelölést kapnak. Ezek receptadatok, nem aukciós árak. Más addon futtatható kódját nem csomagoljuk a kiadásba.
