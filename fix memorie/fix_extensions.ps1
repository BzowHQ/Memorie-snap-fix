[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RootPath {
    param([string]$InputPath)

    if (-not $InputPath) {
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = "Select the folder that contains your files"
            $dialog.ShowNewFolderButton = $false
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $InputPath = $dialog.SelectedPath
            }
        } catch {
            Write-Host "Folder picker unavailable, paste the folder path instead."
            $InputPath = Read-Host "Folder path"
        }
    }

    if (-not $InputPath) {
        throw "No folder chosen."
    }

    if (-not (Test-Path -LiteralPath $InputPath -PathType Container)) {
        throw "Folder not found: $InputPath"
    }

    return (Resolve-Path -LiteralPath $InputPath).Path
}

function Get-FileExtensionFromSignature {
    param([byte[]]$Bytes)

    if (-not $Bytes -or $Bytes.Length -lt 8) {
        return $null
    }

    switch ($true) {
        { $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xD8 -and $Bytes[2] -eq 0xFF } { return ".jpg" }
        { $Bytes[0] -eq 0x89 -and $Bytes[1] -eq 0x50 -and $Bytes[2] -eq 0x4E -and $Bytes[3] -eq 0x47 } { return ".png" }
        { $Bytes[0] -eq 0x47 -and $Bytes[1] -eq 0x49 -and $Bytes[2] -eq 0x46 } { return ".gif" }
        { $Bytes[4] -eq 0x66 -and $Bytes[5] -eq 0x74 -and $Bytes[6] -eq 0x79 -and $Bytes[7] -eq 0x70 } { return ".mp4" }
        { $Bytes[0] -eq 0x00 -and $Bytes[1] -eq 0x00 -and $Bytes[2] -eq 0x00 -and $Bytes[3] -eq 0x18 } { return ".mp4" }
        default { return $null }
    }
}

function Expand-ZipFiles {
    param(
        [string]$Root,
        [int]$StepNumber,
        [int]$TotalSteps
    )

    $zips = Get-ChildItem -Path $Root -File -Filter *.zip -ErrorAction SilentlyContinue
    if (-not $zips) {
        Write-Host ("[{0}/{1}] No zip files to extract." -f $StepNumber, $TotalSteps)
        return
    }

    Write-Host ("[{0}/{1}] Extracting zip files..." -f $StepNumber, $TotalSteps)
    foreach ($zip in $zips) {
        $tempFolder = Join-Path $Root ("_unzipped_" + [guid]::NewGuid().ToString("N"))
        Write-Host (" - {0}" -f $zip.Name)

        try {
            Expand-Archive -Path $zip.FullName -DestinationPath $tempFolder -Force
            Get-ChildItem -Path $tempFolder -Recurse -File | Move-Item -Destination $Root -Force
        } catch {
            Write-Warning ("   Failed to extract {0}: {1}" -f $zip.Name, $_.Exception.Message)
        } finally {
            if (Test-Path -LiteralPath $tempFolder) {
                Remove-Item -LiteralPath $tempFolder -Recurse -Force
            }
        }

        Remove-Item -LiteralPath $zip.FullName -Force
    }
}

function Fix-FileExtensions {
    param(
        [string]$Root,
        [int]$StepNumber,
        [int]$TotalSteps
    )

    $files = Get-ChildItem -Path $Root -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ne ".zip" }
    if (-not $files) {
        Write-Host ("[{0}/{1}] No files found to rename." -f $StepNumber, $TotalSteps)
        return
    }

    Write-Host ("[{0}/{1}] Checking file signatures..." -f $StepNumber, $TotalSteps)
    foreach ($file in $files) {
        $bytes = Get-Content -LiteralPath $file.FullName -Encoding Byte -TotalCount 64 -ErrorAction SilentlyContinue
        $targetExt = Get-FileExtensionFromSignature -Bytes $bytes

        if (-not $targetExt) {
            if (-not $file.Extension) {
                Write-Host (" - Unknown type, skipped: {0}" -f $file.Name)
            }
            continue
        }

        if ([string]::Equals($file.Extension, $targetExt, [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $baseName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        $newName = $baseName + $targetExt
        $newPath = Join-Path $file.DirectoryName $newName

        if (Test-Path -LiteralPath $newPath) {
            $newName = "{0}_{1}{2}" -f $baseName, (Get-Random -Minimum 1000 -Maximum 9999), $targetExt
            $newPath = Join-Path $file.DirectoryName $newName
        }

        Write-Host (" - Renaming {0} -> {1}" -f $file.Name, $newName)
        Move-Item -LiteralPath $file.FullName -Destination $newPath -Force
    }
}

try {
    $rootPath = Resolve-RootPath -InputPath $Path
    Write-Host "`nTarget folder:`n  $rootPath`n"

    $totalSteps = 2

    Expand-ZipFiles -Root $rootPath -StepNumber 1 -TotalSteps $totalSteps
    Fix-FileExtensions -Root $rootPath -StepNumber 2 -TotalSteps $totalSteps

    Write-Host "`nDone."
} catch {
    Write-Error $_
    exit 1
}
