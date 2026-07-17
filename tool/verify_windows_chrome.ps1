param(
  [string]$Executable = (
    Join-Path $PSScriptRoot '..\build\windows\x64\runner\Debug\heni.exe'
  )
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

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

  [DllImport("user32.dll")]
  public static extern bool SetForegroundWindow(IntPtr window);

  [DllImport("user32.dll")]
  public static extern void mouse_event(
    uint flags, uint x, uint y, uint data, UIntPtr extraInfo
  );
}
'@

function Invoke-HeniDrag(
  [IntPtr]$Handle,
  [int]$RelativeX,
  [int]$RelativeY,
  [int]$DeltaX = 180,
  [int]$DeltaY = 90
) {
  $before = New-Object HeniChromeProbe+RECT
  [HeniChromeProbe]::GetWindowRect($Handle, [ref]$before) | Out-Null
  [HeniChromeProbe]::SetForegroundWindow($Handle) | Out-Null
  $startX = $before.Left + $RelativeX
  $startY = $before.Top + $RelativeY
  [System.Windows.Forms.Cursor]::Position =
    [System.Drawing.Point]::new($startX, $startY)
  [HeniChromeProbe]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  for ($step = 1; $step -le 12; $step++) {
    $x = [Math]::Round($startX + ($DeltaX * $step / 12))
    $y = [Math]::Round($startY + ($DeltaY * $step / 12))
    [System.Windows.Forms.Cursor]::Position =
      [System.Drawing.Point]::new($x, $y)
    Start-Sleep -Milliseconds 25
  }
  [HeniChromeProbe]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 600

  $after = New-Object HeniChromeProbe+RECT
  [HeniChromeProbe]::GetWindowRect($Handle, [ref]$after) | Out-Null
  return $after.Left -ne $before.Left -or $after.Top -ne $before.Top
}

function Reset-HeniWindow([IntPtr]$Handle) {
  [HeniChromeProbe]::SetWindowPos(
    $Handle, [IntPtr]::Zero, 50, 50, 1180, 760, 0x0040
  ) | Out-Null
  Start-Sleep -Milliseconds 500
}

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

  # Relative coordinates inside the Heni top chrome.
  $brandPoint = [System.Drawing.Point]::new(42, 32)
  $searchPoint = [System.Drawing.Point]::new(360, 32)
  $spacerPoint = [System.Drawing.Point]::new(820, 32)

  # Expected results after a 180x90 pointer drag:
  # brand: window origin changes
  # search: window origin remains (50, 50)
  # spacer: window origin changes
  Reset-HeniWindow $handle
  $brandMoved = Invoke-HeniDrag $handle $brandPoint.X $brandPoint.Y
  Reset-HeniWindow $handle
  $searchMoved = Invoke-HeniDrag $handle $searchPoint.X $searchPoint.Y
  Reset-HeniWindow $handle
  $spacerMoved = Invoke-HeniDrag $handle $spacerPoint.X $spacerPoint.Y
  $searchProtected = -not $searchMoved

  Write-Output (
    "Heni drag results: brand=$brandMoved " +
    "searchProtected=$searchProtected spacer=$spacerMoved"
  )
  if (-not $brandMoved -or -not $searchProtected -or -not $spacerMoved) {
    throw 'Heni top-chrome drag regions do not match the interaction contract.'
  }
} finally {
  if (-not $process.HasExited) { Stop-Process -Id $process.Id }
}
