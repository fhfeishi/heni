param(
  [string]$Executable = (
    Join-Path $PSScriptRoot '..\build\windows\x64\runner\Debug\heni.exe'
  )
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class HeniChromeProbe {
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left, Top, Right, Bottom; }

  [StructLayout(LayoutKind.Sequential)]
  public struct POINT { public int X, Y; }

  [DllImport("user32.dll")]
  public static extern bool GetWindowRect(IntPtr window, out RECT rect);

  [DllImport("user32.dll")]
  public static extern bool GetClientRect(IntPtr window, out RECT rect);

  [DllImport("user32.dll")]
  public static extern bool ClientToScreen(IntPtr window, ref POINT point);

  [DllImport("user32.dll")]
  public static extern bool SetWindowPos(
    IntPtr window, IntPtr after, int x, int y, int width, int height, uint flags
  );
}
'@

$process = Start-Process -FilePath (Resolve-Path $Executable).Path -PassThru
try {
  $handle = [IntPtr]::Zero
  for ($attempt = 0; $attempt -lt 120; $attempt++) {
    Start-Sleep -Milliseconds 100
    $process.Refresh()
    if ($process.HasExited) {
      throw "Heni exited before creating a window: $($process.ExitCode)."
    }
    $handle = $process.MainWindowHandle
    if ($handle -ne [IntPtr]::Zero) { break }
  }
  if ($handle -eq [IntPtr]::Zero) { throw 'Heni window was not created.' }

  [HeniChromeProbe]::SetWindowPos(
    $handle, [IntPtr]::Zero, 50, 50, 1180, 760, 0x0040
  ) | Out-Null
  Start-Sleep -Seconds 2

  $windowRect = New-Object HeniChromeProbe+RECT
  $clientRect = New-Object HeniChromeProbe+RECT
  $origin = New-Object HeniChromeProbe+POINT
  [HeniChromeProbe]::GetWindowRect($handle, [ref]$windowRect) | Out-Null
  [HeniChromeProbe]::GetClientRect($handle, [ref]$clientRect) | Out-Null
  [HeniChromeProbe]::ClientToScreen($handle, [ref]$origin) | Out-Null

  $outerWidth = $windowRect.Right - $windowRect.Left
  $outerHeight = $windowRect.Bottom - $windowRect.Top
  $leftInset = $origin.X - $windowRect.Left
  $topInset = $origin.Y - $windowRect.Top
  Write-Output (
    "Heni chrome geometry: outer=${outerWidth}x${outerHeight} " +
    "client=$($clientRect.Right)x$($clientRect.Bottom) " +
    "inset=L${leftInset}/T${topInset}"
  )

  if (
    $leftInset -ne 0 -or $topInset -ne 0 -or
    $clientRect.Right -ne $outerWidth -or
    $clientRect.Bottom -ne $outerHeight
  ) {
    throw 'Heni client area does not fill the top-level window.'
  }
} finally {
  if (-not $process.HasExited) { Stop-Process -Id $process.Id }
}
