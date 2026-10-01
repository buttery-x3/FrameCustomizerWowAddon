[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)][string]$AddOnsPath,
    [switch]$Update
)
$ErrorActionPreference = 'Stop'
$workspaceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceRoot = Join-Path $workspaceRoot 'FrameCustomizer'
$targetRoot = [IO.Path]::GetFullPath($AddOnsPath).TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) { throw 'AddOnsPath must name an existing AddOns directory.' }
if ((Split-Path -Leaf $targetRoot) -ne 'AddOns') { throw 'The explicit destination must be the client Interface\AddOns directory.' }
# Reject reparse points in every existing ancestor, not merely the final child.
function Assert-NoReparse([string]$Path) {
    $candidate = [IO.Path]::GetFullPath($Path)
    while ($candidate) {
        if (Test-Path -LiteralPath $candidate) {
            $item = Get-Item -LiteralPath $candidate -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing reparse-point path: $candidate" }
        }
        $parent = Split-Path -Parent $candidate
        if ($parent -eq $candidate) { break }
        $candidate = $parent
    }
}
Assert-NoReparse $sourceRoot
Assert-NoReparse $targetRoot
$destination = [IO.Path]::GetFullPath((Join-Path $targetRoot 'FrameCustomizer'))
if (-not $destination.StartsWith($targetRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Destination escaped AddOns directory.' }
Assert-NoReparse $destination
$tocPath = Join-Path $sourceRoot 'FrameCustomizer.toc'
$tocText = Get-Content -LiteralPath $tocPath -Raw
$files = @('FrameCustomizer.toc', 'LICENSE') + @(
    (Get-Content -LiteralPath $tocPath) | Where-Object { $_.Trim() -and -not $_.StartsWith('#') } | ForEach-Object { $_.Trim() }
)
$assetLine = [regex]::Match($tocText, '(?m)^## X-FrameCustomizer-Assets: (.+)\r?$')
if (-not $assetLine.Success) { throw 'Missing asset manifest.' }
$files += @($assetLine.Groups[1].Value.Trim() -split '\s+')
$existing = Test-Path -LiteralPath $destination
if ($existing) {
    if (-not $Update) { throw 'FrameCustomizer already exists. Use -Update to back it up and copy this version.' }
    $existingToc = Join-Path $destination 'FrameCustomizer.toc'
    if (-not (Test-Path -LiteralPath $existingToc -PathType Leaf)) { throw 'Existing folder is not a recognized FrameCustomizer installation.' }
    $existingText = Get-Content -LiteralPath $existingToc -Raw
    if ($existingText -notmatch '(?m)^## Title: FrameCustomizer\r?$' -or $existingText -notmatch '(?m)^## SavedVariables: FrameCustomizerDB(?:, FrameCustomizerSafeMode)?\r?$') {
        throw 'Refusing to overwrite an unrelated addon.'
    }
}
foreach ($relative in $files) {
    $sourceFile = [IO.Path]::GetFullPath((Join-Path $sourceRoot $relative))
    $destinationFile = [IO.Path]::GetFullPath((Join-Path $destination $relative))
    if (-not $sourceFile.StartsWith($sourceRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or -not $destinationFile.StartsWith($destination + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe manifest path.' }
    if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) { throw "Missing source: $relative" }
    Assert-NoReparse $sourceFile
    Assert-NoReparse $destinationFile
}
if ($PSCmdlet.ShouldProcess($destination, 'Deploy FrameCustomizer files (preserving all other addons and settings)')) {
    if ($existing) {
        # Copy a recoverable backup; never delete or move the installed addon.
        $backupRoot = Join-Path $workspaceRoot ('dist\deploy-backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        Get-ChildItem -LiteralPath $destination -Recurse -Force | ForEach-Object { Assert-NoReparse $_.FullName }
        Copy-Item -LiteralPath $destination -Destination $backupRoot -Recurse
        Write-Output "Backup: $backupRoot\FrameCustomizer"
    }
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach ($relative in $files) {
        $destinationFile = Join-Path $destination $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $destinationFile) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $sourceRoot $relative) -Destination $destinationFile -Force
    }
    Write-Output "Deployed $($files.Count) files to $destination"
    Write-Output 'Existing extra files are preserved. No other addon or account settings were changed.'
}

