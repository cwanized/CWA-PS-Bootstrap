# Showcase Repo to learn with GitHub-Copilot (GPT-5.4)

## CWA-PS-Bootstrap

This repository is a public showcase for building a Windows client bootstrap workflow with PowerShell, `winget DSC`, declarative configuration, and iterative design/implementation.

## What this repo does

It bootstraps and validates Windows clients by using:

- client profiles in `Config/Clients`
- reusable categories in `Config/Categories`
- PowerShell module code in `PSModule/ClientBootstrap`
- `Report` and `Enforce` modes
- `winget DSC` as the preferred package mechanism for `winget` packages
- PowerShell profile and Oh My Posh setup
- optional PowerShell repositories and modules

## Quick start

Run the public install loader:

```powershell
irm https://raw.githubusercontent.com/cwanized/CWA-PS-Bootstrap/master/install.ps1 | iex
```

## Run with a specific client profile

Report mode:

```powershell
iex "& { $(irm https://raw.githubusercontent.com/cwanized/CWA-PS-Bootstrap/master/install.ps1) } -Mode Report -ConfigurationName GAMINGPC-CWA"
```

Enforce mode:

```powershell
iex "& { $(irm https://raw.githubusercontent.com/cwanized/CWA-PS-Bootstrap/master/install.ps1) } -Mode Enforce -ConfigurationName GAMINGPC-CWA"
```

## What `install.ps1` does

`install.ps1`:

- installs missing prerequisites like `git` and `pwsh` via `winget` when needed
- clones or updates the repository under `%LOCALAPPDATA%\CWA-PS-Bootstrap\repo`
- starts `bootstrap.ps1`

`bootstrap.ps1` then:

- installs required bootstrap PowerShell modules
- loads the ClientBootstrap module
- resolves the selected client configuration
- runs `Report` or `Enforce`

## Repository structure

- `install.ps1` — public entry loader
- `bootstrap.ps1` — repository bootstrap entrypoint
- `Config/Clients` — client profiles
- `Config/Categories` — reusable category definitions
- `Config/Applications` — profile fragments, Oh My Posh profiles, and app config assets
- `PSModule/ClientBootstrap` — PowerShell implementation
- `docs/PRD.md` — product requirements
- `docs/designconcept.md` — technical design concept

## Current scope

Implemented today:

- profile resolution
- additive category merge
- application source priority: `winget > choco > msi > exe`
- `winget DSC` integration
- PowerShell repository and module handling
- PowerShell profile generation
- Oh My Posh profile resolution
- logging to `Logs/`

## Notes

- This is a showcase and learning repository.
- Do not store secrets, tokens, or sensitive customer data in this public repository.
- For a new client, the matching profile in `Config/Clients/<client>.json` should already exist.

## More information

See:

- [docs/PRD.md](docs/PRD.md)
- [docs/designconcept.md](docs/designconcept.md)
