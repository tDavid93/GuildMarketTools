# Guild Market Tools

**English** · [Magyar útmutató](README.hu.md)

Auction and profession tools for WoW Forever. English in-game UI; no character-specific UI, keybinds or bag configuration included.

## Download and install

**[Download the latest installable ZIP](https://github.com/tDavid93/GuildMarketTools/releases/latest)**

1. Download `GuildMarketTools-2.1.7.zip` from release assets, not the Source code ZIP.
2. Exit WoW and extract into `_forever_/Interface/AddOns/`.
3. Check that `Interface/AddOns/GuildMarketTools/GuildMarketTools.toc` exists.
4. Start WoW and enable **Guild Market Tools**.


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

## Dependencies

**No other addon is required.**
Use the WoW Forever-compatible version of each optional integration.

| Addon | Required? | Used for | Without it |
| --- | --- | --- | --- |
| Auctionator | Optional, recommended | Item-tooltip AH price and price age through its public API | Tooltip vendor value remains available; AH comparison needs Auctionator data. Market/recipe queries still use the native AH. |
| AHledger | Optional | Estimated daily sales and community prices in Professions | Local scans and profit calculations work; provider fields show `--`. |
| AtlasLootContinued | Optional, recommended | Minimum profession skill and teaching-recipe metadata | Bundled learning metadata is used where available. Unknown character levels remain labelled; trainer candidates can be checked at the trainer. |
| EllesmereUI, TSM, Baganator or other bag addons | No | Not dependencies | Market Tools works without them. |
| LibDBIcon / LibDataBroker | No | Not dependencies | The minimap button is built in. |

Optional integrations are declared in the TOC as `OptionalDeps`, not mandatory
`Dependencies`. Install them separately; they are not bundled in the ZIP.
Python and `lupa` are needed only for developers running tests, not for players.

## Updates

Every maintained addon change is published to this repository and as a new
versioned ZIP with release notes and a checksum. Use the [latest release](https://github.com/tDavid93/GuildMarketTools/releases/latest)
to keep guild installations on the same version. Check the version in the game's
AddOns list. GitHub publication does **not** automatically update installed copies;
each player must replace their addon folder with the new release while WoW is closed.

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

### Learning filter

**Learnable / check trainer** includes unlearned recipes at your recorded profession skill. Known character-level limits still apply. Trainer-taught recipes without a verified character-level requirement are included as **Check trainer**, not guaranteed learnable. Item-taught recipes with unknown character requirements remain excluded. The bundled database supplies minimum skill and teaching-item IDs without AtlasLoot where available. Open the profession and use **Read open profession** to refresh skill and learned status; the addon cannot infer an unimported profession or another character's skill.

### Missing price diagnostics

The price-status column distinguishes No sale price, Missing mats and Missing setup. Select a recipe to see the item name/ID, its role and why the quote is unavailable. Unknown names request client item data automatically. A known cost subtotal remains visible when total cost is incomplete; it is not a profit estimate. Missing AH quotes are not replaced with fabricated prices. Recursive intermediate crafting and recipe-rank selection are not implemented by this update.

### Vendor material defaults

Threads, dyes and common vendor supplies have bundled neutral per-unit estimates, so crafting costs do not require a prior merchant visit. Coarse Thread defaults to 10 copper and Fine Thread to 100 copper. A valid saved merchant quote (including reputation discounts and bundle normalization) overrides the default. Unknown vendor items remain explicitly unpriced. Defaults derive from the same MIT-licensed Profit snapshot, Data/Items.lua; they are estimates, not actual purchase records. Missing output AH quotes still prevent a profit estimate, but complete material costs remain visible.

## Recipe sharing and market supply

Professions now separates Summary, Materials, Market and Setup details. Select a recipe, then use **Link to chat**, or **Shift-click** its row, to insert the crafted item link into chat. Nothing is sent automatically. Uncached item links request client data; click again after it loads.

**Copy Wowhead link** opens a selected URL: press Ctrl+C. It searches by recipe name because Forever-specific IDs and recipes may not match Wowhead.

The **Market** detail tab shows available units, loaded asking value, auction count where known, weighted median and quartiles. Use **Market depth → Refresh AH depth** at the auction house for detailed results. Browse-only observations show quantity without inventing a market value. Age and partial coverage are explicit. Supply is not sales volume: sale velocity remains unknown without completed-sale evidence.


## Optional AHledger integration

Install [AHledger](https://www.curseforge.com/wow/addons/ahledger) separately (0.9.8+, latest Forever release recommended). It is not bundled in our ZIP. Integration uses public AHledgerAPI version 1. Restart the game after installing a new addon.

Professions has a sortable **Est. sold/day** column for estimated units sold across the whole market. Zero is a known zero estimate; `--` means unknown; `*` marks old/unknown age or a bundled snapshot. Data older than one hour is marked old. Summary shows the provider median; Market shows minimum, median, 7/30-day medians, 30-day range, listed units, market identity and table age. These are provider estimates, not guaranteed sales.

Local AH crafting costs and profit are unchanged. Provider data is not copied into local price history. Prices from AHledger (ahledger.com) is credited where shown.

For current community data use the free [AHledger Sync](https://ahledger.com/download): select SavedVariables/AHledger.lua and connect your own AHledger account. Downloaded prices appear after `/reload`. Check the market shown in the Market details; AHledger controls it via `/ahl market`. Use `/ahl scanner on` to suppress AHledger’s additional UI.

Chat linking now supports Forever’s ChatFrameUtil API as well as legacy clients. The button or Shift-click inserts the crafted item into chat without sending it.
