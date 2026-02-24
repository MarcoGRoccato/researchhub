# ResearchHub

Public Quarto website + source repository for research notes/projects.

## Current setup (Windows-first)

- **Git repo (source + website):** `C:\ResearchHub`
- **GitHub repo:** `https://github.com/MarcoGRoccato/researchhub.git`
- **GitHub Pages publish source:** `main` branch, `/docs` folder
- **Local data storage (NOT in Git):** `F:\ResearchHub_Data`

### Data folders linked into repo via Windows junctions
Inside `C:\ResearchHub`, these names exist as **junctions** pointing to `F:\ResearchHub_Data\...`:

- `raw_data` -> `F:\ResearchHub_Data\raw_data`
- `processed_data` -> `F:\ResearchHub_Data\processed_data`
- `outputs` -> `F:\ResearchHub_Data\outputs`
- `temp` -> `F:\ResearchHub_Data\temp`

This allows analysis scripts to use simple local paths while keeping data out of GitHub.

---

## Safety rules (important)

### 1) Do not store research data in Git
The repo is intentionally configured to block common data files and data-like folders.

Protected by:

- **strict `.gitignore`**
- **pre-commit data guard** (`.githooks/pre-commit-data-guard.ps1`)
- local Git hook wrapper in `.git/hooks/pre-commit`

Examples of blocked file types include:

- tabular/spreadsheets: `csv`, `tsv`, `xls`, `xlsx`, `xlsm`, `xlsb`, `xltx`, `xltm`, `xlam`, `ods`
- databases: `sqlite`, `db`, etc.
- EEG/biosignal: `fif`, `eeg`, `vhdr`, `vmrk`, `edf`, `bdf`, `set`, `fdt`, `xdf`, etc.
- archives: `zip`, `7z`, `rar`, `tar`, `gz`, etc.

### 2) Website files in `docs/` are allowed
The `docs/` folder is the GitHub Pages output and is intentionally tracked.

### 3) Password gate is only a flimsy gate
The index page password gate is **not real security**. It is just a UI barrier for casual browsing.

Do **not** rely on it for sensitive information.

### 4) Never overwrite data files
When saving outputs/data, prefer versioned filenames (e.g., dates or `_v2`, `_v3`) instead of overwriting.

---

## Rendering the site (Quarto)

Use the repo-managed render script:

- Script path: `shared/scripts/render_site.ps1`

What it does:

- renders from the **current repo root**
- cleans `.quarto/` and `docs/` (unless `-NoClean`)
- runs Quarto render
- injects a **Europe/Rome timestamp footer** into `docs/index.html`

### Standard render command (Windows PowerShell)

```powershell
cd C:\ResearchHub
powershell -ExecutionPolicy Bypass -File .\shared\scripts\render_site.ps1