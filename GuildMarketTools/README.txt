# Guild Market Tools

Auction and profession tools for WoW Forever. English in-game UI; no character-specific UI, keybinds or bag configuration included.

## Download and install

**[Download the latest installable ZIP](https://github.com/tDavid93/GuildMarketTools/releases/latest)**

1. Download `GuildMarketTools-2.1.0.zip` from release assets, not the Source code ZIP.
2. Exit WoW and extract into `_forever_/Interface/AddOns/`.
3. Check that `Interface/AddOns/GuildMarketTools/GuildMarketTools.toc` exists.
4. Start WoW and enable **Guild Market Tools**.

**Magyarul:** a Releases oldalról az addon ZIP-et töltsd le. A benne lévő `GuildMarketTools` mappát másold az `_forever_/Interface/AddOns/` mappába, majd indítsd újra a játékot.

Updates replace the addon folder while WoW is closed. Keep your WTF folder: it contains your own market history and ledger. Disable legacy copies of the same market/vendor modules.

## Open

- Minimap coin: **left click** Market Tools, **right click** Professions; drag to move.
- AH title bar: **Market Tools** button.
- Commands: `/gmtools` or `/guildmarket`, `/gmvendor`, `/gmvalue`.

## Features

- Market deals, vendor bargains, price history, watchlist and purchase journal.
- Current listing verification before vendor-buy actions; purchases require user action.
- Market depth: loaded supply and price distribution, not actual sales volume.
- Professions: recipe filters and explicit sequential AH price refreshes.
- Vendor ingredients priced per unit; merchant quotes account for bundle size.
- Requirements across all 12 professions: 2493 spell-keyed records.
- Setup costs allocated across the planned craft count in estimated profit.
- Craft shopping with clickable material searches and a persistent panel.
- Confirmed AH purchase tracking and actual-cost allocation to completed batches.

## First use

Open each profession and choose **Read open profession**. At the AH select a recipe and **Refresh prices**. Set your planned craft count in **Buy materials**. Keep **Buy required setup** enabled when acquiring new tools/camp equipment; disable it when using existing setup. Other recipes default to one craft with new setup.

Confirmed AH purchases with verified prices are journaled automatically. Merchant price observations are estimates, not purchase receipts. Earlier stock and vendor purchases may require manual cost entry. Record completed crafts and actual output quantity in **Production costs**. The addon does not craft automatically.

## Compatibility and limitations

Targets WoW Forever interface **16001**. Other game clients are not supported. No required dependencies. Auctionator optionally supplies tooltip prices; AtlasLoot optionally supplies profession-skill and teaching-recipe metadata. EllesmereUI, TSM and bag addons are not required.

Profit is an estimate based on observed asking prices, configured AH fee and relist reserve. Missing, stale or unknown inputs are labelled. Cooldown opportunity cost is not assigned a fictional gold value; nearby station availability must be checked in the profession window. Versioned requirement data can lag hotfixes.

New installs start with empty personal data. No guild synchronization or remote realm price feed is included. Releases contain no account credentials or player SavedVariables.

Automated checks use Lua 5.1 with mocked WoW APIs. They do not replace in-game compatibility testing. For issues, include addon/client version, reproduction steps and the Lua error; omit private SavedVariables.

## Development

```sh
python -m pip install -r requirements-dev.txt
python scripts/check.py
python scripts/package.py
```

Runtime code is in `GuildMarketTools/`; tests use synthetic fixtures. The allowlisted release archive is written to `dist/` with one `GuildMarketTools/` root.

## License and data

Original code: MIT, see [LICENSE](LICENSE).

Requirement data derives from [ExcEssIv3/profit](https://github.com/ExcEssIv3/profit), build `1.60.1.70888`, commit `bbf0b653f8c14544e77d261fc2cb8b4606656b69`. Its MIT notice is included in `GuildMarketTools/LICENSE-Profit.txt`.

Nine gathering requirement facts come from [maf2414/wow-forever-talents](https://github.com/maf2414/wow-forever-talents/blob/bab6cc7556feb95978c11ecb64aaa403a1bf19dd/docs/professions-data.json), build `1.60.1.69876`, with separate source labels in-game. These are recipe requirements, not auction prices. No third-party addon code is bundled.
