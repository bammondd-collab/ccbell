# ccbell installer for Windows (no admin rights needed).
#
#   Online, latest GitHub release:
#     irm https://raw.githubusercontent.com/OWNER/REPO/master/scripts/install.ps1 | iex
#   Offline: unzip ccbell-win-x64.zip and double-click Install.cmd
#
# What it does:
#   1. copies the app to %LOCALAPPDATA%\Programs\ccbell
#   2. adds a Start menu shortcut and an entry in Settings > Apps (to uninstall)
#   3. adds the widget's Stop / Notification hooks to ~/.claude/settings.json
#      (only its own entries; the file is backed up next to itself first)
#   4. installs the VS Code bridge extension when the `code` command exists
#   5. starts the widget (it starts with Windows from then on; switch that off in its settings)
#
# Keep this file ASCII: Windows PowerShell 5.1 reads scripts without a BOM as the ANSI code page.

& {
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'

  # Names: keep in sync with shared/brand.ts (test/brand.test.js checks).
  $Product = 'ccbell'
  $ExeName = 'ccbell'
  $Repo = 'bammondd-collab/ccbell'
  $BridgeVsix = 'ccbell-bridge.vsix'
  # Written by `npm run pack`: the release this installer downloads and its zip's SHA-256.
  $Version = '1.0.1'
  $ZipSha256 = 'A535C3150E32C7A8F427C0A7FFEA35B914288BBB3FB18910D484A1B4633FDFC9'
  # Earlier installs under another name: stopped, unregistered and removed (their settings are copied over).
  $LegacyInstalls = @(@{ Product = 'Session Widget'; ExeName = 'SessionWidget' })
  $LegacyBridgeIds = @('jjmma.session-widget-bridge')

  $Target = Join-Path $env:LOCALAPPDATA "Programs\$ExeName"
  $Exe = Join-Path $Target "$ExeName.exe"
  $ZipName = "$ExeName-win-x64.zip"
  $tmp = $null

  function Step([string]$m) { Write-Host "  - $m" }

  # Native commands write progress to stderr; under 'Stop' Windows PowerShell would turn that into an error.
  function Quiet([scriptblock]$b) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $b 2>&1 | Out-Null } catch {} finally { $ErrorActionPreference = $old }
  }

  try {
    if ($env:OS -ne 'Windows_NT') { throw "$Product runs on Windows only." }
    if (-not [Environment]::Is64BitOperatingSystem) { throw "$Product needs 64-bit Windows." }
    Write-Host "Installing $Product"

    # 1. Files: this folder (Install.cmd inside the zip), a zip named in CCBELL_ZIP, or the pinned release.
    $src = $null
    if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "$ExeName.exe"))) {
      $src = $PSScriptRoot
    } else {
      $tmp = Join-Path ([IO.Path]::GetTempPath()) ("$ExeName-" + [Guid]::NewGuid().ToString('N'))
      New-Item -ItemType Directory -Path $tmp | Out-Null
      $zip = $env:CCBELL_ZIP
      if (-not $zip) {
        if ($Repo -eq 'OWNER/REPO') { throw 'No GitHub repository is set in this installer yet. Use Install.cmd from the zip instead.' }
        if (-not $ZipSha256) { throw 'This installer has no release checksum. Use the copy from the repository or the release.' }
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $zip = Join-Path $tmp $ZipName
        $url = "https://github.com/$Repo/releases/download/v$Version/$ZipName"
        Step "downloading $url"
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip
      }
      # The zip must be byte for byte the one this installer was released with.
      if ($ZipSha256) {
        $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
        if ($hash -ne $ZipSha256) { throw "The zip's checksum does not match ($hash). Nothing was installed." }
        Step 'checksum ok'
      }
      Step 'unpacking'
      $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
      if (Test-Path $tar) { & $tar -xf $zip -C $tmp; if ($LASTEXITCODE) { throw 'Could not unpack the zip.' } }
      else { Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force }
      $src = Join-Path $tmp $ExeName
      if (-not (Test-Path (Join-Path $src "$ExeName.exe"))) { throw "The zip does not contain $ExeName\$ExeName.exe" }
    }

    # 2. Stop the running copy (and any copy under an older name) and replace the files.
    foreach ($n in @($ExeName) + ($LegacyInstalls | ForEach-Object { $_.ExeName })) {
      Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force
    }
    Start-Sleep -Milliseconds 800
    if ((Resolve-Path $src).Path.TrimEnd('\') -ine $Target.TrimEnd('\')) {
      Step "copying to $Target"
      if (Test-Path $Target) { Remove-Item -LiteralPath $Target -Recurse -Force }
      New-Item -ItemType Directory -Path (Split-Path $Target) -Force | Out-Null
      Copy-Item -LiteralPath $src -Destination $Target -Recurse
    }
    Get-ChildItem -LiteralPath $Target -Recurse -File | Unblock-File

    # 3. Start menu shortcut and the Settings > Apps entry.
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Programs')) "$Product.lnk"))
    $lnk.TargetPath = $Exe
    $lnk.WorkingDirectory = $Target
    $lnk.IconLocation = "$Target\icon.ico,0"
    $lnk.Description = 'Claude Code sessions at a glance'
    $lnk.Save()

    $shownVersion = ''
    $vf = Join-Path $Target 'version.txt'
    if (Test-Path $vf) { $shownVersion = (Get-Content $vf -TotalCount 1).Trim() }
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$ExeName"
    New-Item -Path $key -Force | Out-Null
    $strings = @{
      DisplayName     = $Product
      DisplayVersion  = $shownVersion
      Publisher       = $Product
      DisplayIcon     = "$Target\icon.ico"
      InstallLocation = $Target
      UninstallString = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Target\uninstall.ps1`""
    }
    foreach ($k in $strings.Keys) { New-ItemProperty -Path $key -Name $k -Value $strings[$k] -PropertyType String -Force | Out-Null }
    $kb = [int]((Get-ChildItem -LiteralPath $Target -Recurse -File | Measure-Object Length -Sum).Sum / 1KB)
    foreach ($k in @{ NoModify = 1; NoRepair = 1; EstimatedSize = $kb }.GetEnumerator()) {
      New-ItemProperty -Path $key -Name $k.Key -Value $k.Value -PropertyType DWord -Force | Out-Null
    }

    # 4. Claude Code hooks (the app edits settings.json itself, so the JSON keeps its shape).
    if (-not (Test-Path (Join-Path $HOME '.claude'))) { Step 'Claude Code not found yet (~/.claude): the hooks will be ready when it is installed' }
    Step 'adding the Claude Code hooks to ~/.claude/settings.json'
    $p = Start-Process -FilePath $Exe -ArgumentList '--setup' -Wait -PassThru
    if ($p.ExitCode -ne 0) {
      Write-Warning 'Could not read ~/.claude/settings.json (is it valid JSON?). The widget still works; turn the hooks on later in its settings.'
    }

    # Earlier installs: --setup above already moved their hooks and settings to this one.
    foreach ($old in $LegacyInstalls) {
      $oldDir = Join-Path $env:LOCALAPPDATA "Programs\$($old.ExeName)"
      if (-not (Test-Path $oldDir)) { continue }
      Step "removing the earlier install ($($old.Product))"
      Remove-Item -LiteralPath (Join-Path ([Environment]::GetFolderPath('Programs')) "$($old.Product).lnk") -Force -ErrorAction SilentlyContinue
      Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$($old.ExeName)" -Recurse -Force -ErrorAction SilentlyContinue
      Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $old.Product -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath $oldDir -Recurse -Force -ErrorAction SilentlyContinue
      if ($p.ExitCode -eq 0) { Remove-Item -LiteralPath (Join-Path $env:APPDATA $old.Product) -Recurse -Force -ErrorAction SilentlyContinue }
    }

    # 5. VS Code bridge: lets the widget jump to the VS Code terminal tab that shows a session.
    if (Get-Command code -ErrorAction SilentlyContinue) {
      Step 'installing the VS Code bridge extension'
      foreach ($old in $LegacyBridgeIds) { Quiet { code --uninstall-extension $old } }
      $vsix = Join-Path $Target "resources\app\vscode-bridge\$BridgeVsix"
      Quiet { code --install-extension $vsix --force }
    } else {
      Step 'VS Code (code command) not found: skipped the bridge extension; install it later from the widget settings'
    }

    # 6. Start.
    Start-Process -FilePath $Exe
    Write-Host ''
    Write-Host "$Product is running: look for the small capsule at the right edge of the screen." -ForegroundColor Green
    Write-Host "Uninstall: Settings > Apps > $Product, or run $Target\uninstall.ps1"
  } catch {
    Write-Host ''
    Write-Host "Install failed: $($_.Exception.Message)" -ForegroundColor Red
  } finally {
    if ($tmp -and (Test-Path $tmp)) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
  }
}
