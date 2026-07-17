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
  public static extern bool ShowWindow(IntPtr window, int command);

  [DllImport("user32.dll")]
  public static extern bool SetForegroundWindow(IntPtr window);

  [DllImport("user32.dll")]
  public static extern IntPtr GetForegroundWindow();

  [DllImport("user32.dll")]
  public static extern bool BringWindowToTop(IntPtr window);

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
  $originalCursorPosition = [System.Windows.Forms.Cursor]::Position
  $mousePressed = $false
  try {
    $before = New-Object HeniChromeProbe+RECT
    [HeniChromeProbe]::GetWindowRect($Handle, [ref]$before) | Out-Null

    [HeniChromeProbe]::BringWindowToTop($Handle) | Out-Null
    [HeniChromeProbe]::SetForegroundWindow($Handle) | Out-Null
    Start-Sleep -Milliseconds 50
    if ([HeniChromeProbe]::GetForegroundWindow() -ne $Handle) {
      $activationX = $before.Left + 360
      $activationY = $before.Top + 32
      [System.Windows.Forms.Cursor]::Position =
        [System.Drawing.Point]::new($activationX, $activationY)
      $mousePressed = $true
      try {
        [HeniChromeProbe]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 25
      } finally {
        [HeniChromeProbe]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
        $mousePressed = $false
      }
      Start-Sleep -Milliseconds 100
    }
    if ([HeniChromeProbe]::GetForegroundWindow() -ne $Handle) {
      throw "Heni window handle $Handle did not become foreground after activation click."
    }

    $startX = $before.Left + $RelativeX
    $startY = $before.Top + $RelativeY
    [System.Windows.Forms.Cursor]::Position =
      [System.Drawing.Point]::new($startX, $startY)
    $mousePressed = $true
    [HeniChromeProbe]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    for ($step = 1; $step -le 12; $step++) {
      $x = [Math]::Round($startX + ($DeltaX * $step / 12))
      $y = [Math]::Round($startY + ($DeltaY * $step / 12))
      [System.Windows.Forms.Cursor]::Position =
        [System.Drawing.Point]::new($x, $y)
      Start-Sleep -Milliseconds 25
    }
    [HeniChromeProbe]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    $mousePressed = $false
    Start-Sleep -Milliseconds 600

    $after = New-Object HeniChromeProbe+RECT
    [HeniChromeProbe]::GetWindowRect($Handle, [ref]$after) | Out-Null
    return $after.Left -ne $before.Left -or $after.Top -ne $before.Top
  } finally {
    try {
      if ($mousePressed) {
        [HeniChromeProbe]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
      }
    } finally {
      [System.Windows.Forms.Cursor]::Position = $originalCursorPosition
    }
  }
}

function Wait-HeniTargetGeometry([IntPtr]$Handle) {
  $stableSamples = 0
  $lastGeometry = 'unavailable'
  for ($attempt = 0; $attempt -lt 50; $attempt++) {
    $windowRect = New-Object HeniChromeProbe+RECT
    $clientRect = New-Object HeniChromeProbe+RECT
    $origin = New-Object HeniChromeProbe+POINT
    $windowRead =
      [HeniChromeProbe]::GetWindowRect($Handle, [ref]$windowRect)
    $clientRead =
      [HeniChromeProbe]::GetClientRect($Handle, [ref]$clientRect)
    $originRead =
      [HeniChromeProbe]::ClientToScreen($Handle, [ref]$origin)

    if ($windowRead -and $clientRead -and $originRead) {
      $outerWidth = $windowRect.Right - $windowRect.Left
      $outerHeight = $windowRect.Bottom - $windowRect.Top
      $lastGeometry = (
        "outer=${outerWidth}x${outerHeight} " +
        "client=$($clientRect.Right)x$($clientRect.Bottom) " +
        "origin=$($origin.X),$($origin.Y)"
      )
      $atTarget =
        $windowRect.Left -eq 50 -and $windowRect.Top -eq 50 -and
        $outerWidth -eq 1180 -and $outerHeight -eq 760 -and
        $clientRect.Right -eq $outerWidth -and
        $clientRect.Bottom -eq $outerHeight -and
        $origin.X -eq $windowRect.Left -and
        $origin.Y -eq $windowRect.Top
      if ($atTarget) {
        $stableSamples++
        if ($stableSamples -ge 3) {
          return [PSCustomObject]@{
            WindowRect = $windowRect
            ClientRect = $clientRect
            Origin = $origin
          }
        }
      } else {
        $stableSamples = 0
      }
    } else {
      $stableSamples = 0
    }
    Start-Sleep -Milliseconds 100
  }

  throw "Heni window did not reach stable target geometry: $lastGeometry."
}

function Reset-HeniWindow([IntPtr]$Handle) {
  [HeniChromeProbe]::ShowWindow($Handle, 9) | Out-Null
  [HeniChromeProbe]::SetWindowPos(
    $Handle, [IntPtr]::Zero, 50, 50, 1180, 760, 0x0040
  ) | Out-Null
  return Wait-HeniTargetGeometry $Handle
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

  # Allow the persisted initial show command to settle before forcing the
  # deterministic probe geometry.
  Start-Sleep -Seconds 2
  $geometry = Reset-HeniWindow $handle

  $windowRect = $geometry.WindowRect
  $clientRect = $geometry.ClientRect
  $origin = $geometry.Origin

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
  Reset-HeniWindow $handle | Out-Null
  $brandMoved = Invoke-HeniDrag $handle $brandPoint.X $brandPoint.Y
  Reset-HeniWindow $handle | Out-Null
  $searchMoved = Invoke-HeniDrag $handle $searchPoint.X $searchPoint.Y
  Reset-HeniWindow $handle | Out-Null
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
