# Improvement Review

## Summary

Overall, the repository is **logically structured and understandable**.
The split between declarative data under `Config/` and orchestration code under `PSModule/` is a strong foundation.

The current main architectural weakness is **entrypoint overlap**, especially between `install.ps1` and `bootstrap.ps1`.
The repository works, but the current shape still carries some transitional logic and duplicated responsibilities.

## What is already good

### Clear separation of concerns

The broad structure is sensible:

- `Config/` contains declarative client and category data
- `PSModule/ClientBootstrap/` contains runtime logic
- `install.ps1` is the public entrypoint
- `bootstrap.ps1` is the repository bootstrap entrypoint
- `docs/` contains requirements and design material

This is the right general direction.

### Reasonable module layout

The module is split into:

- configuration resolution
- operations/report/enforce
- logging
- winget DSC integration
- PowerShell repository/module handling

That is a good base for future refactoring.

### Good conceptual choices

The following decisions are strong:

- additive category merge
- explicit source priority: `winget > choco > msi > exe`
- separate `Report` and `Enforce`
- PowerShell profile generation from fragments
- explicit Oh My Posh conflict handling
- using `winget DSC` as the preferred `winget` path

## Main improvement areas

## 1. Make `install.ps1` the only remote/public loader

### Current situation

Right now both entry scripts still contain bootstrap-style logic:

- `install.ps1` handles prerequisite installation and repository checkout
- `bootstrap.ps1` still also contains repository checkout and `pwsh` relaunch logic

Relevant files:

- [install.ps1](../install.ps1)
- [bootstrap.ps1](../bootstrap.ps1)

### Why this matters

This creates a blurred contract:

- which file is the real external entrypoint?
- which file is safe to call only from inside a repository checkout?
- where should repository acquisition logic live?

This is the biggest source of conceptual redundancy in the repo.

### Recommendation

Adopt this strict contract:

- `install.ps1` = **public loader only**
- `bootstrap.ps1` = **local repository bootstrap only**

That means `bootstrap.ps1` should no longer:

- clone or pull the repository
- know the remote repository URL
- know the checkout path under `%LOCALAPPDATA%`

After that change:

- `install.ps1` prepares the machine and gets the repo
- `bootstrap.ps1` assumes the repo already exists and only runs the local bootstrap flow

### Expected benefit

- clearer responsibilities
- less duplication
- simpler mental model
- easier future maintenance

## 2. Remove duplicate bootstrap dependency logic

### Current situation

Bootstrap PowerShell dependencies are declared in more than one place:

- `bootstrap.ps1` contains `Install-BootstrapPowerShellDependencies`
- [PSModule/ClientBootstrap/Private/BootstrapPowerShellModules.ps1](../PSModule/ClientBootstrap/Private/BootstrapPowerShellModules.ps1) already contains `Get-BootstrapPowerShellModuleDefinitions()` and related installation logic

### Why this matters

The module list can drift over time.
A future change may update one place but forget the other.

### Recommendation

Create a **single source of truth** for bootstrap module definitions.
Possible options:

1. store the bootstrap module list in a small data file
2. move the bootstrap module list into a shared helper that both entry logic and module logic can consume
3. reduce root-script dependency handling so only one implementation remains

### Expected benefit

- less duplication
- lower drift risk
- easier dependency changes

## 3. Consolidate duplicated helper functions where it is practical

### Current situation

Some helpers exist in more than one place:

- `Invoke-GitCommand` exists in both [install.ps1](../install.ps1) and [bootstrap.ps1](../bootstrap.ps1)
- `Get-PwshExecutablePath` exists in [install.ps1](../install.ps1) and [PSModule/ClientBootstrap/Private/BootstrapWingetDsc.ps1](../PSModule/ClientBootstrap/Private/BootstrapWingetDsc.ps1)
- repository URL and checkout path constants are duplicated in `install.ps1` and `bootstrap.ps1`

### Why this matters

Not all duplication is bad.
For a standalone public loader, some duplication is acceptable.
But right now the duplication exists because responsibilities are still overlapping.

### Recommendation

Do **not** over-abstract the public loader.
Instead:

- first simplify the contract between `install.ps1` and `bootstrap.ps1`
- then remove only the duplication that remains meaningful

Practical target:

- keep standalone helper logic in `install.ps1`
- move internal shared runtime helpers into the module only
- remove repo checkout helpers from `bootstrap.ps1`

### Expected benefit

- fewer parallel implementations
- easier refactoring later
- lower bug-fix duplication

## 4. `Configurations` are modeled but not actually applied

### Current situation

The repo already merges `Configurations` entries in [PSModule/ClientBootstrap/Private/Configuration.ps1](../PSModule/ClientBootstrap/Private/Configuration.ps1), but the runtime path does not actually apply them in `Report` or `Enforce`.

The docs currently speak about configuration synchronization and application configuration, but the implementation is still centered on:

- applications
- folders
- PowerShell repositories/modules
- PowerShell profile
- Oh My Posh

### Why this matters

This is a design/implementation mismatch.
The repo structure suggests broader configuration support than what is currently implemented.

### Recommendation

Choose one of these directions soon:

1. implement `Configurations` properly in `Report` and `Enforce`
2. or clearly narrow the docs until that feature exists

### Expected benefit

- more honest scope
- fewer false expectations
- cleaner v1 boundary

## 5. Separate config validation from machine-state validation

### Current situation

`Test-ConfigurationState()` in [PSModule/ClientBootstrap/Private/Configuration.ps1](../PSModule/ClientBootstrap/Private/Configuration.ps1) mixes two kinds of checks:

- static definition validation
- runtime environment checks against the current machine

Examples:

- checking required properties for application definitions
- checking whether a PowerShell repository already exists locally

### Why this matters

This makes validation harder to reason about.
A configuration can be structurally valid but still fail because the current machine state is different.

### Recommendation

Split validation into two phases:

- `Test-ConfigurationDefinition` for static config/schema validation
- `Test-EnvironmentReadiness` for machine-specific checks

### Expected benefit

- clearer failure messages
- easier testability
- better long-term schema validation support

## 6. Reduce repeated merge logic for apps, repositories, and modules

### Current situation

These functions are structurally very similar:

- `Resolve-Applications()`
- `Resolve-PowerShellRepositories()`
- `Resolve-PowerShellModules()`

### Why this matters

This kind of repeated merge logic tends to drift.
A later improvement to one resolver may not be copied to the others.

### Recommendation

Introduce a small generic merge helper for:

- grouping by key
- deduplication by serialized value
- conflict detection

Then keep only the domain-specific rules in thin wrappers.

### Expected benefit

- less repeated logic
- easier maintenance
- lower risk of inconsistent conflict behavior

## 7. Move runtime logs outside the repository checkout

### Current situation

Logs are currently written into the repository under `Logs/`.
They are ignored by Git, which is good, but they still live inside the checkout.

### Why this matters

Runtime output inside a cloned repo is usually less clean than storing it under a runtime directory.
It also makes repo folders noisier for users.

### Recommendation

Consider moving logs to something like:

- `%LOCALAPPDATA%\CWA-PS-Bootstrap\Logs`

and keep the repository itself mostly declarative and code-focused.

### Expected benefit

- cleaner checkout
- cleaner separation between source and runtime artifacts
- simpler public-repo hygiene

## 8. Improve PowerShell profile and Oh My Posh adoption strategy

### Current situation

The current bootstrap implementation fully rewrites the default PowerShell profile target in [PSModule/ClientBootstrap/Private/Operations.ps1](../PSModule/ClientBootstrap/Private/Operations.ps1).

That is fine for a clean demo, but it is too destructive for taking over an existing personal profile.

The currently used personal profile shows that real-world profile state usually contains a mix of:

- environment setup such as additional `PSModulePath` entries
- host-specific prompt initialization for VS Code vs Windows Terminal vs fallback shell
- optional module imports such as `Terminal-Icons`
- `PSReadLine` behavior
- helper functions and aliases
- startup banner/output

### Why this matters

If bootstrap owns the complete profile file, user-specific customizations will be overwritten.

That is especially risky for:

- custom functions
- personal aliases
- local paths outside the repository
- host-specific Oh My Posh behavior

### Recommendation

Do not let bootstrap permanently own the full user profile file.
Instead, move to a layered model with clear ownership.

Recommended target model:

1. **user-owned profile file**
2. **bootstrap-managed generated include**
3. **optional user local overlay include**

Example direction:

- the normal PowerShell profile remains user-owned
- bootstrap ensures it contains a small stable include snippet
- bootstrap writes its generated content into a separate managed file
- user-specific custom functions remain in a local overlay file that bootstrap never rewrites

Conceptually:

- `Microsoft.PowerShell_profile.ps1` = minimal entry file
- generated bootstrap include = managed by repository
- personal include = unmanaged and local

This is much safer than replacing the entire profile content on every `Enforce` run.

### How the current personal profile can be mapped

The observed profile content can be split into these buckets:

#### A. Repository-manageable session setup

These parts fit well into the repo-managed bootstrap profile:

- `Terminal-Icons` import
- `PSReadLine` settings
- startup fragments such as repo navigation helpers
- optional banner/output if desired

These should become profile fragments under `Config/Applications/PowerShell/`.

#### B. Environment-specific shell behavior

The current Oh My Posh setup selects different themes depending on shell context.
That is more advanced than the current single `OhMyPoshProfile` value in the repo.

Recommended extension:

- support host-aware prompt selection, for example `vscode`, `windowsTerminal`, `default`
- keep one fallback prompt profile
- keep the final initialization logic generated by bootstrap

In other words, the model should evolve from:

- one effective Oh My Posh profile

to:

- a small prompt policy with optional host-specific overrides

#### C. Machine-local or private personal logic

These parts should usually stay outside repo ownership:

- personal helper functions like DNS flush helpers
- tools that may not exist everywhere
- private paths in OneDrive or personal repo folders
- experimental aliases and shell utilities

These belong in a local overlay file, not in the shared bootstrap config.

### Concrete improvement for Oh My Posh handling

The current repo already generates one `oh-my-posh init` block in [PSModule/ClientBootstrap/Private/Operations.ps1](../PSModule/ClientBootstrap/Private/Operations.ps1).

To absorb the richer profile behavior cleanly, add a declarative prompt strategy such as:

- `OhMyPoshProfile`: default profile
- `OhMyPoshProfilesByHost`: optional map for host-specific overrides

Example host keys could be:

- `vscode`
- `windows-terminal`
- `default`

Then the generated profile can resolve the active host once and pick the correct theme without hardcoding personal logic into the main profile.

### Concrete improvement for PowerShell profile handling

The current generated profile path logic in [PSModule/ClientBootstrap/Private/Operations.ps1](../PSModule/ClientBootstrap/Private/Operations.ps1) should evolve in one of these safe ways:

1. manage only a generated include file under `%LOCALAPPDATA%\CWA-PS-Bootstrap\Generated\` and add a one-time include snippet to the main profile
2. or manage only a clearly marked begin/end block inside the main profile

Option 1 is cleaner and safer.

### Additional recommendation: model module-path extensions explicitly

The personal profile currently appends a shared path to `PSModulePath`.
That type of behavior should not stay as ad-hoc script code.

If this is a real requirement, add an explicit configuration concept such as:

- `PowerShellModulePaths`

Then bootstrap can:

- ensure the directories exist if desired
- extend session-local module discovery deterministically
- avoid repeatedly mutating persisted environment state without control

### Expected benefit

- existing personal profiles can be adopted without destructive overwrite
- Oh My Posh handling becomes expressive enough for real shell contexts
- repository-managed and personal shell logic are cleanly separated
- future profile growth stays maintainable

## 9. Improve documentation consistency now that the repo is public

### Current situation

The repository recently shifted from a private-repo assumption to a public-repo entry model.
Most docs are now aligned, but this transition should be fully normalized.

### Recommendation

Standardize all examples on:

- `install.ps1` as the public entrypoint
- `bootstrap.ps1` as the local repo entrypoint
- one consistent client profile example and casing

Also keep public-facing docs explicit that this is a showcase repository and not yet a production-hardened bootstrap framework.

### Expected benefit

- less confusion for new readers
- better onboarding
- fewer contradictory examples

## 10. Add lightweight automated validation for a public showcase repo

### Current situation

The repo works manually, but there is no visible automated safety net for:

- JSON validity
- basic bootstrap path regression
- module import regression

### Recommendation

Add lightweight automation such as:

- Pester smoke tests for module import and config resolution
- a simple CI workflow for PowerShell syntax and JSON validation
- maybe one end-to-end `Report` smoke test against sample config

### Expected benefit

- safer refactoring
- better public-repo credibility
- easier contribution and experimentation

## Suggested priority order

### High priority

1. make `install.ps1` the only public entrypoint
2. simplify `bootstrap.ps1` into a local-only bootstrap script
3. remove duplicate bootstrap dependency declarations
4. change profile handling from full overwrite to layered ownership
5. decide whether `Configurations` should be implemented now or documented as future scope

### Medium priority

6. add host-aware Oh My Posh selection and explicit profile overlay support
7. separate static config validation from machine-state validation
8. reduce repeated merge logic
9. move logs outside the repository checkout

### Lower priority

10. add CI and smoke tests
11. polish remaining documentation consistency and examples

## Overall verdict

The repository is **not badly structured**.
It already has a good architectural base and a sensible high-level split.

The main issue is not the module design itself.
The main issue is that the repository is still carrying **transition-state bootstrap logic** from the shift:

- from local-only use
- to public install loader
- to repo-local runtime bootstrap

So the right next step is **simplification**, not a rewrite.

The best concrete improvement is:

- make `install.ps1` the only public loader
- make `bootstrap.ps1` purely local
- centralize shared bootstrap dependency definitions
- stop overwriting the complete PowerShell profile and switch to a layered include model

That would remove most of the current conceptual redundancy without overengineering the project.
