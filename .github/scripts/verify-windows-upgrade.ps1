param([string]$CandidateInstaller)
$ErrorActionPreference = 'Stop'
$installDir = Join-Path $env:RUNNER_TEMP 'Larik Chat upgrade QA'
$exe = Join-Path $installDir 'Larik Chat.exe'
$oldInstaller = Join-Path $env:RUNNER_TEMP 'larik-chat-old.exe'
$newInstaller = if ($CandidateInstaller) { $CandidateInstaller } else { Join-Path $PSScriptRoot '..\dist\Larik-Chat-0.1.5-win-x64.exe' }
function ClientProcesses {
  @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.Equals($exe, [StringComparison]::OrdinalIgnoreCase) })
}
function WaitUntil([scriptblock]$test, [string]$message, [int]$seconds = 30) {
  $end = (Get-Date).AddSeconds($seconds)
  do { if (& $test) { return }; Start-Sleep -Milliseconds 500 } while ((Get-Date) -lt $end)
  throw $message
}
function Install([string]$file) {
  $p = Start-Process -FilePath $file -ArgumentList @('/S', "/D=$installDir") -PassThru
  if (-not $p.WaitForExit(120000)) { throw 'Installer timed out' }
  if ($p.ExitCode -ne 0) { throw "Installer failed: $($p.ExitCode)" }
}
try {
  Invoke-WebRequest 'https://github.com/Larik1329/larik-chat-desktop/releases/download/v0.1.4/Larik-Chat-0.1.4-win-x64.exe' -OutFile $oldInstaller
  Install $oldInstaller
  WaitUntil { Test-Path $exe } 'Old application was not installed'
  $old = Start-Process $exe -PassThru
  WaitUntil { (ClientProcesses).Count -gt 0 } 'Old application did not start'
  Start-Sleep -Seconds 4
  # WM_CLOSE exercises the old close-to-tray behaviour, when an HWND is available.
  if ($old.HasExited) { throw 'Old client exited before upgrade test' }
  $old.Refresh()
  if ($old.MainWindowHandle -ne 0) {
    [void]$old.CloseMainWindow()
    Start-Sleep -Seconds 1
    if ($old.HasExited) { throw 'Old client unexpectedly exited instead of staying in the tray' }
  }
  Install $newInstaller
  WaitUntil { (ClientProcesses).Count -eq 0 } 'Upgrade left old application processes alive' 30
  if (-not $old.HasExited) { throw 'Old application survived upgrade' }
  $version = (Get-Item $exe).VersionInfo.ProductVersion
  if ($version -notlike '0.1.5*') { throw "Wrong installed version: $version" }
  Write-Output 'WINDOWS_OLD_CLIENT_UPGRADE_PASS'
  $new = Start-Process $exe -PassThru
  WaitUntil { (ClientProcesses).Count -gt 0 } 'New application did not start'
  Start-Sleep -Seconds 4
  if ($new.HasExited) { throw 'New client exited before shutdown test' }
  $new.Refresh()
  if ($new.MainWindowHandle -ne 0) { [void]$new.CloseMainWindow() }
  $request = Start-Process $exe -ArgumentList '--quit-for-update' -PassThru
  if (-not $request.WaitForExit(15000)) { throw 'Shutdown request did not finish' }
  WaitUntil { (ClientProcesses).Count -eq 0 } 'Native updater shutdown left helpers alive' 20
  Write-Output 'WINDOWS_GRACEFUL_UPDATE_SHUTDOWN_PASS'
} finally {
  # Only this isolated runner's private test installation, never an arbitrary client.
  ClientProcesses | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}
