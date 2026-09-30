$ErrorActionPreference = 'Stop'
$workspaceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$testRoot = Join-Path $workspaceRoot ('.tools\deployment-test-' + [Guid]::NewGuid().ToString('N'))
$addons = Join-Path $testRoot 'Interface\AddOns'
$other = Join-Path $addons 'OtherAddon'
$settings = Join-Path $testRoot 'WTF'
New-Item -ItemType Directory -Path $other,$settings -Force | Out-Null
Set-Content -LiteralPath (Join-Path $other 'sentinel.txt') -Value 'untouched addon'
Set-Content -LiteralPath (Join-Path $settings 'sentinel.txt') -Value 'untouched settings'
$beforeAddon = (Get-FileHash -LiteralPath (Join-Path $other 'sentinel.txt')).Hash
$beforeSettings = (Get-FileHash -LiteralPath (Join-Path $settings 'sentinel.txt')).Hash
& (Join-Path $PSScriptRoot 'deploy.ps1') -AddOnsPath $addons -WhatIf
if (Test-Path -LiteralPath (Join-Path $addons 'FrameCustomizer')) { throw 'WhatIf changed destination.' }
& (Join-Path $PSScriptRoot 'deploy.ps1') -AddOnsPath $addons
$refused = $false
try { & (Join-Path $PSScriptRoot 'deploy.ps1') -AddOnsPath $addons } catch { $refused = $true }
if (-not $refused) { throw 'Existing addon overwritten without explicit Update.' }
& (Join-Path $PSScriptRoot 'deploy.ps1') -AddOnsPath $addons -Update
if ((Get-FileHash -LiteralPath (Join-Path $other 'sentinel.txt')).Hash -ne $beforeAddon) { throw 'Other addon modified.' }
if ((Get-FileHash -LiteralPath (Join-Path $settings 'sentinel.txt')).Hash -ne $beforeSettings) { throw 'Settings modified.' }
$targetToc = Join-Path $addons 'FrameCustomizer\FrameCustomizer.toc'
Set-Content -LiteralPath $targetToc -Value '## Title: AnotherAddon'
$refused = $false
try { & (Join-Path $PSScriptRoot 'deploy.ps1') -AddOnsPath $addons -Update } catch { $refused = $true }
if (-not $refused -or (Get-Content -LiteralPath $targetToc -Raw).Trim() -ne '## Title: AnotherAddon') { throw 'Unrelated addon was not protected.' }
Write-Output 'DEPLOYMENT PASS: WhatIf, fresh install, refusal without Update, backup update, unrelated-addon rejection, sibling addon and WTF preservation.'
Write-Output "Fixture artifacts retained only under: $testRoot"

