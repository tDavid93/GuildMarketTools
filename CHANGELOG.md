# Changelog

## 2.1.6 — 2026-11-22

- Reorganize Professions into a compact recipe table and wider Summary / Materials / Market / Setup details.
- Add crafted-item chat insertion by button and Shift-click; no automatic sending.
- Add copyable Wowhead name-search links compatible with custom-realm naming.
- Show observed supply units, asking value, weighted price distribution, coverage and age; do not infer sales velocity.
- Test recipe selection, all detail tabs, link insertion/copying, cache misses and partial/empty market data.
- No new dependencies.

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
