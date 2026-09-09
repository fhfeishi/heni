param(
  [string]$Executable = (
    Join-Path $PSScriptRoot '..\build\windows\x64\runner\Debug\heni.exe'
  )
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class HeniMinimumWindowProbe {
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
  }

  [DllImport("user32.dll", SetLastError = true)]
  public static extern bool SetWindowPos(
    IntPtr hWnd,
    IntPtr hWndInsertAfter,
    int x,
    int y,
    int width,
    int height,
    uint flags
  );

  [DllImport("user32.dll")]
  public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

  [DllImport("user32.dll")]
  public static extern bool ShowWindow(IntPtr hWnd, int command);

  [DllImport("user32.dll")]
  public static extern bool SetProcessDpiAwarenessContext(IntPtr value);

  [DllImport("user32.dll")]
  public static extern uint GetDpiForWindow(IntPtr window);
}
'@

[HeniMinimumWindowProbe]::SetProcessDpiAwarenessContext(
  [IntPtr]::new(-4)
) | Out-Null

$resolvedExecutable = (Resolve-Path -LiteralPath $Executable).Path
$probeAppData = Join-Path (
  [IO.Path]::GetTempPath()
) "heni-minimum-probe-$([Guid]::NewGuid().ToString('N'))"
[IO.Directory]::CreateDirectory($probeAppData) | Out-Null
$previousAppData = $env:APPDATA
try {
  $env:APPDATA = $probeAppData
  $process = Start-Process `
    -FilePath $resolvedExecutable `
    -PassThru
} finally {
  $env:APPDATA = $previousAppData
}

try {
  $handle = [IntPtr]::Zero
  for ($attempt = 0; $attempt -lt 100; $attempt++) {
    Start-Sleep -Milliseconds 100
    $process.Refresh()
    if ($process.HasExited) {
      throw "Heni exited before creating a window with code $($process.ExitCode)."
    }
    $handle = $process.MainWindowHandle
    if ($handle -ne [IntPtr]::Zero) {
      break
    }
  }

  if ($handle -eq [IntPtr]::Zero) {
    throw 'Heni did not create a top-level window.'
  }

  [HeniMinimumWindowProbe]::ShowWindow($handle, 5) | Out-Null
  $dpi = [HeniMinimumWindowProbe]::GetDpiForWindow($handle)
  $scale = $dpi / 96.0
  $expectedWidth = [Math]::Round(900 * $scale)
  $expectedHeight = [Math]::Round(620 * $scale)
  [HeniMinimumWindowProbe]::SetWindowPos(
    $handle,
    [IntPtr]::Zero,
    40,
    40,
    [Math]::Round(220 * $scale),
    [Math]::Round(300 * $scale),
    0x0040
  ) | Out-Null
  Start-Sleep -Milliseconds 600

  $rect = New-Object HeniMinimumWindowProbe+RECT
  if (-not [HeniMinimumWindowProbe]::GetWindowRect($handle, [ref]$rect)) {
    throw 'Could not read the resized Heni window rectangle.'
  }

  $width = $rect.Right - $rect.Left
  $height = $rect.Bottom - $rect.Top
  Write-Output (
    "Heni minimum resize result: ${width}x${height} " +
    "at ${dpi}dpi (expected at least ${expectedWidth}x${expectedHeight})"
  )

  if ($width -lt $expectedWidth -or $height -lt $expectedHeight) {
    throw (
      "Window shrank below the 900x620 logical minimum: " +
      "${width}x${height} at ${dpi}dpi."
    )
  }
} finally {
  if (-not $process.HasExited) {
    Stop-Process -Id $process.Id
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
