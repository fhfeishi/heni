param(
  [string]$Executable = (
    Join-Path $PSScriptRoot '..\build\windows\x64\runner\Debug\heni.exe'
  ),
  [string]$Screenshot,
  [switch]$SkipPointerDragChecks
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
  private static extern uint GetWindowThreadProcessId(
    IntPtr window, IntPtr processId
  );

  [DllImport("kernel32.dll")]
  private static extern uint GetCurrentThreadId();

  [DllImport("user32.dll")]
  private static extern bool AttachThreadInput(
    uint attachThread, uint attachToThread, bool attach
  );

  [DllImport("user32.dll")]
  public static extern IntPtr SendMessage(
    IntPtr window, uint message, IntPtr wparam, IntPtr lparam
  );

  [DllImport("user32.dll")]
  public static extern bool SetProcessDpiAwarenessContext(IntPtr value);

  [DllImport("user32.dll")]
  public static extern uint GetDpiForWindow(IntPtr window);

  [DllImport("dwmapi.dll")]
  public static extern int DwmGetWindowAttribute(
    IntPtr window, uint attribute, out int value, int valueSize
  );

  [DllImport("user32.dll")]
  public static extern void mouse_event(
    uint flags, uint x, uint y, uint data, UIntPtr extraInfo
  );

  [DllImport("user32.dll")]
  private static extern void keybd_event(
    byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo
  );

  public static bool ForceForeground(IntPtr window) {
    IntPtr foreground = GetForegroundWindow();
    uint currentThread = GetCurrentThreadId();
    uint foregroundThread = GetWindowThreadProcessId(foreground, IntPtr.Zero);
    uint targetThread = GetWindowThreadProcessId(window, IntPtr.Zero);
    bool foregroundAttached = false;
    bool targetAttached = false;
    try {
      if (foregroundThread != 0 && foregroundThread != currentThread) {
        foregroundAttached = AttachThreadInput(
          currentThread, foregroundThread, true
        );
      }
      if (targetThread != 0 && targetThread != currentThread) {
        targetAttached = AttachThreadInput(currentThread, targetThread, true);
      }
      BringWindowToTop(window);
      keybd_event(0x12, 0, 0, UIntPtr.Zero);
      keybd_event(0x12, 0, 0x0002, UIntPtr.Zero);
      SetForegroundWindow(window);
      return GetForegroundWindow() == window;
    } finally {
      if (targetAttached) {
        AttachThreadInput(currentThread, targetThread, false);
      }
      if (foregroundAttached) {
        AttachThreadInput(currentThread, foregroundThread, false);
      }
    }
  }
}
'@

# Make the probe coordinates physical and deterministic on non-100% displays.
[HeniChromeProbe]::SetProcessDpiAwarenessContext([IntPtr]::new(-4)) | Out-Null

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

    [HeniChromeProbe]::SetWindowPos(
      $Handle, [IntPtr]::new(-1), 0, 0, 0, 0, 0x0043
    ) | Out-Null
    [HeniChromeProbe]::SetWindowPos(
      $Handle, [IntPtr]::new(-2), 0, 0, 0, 0, 0x0043
    ) | Out-Null
    [HeniChromeProbe]::ForceForeground($Handle) | Out-Null
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
      [HeniChromeProbe]::ForceForeground($Handle) | Out-Null
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

function Wait-HeniTargetGeometry(
  [IntPtr]$Handle,
  [int]$TargetWidth,
  [int]$TargetHeight
) {
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
        $outerWidth -eq $TargetWidth -and $outerHeight -eq $TargetHeight -and
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
  # Move first so the target monitor, rather than a persisted monitor, decides
  # the DPI used for the deterministic logical size below.
  [HeniChromeProbe]::SetWindowPos(
    $Handle, [IntPtr]::Zero, 50, 50, 1180, 760, 0x0040
  ) | Out-Null
  Start-Sleep -Milliseconds 100
  $scale = [HeniChromeProbe]::GetDpiForWindow($Handle) / 96.0
  $targetWidth = [Math]::Round(1180 * $scale)
  $targetHeight = [Math]::Round(760 * $scale)
  [HeniChromeProbe]::SetWindowPos(
    $Handle, [IntPtr]::Zero, 50, 50, $targetWidth, $targetHeight, 0x0040
  ) | Out-Null
  return Wait-HeniTargetGeometry $Handle $targetWidth $targetHeight
}

$probeAppData = Join-Path (
  [IO.Path]::GetTempPath()
) "heni-chrome-probe-$([Guid]::NewGuid().ToString('N'))"
[IO.Directory]::CreateDirectory($probeAppData) | Out-Null
$previousAppData = $env:APPDATA
try {
  $env:APPDATA = $probeAppData
  $process = Start-Process -FilePath (Resolve-Path $Executable).Path -PassThru
} finally {
  $env:APPDATA = $previousAppData
}
try {
  $handle = [IntPtr]::Zero
  for ($attempt = 0; $attempt -lt 300; $attempt++) {
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

  $cornerPreference = 0
  $cornerResult = [HeniChromeProbe]::DwmGetWindowAttribute(
    $handle,
    33,
    [ref]$cornerPreference,
    4
  )
  if ($cornerResult -eq 0) {
    Write-Output "Heni DWM corner preference: $cornerPreference"
    if ($cornerPreference -ne 2) {
      throw "Heni did not request the standard rounded DWM corner style."
    }
  } else {
    Write-Output (
      "Heni DWM corner preference unavailable; square fallback expected " +
      "(HRESULT=0x$($cornerResult.ToString('X8')))."
    )
  }

  if ($Screenshot) {
    $padding = 24
    $captureWidth = $outerWidth + ($padding * 2)
    $captureHeight = $outerHeight + ($padding * 2)
    $bitmap = [System.Drawing.Bitmap]::new($captureWidth, $captureHeight)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.CopyFromScreen(
        $windowRect.Left - $padding,
        $windowRect.Top - $padding,
        0,
        0,
        $bitmap.Size
      )
      $resolvedScreenshot = [IO.Path]::GetFullPath($Screenshot)
      [IO.Directory]::CreateDirectory(
        [IO.Path]::GetDirectoryName($resolvedScreenshot)
      ) | Out-Null
      $bitmap.Save(
        $resolvedScreenshot,
        [System.Drawing.Imaging.ImageFormat]::Png
      )
      Write-Output "Heni chrome screenshot: $resolvedScreenshot"
    } finally {
      $graphics.Dispose()
      $bitmap.Dispose()
    }
  }

  $middleX = [Math]::Round(($windowRect.Left + $windowRect.Right) / 2)
  $middleY = [Math]::Round(($windowRect.Top + $windowRect.Bottom) / 2)
  $hitTests = @(
    @('left', ($windowRect.Left + 1), $middleY, 10),
    @('right', ($windowRect.Right - 1), $middleY, 11),
    @('top', $middleX, ($windowRect.Top + 1), 12),
    @(
      'topLeft',
      ($windowRect.Left + 1),
      ($windowRect.Top + 1),
      13
    ),
    @(
      'topRight',
      ($windowRect.Right - 1),
      ($windowRect.Top + 1),
      14
    ),
    @('bottom', $middleX, ($windowRect.Bottom - 1), 15),
    @(
      'bottomLeft',
      ($windowRect.Left + 1),
      ($windowRect.Bottom - 1),
      16
    ),
    @(
      'bottomRight',
      ($windowRect.Right - 1),
      ($windowRect.Bottom - 1),
      17
    )
  )
  $hitResults = foreach ($test in $hitTests) {
    $packedPoint = (($test[2] -band 0xFFFF) -shl 16) -bor (
      $test[1] -band 0xFFFF
    )
    $actual = [HeniChromeProbe]::SendMessage(
      $handle,
      0x0084,
      [IntPtr]::Zero,
      [IntPtr]::new($packedPoint)
    ).ToInt32()
    if ($actual -ne $test[3]) {
      throw "Heni $($test[0]) hit test returned $actual, expected $($test[3])."
    }
    "$($test[0])=$actual"
  }
  Write-Output "Heni resize hit tests: $($hitResults -join ' ')"

  if ($SkipPointerDragChecks) {
    Write-Output 'Heni pointer drag checks skipped by request.'
    return
  }

  # Relative coordinates inside the Heni top chrome.
  $scale = [HeniChromeProbe]::GetDpiForWindow($handle) / 96.0
  $brandPoint = [System.Drawing.Point]::new(
    [Math]::Round(42 * $scale),
    [Math]::Round(32 * $scale)
  )
  $searchPoint = [System.Drawing.Point]::new(
    [Math]::Round(360 * $scale),
    [Math]::Round(32 * $scale)
  )
  $spacerPoint = [System.Drawing.Point]::new(
    [Math]::Round(820 * $scale),
    [Math]::Round(32 * $scale)
  )

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
  $resolvedProbeAppData = [IO.Path]::GetFullPath($probeAppData)
  $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  if ($resolvedProbeAppData.StartsWith(
    $resolvedTemp,
    [StringComparison]::OrdinalIgnoreCase
  )) {
    Remove-Item -LiteralPath $resolvedProbeAppData -Recurse -Force
  }
}
