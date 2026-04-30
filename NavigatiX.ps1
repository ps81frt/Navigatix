& {

function Show-Banner {
    Clear-Host
$banner = @'
███╗   ██╗ █████╗ ██╗   ██╗██╗ ██████╗  █████╗ ████████╗██╗██╗  ██╗
████╗  ██║██╔══██╗██║   ██║██║██╔════╝ ██╔══██╗╚══██╔══╝██║╚██╗██╔╝
██╔██╗ ██║███████║██║   ██║██║██║  ███╗███████║   ██║   ██║ ╚███╔╝ 
██║╚██╗██║██╔══██║╚██╗ ██╔╝██║██║   ██║██╔══██║   ██║   ██║ ██╔██╗ 
██║ ╚████║██║  ██║ ╚████╔╝ ██║╚██████╔╝██║  ██║   ██║   ██║██╔╝ ██╗
╚═╝  ╚═══╝╚═╝  ╚═╝  ╚═══╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝╚═╝  ╚═╝
                                                 
'@
    Write-Host $banner -ForegroundColor Cyan
    $title = "Sauvegarde / Restaure Navigateurs & Thunderbird"
    $bannerWidth = ($banner -split "`n" | Measure-Object -Property Length -Maximum).Maximum
    $pad = [math]::Max(0, ($bannerWidth - $title.Length) / 2)
    Write-Host (" " * [int]$pad + $title) -ForegroundColor Yellow
    Write-Host ""
}

function Get-SupportedApps {
    return @(
        @{ Name="Thunderbird"; Process="thunderbird"; Profile="$env:APPDATA\Thunderbird";                        RegKey="HKLM:\SOFTWARE\Mozilla\Thunderbird" },
        @{ Name="Firefox";     Process="firefox";     Profile="$env:APPDATA\Mozilla\Firefox";                   RegKey="HKLM:\SOFTWARE\Mozilla\Mozilla Firefox" },
        @{ Name="LibreWolf";   Process="librewolf";   Profile="$env:LOCALAPPDATA\librewolf";                    RegKey="HKLM:\SOFTWARE\LibreWolf" },
        @{ Name="Vivaldi";     Process="vivaldi";     Profile="$env:LOCALAPPDATA\Vivaldi\User Data\Default";    RegKey="HKLM:\SOFTWARE\Vivaldi" },
        @{ Name="Chrome";      Process="chrome";      Profile="$env:LOCALAPPDATA\Google\Chrome\User Data\Default"; RegKey="HKLM:\SOFTWARE\Google\Chrome" },
        @{ Name="Edge";        Process="msedge";      Profile="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"; RegKey="HKLM:\SOFTWARE\Microsoft\Edge" },
        @{ Name="Brave";       Process="brave";       Profile="$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"; RegKey="HKLM:\SOFTWARE\BraveSoftware\Brave-Browser" },
        @{ Name="Opera";       Process="opera";       Profile="$env:APPDATA\Opera Software\Opera Stable";       RegKey="HKLM:\SOFTWARE\Opera Software" }
    )
}

function Get-InstalledApps {
    $all = Get-SupportedApps
    $found = @()
    foreach ($app in $all) {
        $inReg    = Test-Path $app.RegKey
        $inRegU   = Test-Path ($app.RegKey -replace "HKLM:\\","HKCU:\")
        $hasProfile = Test-Path $app.Profile
        if ($inReg -or $inRegU -or $hasProfile) {
            $found += $app
        }
    }
    return $found
}

function Show-SelectionMenu {
    param($apps)

    $selected = @{}
    foreach ($app in $apps) { $selected[$app.Name] = $true }

    do {
        Show-Banner
        Write-Host "=== Sélection des applications ===" -ForegroundColor Cyan
        Write-Host ""

        for ($i = 0; $i -lt $apps.Count; $i++) {
            $app = $apps[$i]
            $check = if ($selected[$app.Name]) { "[x]" } else { "[ ]" }
            $color = if ($selected[$app.Name]) { "Green" } else { "Gray" }
            Write-Host "  $($i+1). $check $($app.Name)" -ForegroundColor $color
        }

        Write-Host ""
        Write-Host "  A. Tout sélectionner" -ForegroundColor Yellow
        Write-Host "  N. Tout désélectionner" -ForegroundColor Yellow
        Write-Host "  V. Valider" -ForegroundColor Cyan
        Write-Host ""
        $choice = Read-Host "Choix (numéro pour toggle, A/N/V)"

        if ($choice -match '^\d+$') {
            $idx = [int]$choice - 1
            if ($idx -ge 0 -and $idx -lt $apps.Count) {
                $name = $apps[$idx].Name
                $selected[$name] = -not $selected[$name]
            }
        } elseif ($choice -eq "A" -or $choice -eq "a") {
            foreach ($app in $apps) { $selected[$app.Name] = $true }
        } elseif ($choice -eq "N" -or $choice -eq "n") {
            foreach ($app in $apps) { $selected[$app.Name] = $false }
        }

    } while ($choice -notin @("V","v"))

    return $apps | Where-Object { $selected[$_.Name] }
}

function Backup {
    $installed = Get-InstalledApps

    if ($installed.Count -eq 0) {
        Write-Host "Aucune application détectée." -ForegroundColor Red
        return
    }

    Show-Banner
    Write-Host "Applications détectées :" -ForegroundColor Cyan
    foreach ($a in $installed) { Write-Host "  ✔ $($a.Name)" -ForegroundColor Green }
    Write-Host ""
    Write-Host "  1. Sauvegarder TOUT"
    Write-Host "  2. Choisir les applications"
    Write-Host ""
    $mode = Read-Host "Choix"

    $toBackup = if ($mode -eq "2") { Show-SelectionMenu $installed } else { $installed }

    if (-not $toBackup) {
        Write-Host "Rien de sélectionné." -ForegroundColor Yellow
        return
    }

    $backupRoot = "$env:USERPROFILE\Desktop\Sauvegarde_Browsers_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $total = $toBackup.Count
    $i = 0

    foreach ($app in $toBackup) {
        $i++
        $pct = [int](($i / $total) * 100)
        Write-Progress -Activity "Backup" -Status "$($app.Name)..." -PercentComplete $pct
        Copy-Item $app.Profile "$backupRoot\$($app.Name)" -Recurse -Force -EA SilentlyContinue
    }

    Write-Progress -Activity "Backup" -Completed
    Write-Host ""
    Write-Host "✅ Sauvegarde terminée dans : $backupRoot" -ForegroundColor Green
}

function Restore {
    $backupRoot = Read-Host "Chemin de la sauvegarde"

    if (-not (Test-Path $backupRoot)) {
        Write-Host "❌ Dossier introuvable : $backupRoot" -ForegroundColor Red
        return
    }

    $all = Get-SupportedApps
    $available = $all | Where-Object { Test-Path "$backupRoot\$($_.Name)" }

    if ($available.Count -eq 0) {
        Write-Host "❌ Aucune sauvegarde reconnue dans ce dossier." -ForegroundColor Red
        return
    }

    Show-Banner
    Write-Host "Applications trouvées dans la sauvegarde :" -ForegroundColor Cyan
    foreach ($a in $available) { Write-Host "  ✔ $($a.Name)" -ForegroundColor Green }
    Write-Host ""
    Write-Host "  1. Restaurer TOUT"
    Write-Host "  2. Choisir les applications"
    Write-Host ""
    $mode = Read-Host "Choix"

    $toRestore = if ($mode -eq "2") { Show-SelectionMenu $available } else { $available }

    if (-not $toRestore) {
        Write-Host "Rien de sélectionné." -ForegroundColor Yellow
        return
    }

    $processes = $toRestore | ForEach-Object { $_.Process }
    Get-Process $processes -EA SilentlyContinue | Stop-Process -Force
    Start-Sleep 2

    $total = $toRestore.Count
    $i = 0

    foreach ($app in $toRestore) {
        $i++
        $pct = [int](($i / $total) * 100)
        Write-Progress -Activity "Restore" -Status "$($app.Name)..." -PercentComplete $pct
        Copy-Item "$backupRoot\$($app.Name)" $app.Profile -Recurse -Force -EA SilentlyContinue
    }

    Write-Progress -Activity "Restore" -Completed
    Write-Host ""
    Write-Host "✅ Restauration terminée !" -ForegroundColor Green
}

do {
    Show-Banner

    Write-Host "1. Sauvegarder"
    Write-Host "2. Restaurer"
    Write-Host "0. Quitter"
    Write-Host ""
    $choice = Read-Host "Choix"

    switch ($choice) {
        "1" { Backup }
        "2" { Restore }
        "0" { return }
        "q" { return }
    }

    if ($choice -ne "0" -and $choice -ne "q") {
        Read-Host "Entrée pour continuer"
    }

} while ($true)

}