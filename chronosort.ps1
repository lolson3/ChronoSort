<#
.SYNOPSIS
Organizes files by date into a sibling output directory and maintains a manifest log.

.DESCRIPTION
ChronoSort scans specified source folders for date patterns, copies matched files into an organized output tree by Year/Month, and logs processed files in a CSV manifest. Can validate manifest integrity and clean missing entries.

.PARAMETER SourceDirectories
One or more source directories to process. Defaults to the current directory.

.PARAMETER OutputSuffix
Suffix appended to each source directory name to create the output directory. Defaults to '_organized'.

.PARAMETER Rebuild
When specified, deletes the organized directory completely and rebuilds it from scratch with all source files.

.PARAMETER Validate
When specified, verifies that all files listed in the manifest exist in the organized directory. Removes entries for missing files and updates the manifest.

.EXAMPLE
.\chronosort.ps1 C:\Users\Leif\Documents\source

.EXAMPLE
.\chronosort.ps1 C:\Users\Leif\Documents\source -Validate

.EXAMPLE
.\chronosort.ps1 C:\Users\Leif\Documents\source -Rebuild
#>
param(
    [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
    [string[]]$SourceDirectories = @('.'),

    [string]$OutputSuffix = '_organized',
    [switch]$Rebuild,
    [switch]$Validate
)

$ErrorActionPreference = 'Stop'
$monthNames = @(
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
)

$patterns = @(
    [regex]'(?<year>\d{4})(?<month>0[1-9]|1[0-2])(?<day>0[1-9]|[12]\d|3[01])',
    [regex]'(?<year>\d{4})-(?<month>0[1-9]|1[0-2])-(?<day>0[1-9]|[12]\d|3[01])'
)

$monthNameMap = @{
    'january' = '01'; 'february' = '02'; 'march' = '03'; 'april' = '04';
    'may' = '05'; 'june' = '06'; 'july' = '07'; 'august' = '08';
    'september' = '09'; 'october' = '10'; 'november' = '11'; 'december' = '12'
}

function Get-DateFromText {
    param([string]$Text)

    foreach ($pattern in $patterns) {
        $match = $pattern.Match($Text)
        if ($match.Success) {
            return [pscustomobject]@{
                Year = $match.Groups['year'].Value
                Month = $match.Groups['month'].Value
                Day = $match.Groups['day'].Value
                Pattern = $pattern.ToString()
            }
        }
    }

    $match = $wrongMonthPattern.Match($Text)
    if ($match.Success) {
        $monthName = $match.Groups['month'].Value.Trim().ToLower()
        if ($monthNameMap.ContainsKey($monthName)) {
            return [pscustomobject]@{
                Year = $match.Groups['year'].Value
                Month = $monthNameMap[$monthName]
                Day = '01'
                Pattern = $wrongMonthPattern.ToString()
            }
        }
    }

    return $null
}

function Get-OrganizedOutputRoot {
    param([string]$SourceRoot)

    $baseName = Split-Path -Path $SourceRoot -Leaf
    if ($baseName.EndsWith($OutputSuffix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return Join-Path -Path (Split-Path -Path $SourceRoot -Parent) -ChildPath $baseName
    }

    return Join-Path -Path (Split-Path -Path $SourceRoot -Parent) -ChildPath ("$baseName$OutputSuffix")
}

function Get-DirectorySegments {
    param([string]$RelativePath)
    return ($RelativePath -split '[\\/]') | Where-Object { $_ -ne '' }
}

function Detect-IncorrectSort {
    param([string]$RelativePath)

    $segments = Get-DirectorySegments -RelativePath $RelativePath
    for ($index = 0; $index -lt $segments.Count - 1; $index++) {
        if ($segments[$index] -match '^[0-9]{4}$') {
            $nextSegment = $segments[$index + 1]
            if ($nextSegment -match '^(?<month>[A-Za-z]+)\s+(?<year>[0-9]{4})$' -and $matches['year'] -eq $segments[$index]) {
                return $true
            }
        }
    }

    return $false
}

function Get-UniqueDestinationFile {
    param(
        [string]$DestinationDirectory,
        [string]$FileName
    )

    $candidatePath = Join-Path -Path $DestinationDirectory -ChildPath $FileName
    if (-not (Test-Path -Path $candidatePath)) {
        return $candidatePath
    }

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $extension = [System.IO.Path]::GetExtension($FileName)
    $counter = 1

    while ($true) {
        $candidate = "{0} ({1}){2}" -f $baseName, $counter, $extension
        $candidatePath = Join-Path -Path $DestinationDirectory -ChildPath $candidate
        if (-not (Test-Path -Path $candidatePath)) {
            return $candidatePath
        }
        $counter++
    }
}

function Validate-Manifest {
    param(
        [string]$ManifestPath,
        [object[]]$ManifestEntries
    )

    if (-not (Test-Path -Path $ManifestPath)) {
        return @{
            ValidEntries = $ManifestEntries
            ValidCount = $ManifestEntries.Count
            RemovedCount = 0
        }
    }

    $validEntries = @()
    $removedCount = 0

    foreach ($entry in $ManifestEntries) {
        if (Test-Path -Path $entry.OutputFullPath) {
            $validEntries += $entry
        }
        else {
            $removedCount++
            Write-Warning "Manifest entry points to missing file: $($entry.OutputFullPath)"
        }
    }

    if ($removedCount -gt 0) {
        if ($validEntries.Count -gt 0) {
            $validEntries | Export-Csv -Path $ManifestPath -NoTypeInformation
        }
        else {
            @() | Export-Csv -Path $ManifestPath -NoTypeInformation
        }
    }

    return @{
        ValidEntries = $validEntries
        ValidCount = $validEntries.Count
        RemovedCount = $removedCount
    }
}

foreach ($sourceDirectory in $SourceDirectories) {
    if ([string]::IsNullOrWhiteSpace($sourceDirectory)) {
        continue
    }

    $resolvedSource = Resolve-Path -Path $sourceDirectory -ErrorAction SilentlyContinue
    if (-not $resolvedSource) {
        Write-Warning "Source directory '$sourceDirectory' does not exist. Skipping."
        continue
    }

    $sourceRoot = $resolvedSource.ProviderPath
    if (-not (Test-Path -Path $sourceRoot -PathType Container)) {
        Write-Warning "Source path '$sourceRoot' is not a directory. Skipping."
        continue
    }

    Write-Host "Processing source directory: $sourceRoot"
    $outputRoot = Get-OrganizedOutputRoot -SourceRoot $sourceRoot
    if (-not (Test-Path -Path $outputRoot)) {
        New-Item -Path $outputRoot -ItemType Directory | Out-Null
    }

    $manifestPath = Join-Path -Path $outputRoot -ChildPath 'manifest.csv'
    $existingManifest = @{}
    $manifestEntries = @()
    $filesScanned = 0
    $filesAlreadyOrganized = 0
    $filesNewlyOrganized = 0
    $validateManifestValidCount = 0
    $validateManifestRemovedCount = 0

    # If Rebuild is specified, delete the entire organized directory and start fresh
    if ($Rebuild) {
        if (Test-Path -Path $outputRoot) {
            Write-Host "Removing existing organized directory: $outputRoot"
            Remove-Item -Path $outputRoot -Recurse -Force
        }
        New-Item -Path $outputRoot -ItemType Directory | Out-Null
    }

    if ((Test-Path -Path $manifestPath) -and (-not $Rebuild)) {
        $existingEntries = Import-Csv -Path $manifestPath -ErrorAction SilentlyContinue
        foreach ($entry in $existingEntries) {
            if ($entry.SourceRelativePath) {
                $existingManifest[$entry.SourceRelativePath] = $true
            }
        }
        $manifestEntries = @($existingEntries)
        
        if ($Validate) {
            $validationResult = Validate-Manifest -ManifestPath $manifestPath -ManifestEntries $manifestEntries
            $manifestEntries = $validationResult.ValidEntries
            $validateManifestValidCount = $validationResult.ValidCount
            $validateManifestRemovedCount = $validationResult.RemovedCount
        }
    }

    # Only scan source files if not in Validate-only mode
    if (-not $Validate) {
        $files = Get-ChildItem -Path $sourceRoot -File -Recurse
        foreach ($file in $files) {
            $filesScanned++
            $relativePath = $file.FullName.Substring($sourceRoot.Length).TrimStart('\','/')
            if ($existingManifest.ContainsKey($relativePath)) {
                $filesAlreadyOrganized++
                continue
            }

            $dateMetadata = Get-DateFromText -Text $relativePath
            if (-not $dateMetadata) {
                Write-Verbose "Skipping file without recognized date pattern: $relativePath"
                continue
            }
            $filesNewlyOrganized++

            $incorrectSort = Detect-IncorrectSort -RelativePath (Split-Path -Path $relativePath -Parent)
            $year = $dateMetadata.Year
            $monthNumber = $dateMetadata.Month
            $monthIndex = [int]$monthNumber - 1
            if ($monthIndex -lt 0 -or $monthIndex -ge $monthNames.Count) {
                Write-Warning "Parsed month '$monthNumber' for file '$relativePath' is invalid. Skipping."
                continue
            }

            $monthName = $monthNames[$monthIndex]
            $destinationDirectory = Join-Path -Path $outputRoot -ChildPath $year
            $destinationDirectory = Join-Path -Path $destinationDirectory -ChildPath "$monthNumber $monthName"
            if (-not (Test-Path -Path $destinationDirectory)) {
                New-Item -Path $destinationDirectory -ItemType Directory -Force | Out-Null
            }

            $destinationFile = Get-UniqueDestinationFile -DestinationDirectory $destinationDirectory -FileName $file.Name
            Copy-Item -Path $file.FullName -Destination $destinationFile

            $notes = @('Organized')
            if ($incorrectSort) {
                $notes += 'DetectedIncorrectSort'
            }

            $manifestEntries += [pscustomobject]@{
                SourceFullPath     = $file.FullName
                SourceRelativePath = $relativePath
                OutputFullPath     = $destinationFile
                Year               = $year
                Month              = $monthNumber
                Day                = $dateMetadata.Day
                PatternMatched     = $dateMetadata.Pattern
                Notes              = ($notes -join ';')
                ProcessedUtc       = (Get-Date).ToUniversalTime().ToString('o')
            }
            $existingManifest[$relativePath] = $true
        }
    }

    # Output messages based on mode
    if ($Validate) {
        $totalValidated = $validateManifestValidCount + $validateManifestRemovedCount
        Write-Host "Validated $totalValidated manifest entry(ies). $validateManifestValidCount file(s) exist - $validateManifestRemovedCount file(s) removed."
    }
    else {
        Write-Host "Scanned $filesScanned file(s)."
        
        if ($filesNewlyOrganized -gt 0) {
            $manifestEntries | Sort-Object SourceRelativePath | Export-Csv -Path $manifestPath -NoTypeInformation
            Write-Host "Updated manifest at: $manifestPath"
            if ($Rebuild) {
                Write-Host "Rebuilt directory with $filesNewlyOrganized file(s)."
            }
            else {
                Write-Host "Organized $filesNewlyOrganized new file(s). $filesAlreadyOrganized file(s) already organized."
            }
        }
        elseif ($filesAlreadyOrganized -gt 0) {
            Write-Host "All $filesScanned file(s) scanned - all files already organized."
        }
        else {
            Write-Host "No files with recognized date patterns found."
            if (-not (Test-Path -Path $manifestPath)) {
                @() | Export-Csv -Path $manifestPath -NoTypeInformation
            }
        }
    }
}