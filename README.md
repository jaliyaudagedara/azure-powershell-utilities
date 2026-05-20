# powershell-utilities

A collection of small PowerShell utilities.

Utilities are grouped into folders by provider / domain (e.g. `azure/`, `other/`). Each utility is self-contained — see its folder's `README.md` for what it does and how to run it.

## Current utilities

- [`azure/`](./azure/README.md) — utilities for Azure resources.
- [`other/`](./other/README.md) — utilities for non-Azure providers.

### Prerequisites

- **PowerShell 7+** (`pwsh`). The scripts use PS 7-only features such as the 3-argument form of `Join-Path`. Windows PowerShell 5.1 is not supported.

Provider-specific CLI requirements, setup, and per-utility behaviour live in each group's README.
