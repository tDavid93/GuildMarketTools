# Changelog

## 2.1.5 — 2026-11-19

- Supply neutral per-unit defaults for 24 vendor ingredients, including Coarse and Fine Thread.
- Preserve valid observed merchant discounts over defaults; ignore invalid saved quotes.
- Fix missing Tailoring costs caused by unobserved thread prices; retain real missing output-price status.
- Add screenshot-based regression cases.

## 2.1.4 — 2026-11-19

- Distinguish missing output, material and setup prices, with item IDs and actionable reasons.
- Request missing item names asynchronously and use known tool names as fallback.
- Show known cost subtotals without presenting incomplete costs as profit.
- Add missing-price and item-cache regression tests.

## 2.1.3 — 2026-11-19

- Fix exclusion of trainer recipes without teaching items from the learning filter.
- Add bundled minimum-skill and teaching-item metadata for all professions in the source dataset.
- Label unverified trainer candidates explicitly; preserve known character-level and skill limits.
- Add Tailoring and Enchanting learning regression tests.

## 2.1.2 — 2026-11-19

- Add a complete Hungarian README with installation, dependencies and usage instructions.
- Link both languages and include the Hungarian guide in the installable ZIP.
- Correct previously corrupted Hungarian text in the English guide. No gameplay changes.

## 2.1.1 — 2026-11-19

- Document required versus optional dependencies and behavior without each integration.
- Add player update instructions and a persistent maintainer release policy.
- Synchronize the installed addon version with the public release. No gameplay logic changes.

## 2.1.0 — 2026-11-19

Initial public guild release: market/vendor analysis, all-profession requirement data, setup-cost profit estimates, persistent craft shopping, purchase journal, production costs and draggable minimap launcher.

Personal UI modules and SavedVariables are excluded. Includes Lua 5.1 checks and mocked behavior tests. Live compatibility still depends on client build and server hotfixes.
