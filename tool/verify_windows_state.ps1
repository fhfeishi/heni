param(
  [string]$Executable = (
    Join-Path $PSScriptRoot '..\build\windows\x64\runner\Debug\heni.exe'
  )
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class HeniWindowStateProbe {
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left, Top, Right, Bottom; }

  [DllImport("user32.dll")]
  public static extern bool SetProcessDpiAwarenessContext(IntPtr value);

  [DllImport("user32.dll")]
  public static extern uint GetDpiForWindow(IntPtr window);

  [DllImport("user32.dll")]
  public static extern bool GetWindowRect(IntPtr window, out RECT rect);

  [DllImport("user32.dll")]
  public static extern bool SetWindowPos(
    IntPtr window, IntPtr after, int x, int y, int width, int height, uint flags
  );

  [DllImport("user32.dll")]
  public static extern bool ShowWindow(IntPtr window, int command);

  [DllImport("user32.dll")]
  public static extern IntPtr SendMessage(
    IntPtr window, uint message, IntPtr wparam, IntPtr lparam
  );
}
'@

[HeniWindowStateProbe]::SetProcessDpiAwarenessContext(
  [IntPtr]::new(-4)
) | Out-Null

function Wait-HeniWindow([Diagnostics.Process]$Process) {
  for ($attempt = 0; $attempt -lt 120; $attempt++) {
    Start-Sleep -Milliseconds 100
    $Process.Refresh()
    if ($Process.HasExited) {
      throw "Heni exited before creating a window: $($Process.ExitCode)."
    }
    if ($Process.MainWindowHandle -ne [IntPtr]::Zero) {
      return $Process.MainWindowHandle
    }
  }
  throw 'Heni window was not created.'
}

function Read-HeniRect([IntPtr]$Handle) {
  $rect = New-Object HeniWindowStateProbe+RECT
  if (-not [HeniWindowStateProbe]::GetWindowRect($Handle, [ref]$rect)) {
    throw 'Could not read Heni window bounds.'
  }
  return $rect
}

function Test-Near([int]$Actual, [int]$Expected, [string]$Label) {
  if ([Math]::Abs($Actual - $Expected) -gt 1) {
    throw "$Label restored as $Actual, expected $Expected."
  }
}

$resolvedExecutable = (Resolve-Path -LiteralPath $Executable).Path
$probeAppData = Join-Path (
  [IO.Path]::GetTempPath()
) "heni-state-probe-$([Guid]::NewGuid().ToString('N'))"
[IO.Directory]::CreateDirectory($probeAppData) | Out-Null
$statePath = Join-Path $probeAppData 'Heni\window-state.ini'
$previousAppData = $env:APPDATA

try {
  $env:APPDATA = $probeAppData
  $first = Start-Process -FilePath $resolvedExecutable -PassThru
  $firstHandle = Wait-HeniWindow $first
  [HeniWindowStateProbe]::ShowWindow($firstHandle, 9) | Out-Null
  $dpi = [HeniWindowStateProbe]::GetDpiForWindow($firstHandle)
  $scale = $dpi / 96.0
  $targetWidth = [Math]::Round(1100 * $scale)
  $targetHeight = [Math]::Round(700 * $scale)
  [HeniWindowStateProbe]::SetWindowPos(
    $firstHandle,
    [IntPtr]::Zero,
    120,
    120,
    $targetWidth,
    $targetHeight,
    0x0040
  ) | Out-Null
  Start-Sleep -Milliseconds 500
  $normalRect = Read-HeniRect $firstHandle

  # Persist a completed user resize, then close while maximized. The saved
  # bounds must remain the normal rectangle rather than the work-area bounds.
  [HeniWindowStateProbe]::SendMessage(
    $firstHandle, 0x0232, [IntPtr]::Zero, [IntPtr]::Zero
  ) | Out-Null
  [HeniWindowStateProbe]::ShowWindow($firstHandle, 3) | Out-Null
  Start-Sleep -Milliseconds 300
  [HeniWindowStateProbe]::SendMessage(
    $firstHandle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero
  ) | Out-Null
  $first.WaitForExit(5000) | Out-Null
  if (-not $first.HasExited) {
    throw 'The first Heni process did not close cleanly.'
  }

  if (-not (Test-Path -LiteralPath $statePath)) {
    throw 'Heni did not persist window-state.ini.'
  }
  $state = @{}
  foreach ($line in Get-Content -LiteralPath $statePath) {
    $parts = $line -split '=', 2
    if ($parts.Count -eq 2) { $state[$parts[0]] = $parts[1] }
  }
  if ($state.maximized -ne '1') {
    throw 'Heni did not persist the maximized state.'
  }
  if ([int]$state.dpi -ne $dpi) {
    throw "Heni persisted DPI $($state.dpi), expected $dpi."
  }
  Test-Near ([int]$state.width) (
    $normalRect.Right - $normalRect.Left
  ) 'Persisted width'
  Test-Near ([int]$state.height) (
    $normalRect.Bottom - $normalRect.Top
  ) 'Persisted height'

  $second = Start-Process -FilePath $resolvedExecutable -PassThru
  $secondHandle = Wait-HeniWindow $second
  Start-Sleep -Milliseconds 500
  [HeniWindowStateProbe]::ShowWindow($secondHandle, 9) | Out-Null
  Start-Sleep -Milliseconds 500
  $restoredRect = Read-HeniRect $secondHandle

  Test-Near $restoredRect.Left $normalRect.Left 'Left edge'
  Test-Near $restoredRect.Top $normalRect.Top 'Top edge'
  Test-Near (
    $restoredRect.Right - $restoredRect.Left
  ) ($normalRect.Right - $normalRect.Left) 'Restored width'
  Test-Near (
    $restoredRect.Bottom - $restoredRect.Top
  ) ($normalRect.Bottom - $normalRect.Top) 'Restored height'

  Write-Output (
    "Heni state restore: " +
    "$($restoredRect.Left),$($restoredRect.Top) " +
    "$($restoredRect.Right - $restoredRect.Left)x" +
    "$($restoredRect.Bottom - $restoredRect.Top) at ${dpi}dpi"
  )
} finally {
  $env:APPDATA = $previousAppData
  foreach ($candidate in @($first, $second)) {
    if ($null -ne $candidate -and -not $candidate.HasExited) {
      Stop-Process -Id $candidate.Id
    }
  }
  $resolvedProbeAppData = [IO.Path]::GetFullPath($probeAppData)
  $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  if ($resolvedProbeAppData.StartsWith(
    $resolvedTemp,
    [StringComparison]::OrdinalIgnoreCase
  )) {
    Remove-Item -LiteralPath $resolvedProbeAppData -Recurse -Force
  }
}
