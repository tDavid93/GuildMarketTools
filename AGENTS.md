# Guild Market Tools maintenance

The owner has authorized ongoing publication: every completed addon change must
also update this GitHub repository and produce a new downloadable GitHub Release.
Do not stop after editing the installed addon or pushing source only.

- Treat `GuildMarketTools/` here as the distributable source. Compare it with the
  installed addon before editing; preserve unrelated local changes.
- Keep the installed runtime and release source aligned. Never publish player
  SavedVariables, account paths, private test fixtures or personal UI modules.
- Increment the TOC version for every release and update CHANGELOG.md, README.md
  and the packaged README.txt. Document dependency changes explicitly.
- Run `python scripts/check.py` and `python scripts/package.py`; inspect the diff
  and archive contents. The package allowlist must remain explicit.
- Commit and push to the owner's existing repository, wait for CI, then publish
  a matching version tag/release with the ZIP and SHA256SUMS.txt.
- Verify the public download matches the tested ZIP. Report the release URL and
  relevant verification. If publication is blocked, say exactly what remains.
- Use release notes from a file, keep tests synthetic, and do not claim live WoW
  testing when only mocked tests have run.
- Future changes do not require another publication confirmation unless the owner
  changes this instruction or the operation goes beyond this repository's scope.

Publishing a release does not automatically update guildmates' installations;
they must install the new ZIP or use a compatible addon updater.
