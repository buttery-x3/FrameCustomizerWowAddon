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
$blankSource = Join-Path $workspaceRoot 'FrameCustomizer\Media\Transparent.tga'
$blankTarget = Join-Path $addons 'FrameCustomizer\Media\Transparent.tga'
if ((Get-FileHash -LiteralPath $blankSource).Hash -ne (Get-FileHash -LiteralPath $blankTarget).Hash) { throw 'Transparent texture missing or changed during deployment.' }
if ((Get-FileHash -LiteralPath (Join-Path $other 'sentinel.txt')).Hash -ne $beforeAddon) { throw 'Other addon modified.' }
if ((Get-FileHash -LiteralPath (Join-Path $settings 'sentinel.txt')).Hash -ne $beforeSettings) { throw 'Settings modified.' }
$targetToc = Join-Path $addons 'FrameCustomizer\FrameCustomizer.toc'
Set-Content -LiteralPath $targetToc -Value '## Title: AnotherAddon'
$refused = $false
try { & (Join-Path $PSScriptRoot 'deploy.ps1') -AddOnsPath $addons -Update } catch { $refused = $true }
if (-not $refused -or (Get-Content -LiteralPath $targetToc -Raw).Trim() -ne '## Title: AnotherAddon') { throw 'Unrelated addon was not protected.' }

# Exercise default configuration in an isolated repository, never the user's
# real .env or game installation. Include spaces, #, brackets and literal $().
$fixtureRepo = Join-Path $testRoot 'repository'
$fixtureScripts = Join-Path $fixtureRepo 'scripts'
New-Item -ItemType Directory -Path $fixtureScripts -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $workspaceRoot 'FrameCustomizer') -Destination $fixtureRepo -Recurse
$fixtureDeploy = Join-Path $fixtureScripts 'deploy.ps1'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'deploy.ps1') -Destination $fixtureDeploy
$fixtureConfig = Join-Path $fixtureRepo '.env'
$configuredAddons = Join-Path $testRoot 'configured client [a] #1 $(unexpanded)\Interface\AddOns'
New-Item -ItemType Directory -Path $configuredAddons -Force | Out-Null
$configuredDestination = Join-Path $configuredAddons 'FrameCustomizer'
function Assert-ConfigRejected([string]$Expected) {
    $rejected = $false
    try { & $fixtureDeploy -WhatIf } catch {
        if (-not $_.Exception.Message.Contains($Expected)) { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw "Expected configuration rejection: $Expected" }
}
Assert-ConfigRejected 'Set FRAMECUSTOMIZER_ADDONS_PATH'
Set-Content -LiteralPath $fixtureConfig -Encoding UTF8 -Value 'FRAMECUSTOMIZER_ADDONS_PATH='
Assert-ConfigRejected 'Set FRAMECUSTOMIZER_ADDONS_PATH'
Set-Content -LiteralPath $fixtureConfig -Encoding UTF8 -Value @(
    '# Comments and unrelated settings are not executed or imported.'
    'UNRELATED=$(throw "Config must never execute")'
    ('  FRAMECUSTOMIZER_ADDONS_PATH = "' + $configuredAddons + '"  ')
)
$configBefore = (Get-FileHash -LiteralPath $fixtureConfig).Hash
Push-Location $testRoot
try {
    & $fixtureDeploy -WhatIf
    if (Test-Path -LiteralPath $configuredDestination) { throw 'Configured WhatIf changed destination.' }
    & $fixtureDeploy
    Assert-ConfigRejected 'already exists'
    & $fixtureDeploy -Update
} finally { Pop-Location }
if ((Get-FileHash -LiteralPath $fixtureConfig).Hash -ne $configBefore) { throw 'Deployment modified .env.' }
if ((Get-FileHash -LiteralPath (Join-Path $configuredDestination 'Media\Transparent.tga')).Hash -ne (Get-FileHash -LiteralPath $blankSource).Hash) { throw 'Configured deployment changed the texture.' }
if (@(Get-ChildItem -LiteralPath (Join-Path $fixtureRepo 'dist\deploy-backups') -Directory).Count -ne 1) { throw 'Configured update did not create exactly one backup.' }

# All supported quoting forms preserve literal path characters.
foreach ($value in @($configuredAddons, ("'" + $configuredAddons + "'"))) {
    Set-Content -LiteralPath $fixtureConfig -Encoding UTF8 -Value ('FRAMECUSTOMIZER_ADDONS_PATH=' + $value)
    & $fixtureDeploy -Update -WhatIf
}
Set-Content -LiteralPath $fixtureConfig -Encoding UTF8 -Value 'FRAMECUSTOMIZER_ADDONS_PATH="unfinished'
Assert-ConfigRejected 'Unmatched quotes'
# An explicit destination skips even a malformed default config.
& $fixtureDeploy -AddOnsPath $configuredAddons -Update -WhatIf
$emptyRejected = $false
try { & $fixtureDeploy -AddOnsPath '' -WhatIf } catch { $emptyRejected = $true }
if (-not $emptyRejected) { throw 'Explicit empty path silently used a default.' }
Set-Content -LiteralPath $fixtureConfig -Encoding UTF8 -Value @('FRAMECUSTOMIZER_ADDONS_PATH=one', 'FRAMECUSTOMIZER_ADDONS_PATH=two')
Assert-ConfigRejected 'Duplicate FRAMECUSTOMIZER_ADDONS_PATH'
Set-Content -LiteralPath $fixtureConfig -Encoding UTF8 -Value ('FRAMECUSTOMIZER_ADDONS_PATH=' + $fixtureRepo)
Assert-ConfigRejected 'Interface\AddOns'
Set-Content -LiteralPath $fixtureConfig -Encoding UTF8 -Value ('FRAMECUSTOMIZER_ADDONS_PATH=' + (Join-Path $testRoot 'missing\AddOns'))
Assert-ConfigRejected 'existing AddOns directory'
# Relative configured paths are relative to the repository, not the caller.
New-Item -ItemType Directory -Path (Join-Path $fixtureRepo 'client\Interface\AddOns') -Force | Out-Null
Set-Content -LiteralPath $fixtureConfig -Encoding UTF8 -Value 'FRAMECUSTOMIZER_ADDONS_PATH=client/Interface/AddOns'
Push-Location $testRoot
try { & $fixtureDeploy -WhatIf } finally { Pop-Location }
Set-Content -LiteralPath (Join-Path $configuredDestination 'FrameCustomizer.toc') -Value '## Title: AnotherAddon'
Set-Content -LiteralPath $fixtureConfig -Encoding UTF8 -Value ('FRAMECUSTOMIZER_ADDONS_PATH=' + $configuredAddons)
$refused = $false
try { & $fixtureDeploy -Update } catch { $refused = $_.Exception.Message.Contains('unrelated addon') }
if (-not $refused) { throw 'Configured destination allowed an unrelated addon overwrite.' }
Write-Output 'DEPLOYMENT PASS: WhatIf, fresh install, refusal without Update, backup update, unrelated-addon rejection, sibling addon and WTF preservation.'
Write-Output 'CONFIG PASS: .env default, literal quoted/unquoted paths, working-directory independence, explicit override, missing/empty/malformed/duplicate/invalid destinations, existing-install protections; user config untouched.'
Write-Output "Fixture artifacts retained only under: $testRoot"

