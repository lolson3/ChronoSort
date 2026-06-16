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
.\chronosort.ps1 <SourceDirectory> [Options]
```

### Parameters

- **SourceDirectory**: Path to the source directory to organize (can specify multiple)
- **-OutputSuffix**: Custom suffix for output directory (default: `_organized`)
- **-Rebuild**: Deletes the organized directory completely and rebuilds it from scratch. Use when you want to start fresh or when the directory structure is corrupted.
- **-Validate**: Verifies that all files listed in the manifest exist in the organized directory. Removes entries for missing files. Use when files have been manually deleted from the organized directory.

### Examples

```powershell
# Organize a single directory
.\chronosort.ps1 C:\Users\Leif\Documents\SourceFiles

# Organize multiple directories
.\chronosort.ps1 C:\Data\Archive C:\Data\Downloads

# Rebuild the directory from scratch
.\chronosort.ps1 C:\Users\Leif\Documents\SourceFiles -Rebuild

# Verify manifest integrity and remove missing file entries
.\chronosort.ps1 C:\Users\Leif\Documents\SourceFiles -Validate
```

## Output

For a source directory named `Photos`, the script will create a sibling directory named `Photos_organized` and populate it like:

- `Photos_organized\2025\March\...`
- `Photos_organized\2026\January\...`

The manifest file is stored at:

- `Photos_organized\manifest.csv`

## Notes

- Files are only copied when they contain a recognized date pattern.
- The script avoids reprocessing files already listed in the manifest unless `-Rebuild` is used.
- Use `-Validate` to detect and remove manifest entries for files that have been deleted or failed to copy. This ensures the manifest stays in sync with the actual organized directory.
- Use `-Rebuild` to delete and recreate the organized directory from scratch. This reprocesses all source files and creates a new manifest.
- **Rebuild vs Validate**: Rebuild deletes the entire organized directory and rebuilds it from scratch; Validate only checks that organized files still exist and removes orphaned manifest entries.

## Task Scheduler

To run `chronosort.ps1` on a schedule via Windows Task Scheduler:

1. Open Task Scheduler and choose "Create Task...".
2. On the "General" tab give the task a name and optionally select "Run whether user is logged on".
3. On the "Triggers" tab add a trigger (daily, at log on, etc.).
4. On the "Actions" tab add a new action:
	 - **Program/script:** `powershell.exe`
	 - **Add arguments (example):**
		 -NoProfile -ExecutionPolicy Bypass -File "C:\\path\\to\\chronosort.ps1" "C:\\path\\to\\source" -Validate
	 - **Start in (optional):** `C:\path\to\script\folder`
5. Save the task. You can test it by right-clicking and selecting "Run".

Notes:
- Use full absolute paths in the action arguments.
- For a full rebuild, replace `-Validate` with `-Rebuild` in the arguments.
