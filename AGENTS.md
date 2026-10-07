# Bifrost agent instructions

## Preserve the Bifrost build pipeline during system updates

Run `tools/Test-BifrostPipeline.ps1` and `tools/Test-SharedAlpacaContainer.ps1` before
opening a pipeline PR; the independent **Bifrost Pipeline Guards** workflow runs both.
AL-Go and Alpaca updates must retain sequential Default/Test builds, filtered container
creation, physical container identity, Test production-app republishing, Default internals
stripping, signing requests, deferred cleanup, merged settings before secrets, and Test-only
upgrade skipping. Keep this repository's app IDs, action versions, dependency settings and
deployment variables. Apply compatible upstream updates and reapply the Bifrost custom blocks
before pushing; do not disable the guard or exclude generated workflows from future updates.
