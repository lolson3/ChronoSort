# ChronoSort

ChronoSort is a PowerShell script that scans specified source directories for files whose names or paths contain date patterns, then copies those files into a new organized output tree grouped by `Year/Month`.

## Behavior

- Operates on one or more source directories.
- Leaves source files untouched.
- Creates a sibling output directory named `<SourceDirectory>_organized`.
- Copies matched files into `Year/Month` folders under the output directory.
- Maintains a `manifest.csv` log in the output directory.
- Detects incorrect sort patterns such as `2025/October 2025`.

## Usage

Run the script from PowerShell:

```powershell
.
\chronosort.ps1 <SourceDirectory>
```

Examples:

```powershell
# Organize a single directory
.
\chronosort.ps1 C:\Users\Leif\Documents\SourceFiles

# Organize multiple directories
.
\chronosort.ps1 C:\Data\Archive C:\Data\Downloads

# Rebuild the manifest and reprocess all matching files
.
\chronosort.ps1 C:\Users\Leif\Documents\SourceFiles -RebuildManifest
```

## Output

For a source directory named `Photos`, the script will create a sibling directory named `Photos_organized` and populate it like:

- `Photos_organized\2025\March\...`
- `Photos_organized\2026\January\...`

The manifest file is stored at:

- `Photos_organized\manifest.csv`

## Notes

- Files are only copied when they contain a recognized date pattern.
- The script avoids reprocessing files already listed in the manifest unless `-RebuildManifest` is used.
