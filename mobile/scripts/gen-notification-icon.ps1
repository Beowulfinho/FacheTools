Add-Type -AssemblyName System.Drawing

# Android status-bar notification icons must be a plain alpha-channel silhouette — the OS
# ignores whatever RGB you draw and always renders it as a solid tint (white, normally), so the
# only thing that matters here is the shape's transparency mask, not its color. This redraws the
# app's stacked-coins mark (same ellipses as the favicon SVG in Financas/index.html) as that
# silhouette at every density Android expects for a 24dp notification icon.
$sizes = @{
    "drawable-mdpi"    = 24
    "drawable-hdpi"    = 36
    "drawable-xhdpi"   = 48
    "drawable-xxhdpi"  = 72
    "drawable-xxxhdpi" = 96
}

$resRoot = Join-Path $PSScriptRoot "..\android\app\src\main\res"

foreach ($dir in $sizes.Keys) {
    $size = $sizes[$dir]
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    $scale = $size / 24.0
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), (1.6 * $scale)
    $brush = [System.Drawing.Brushes]::White

    # Three overlapping ellipses, same layout as the app favicon (viewBox 0 0 24 24 equivalent)
    function DrawEllipseAt($cx, $cy, $rx, $ry, $filled) {
        $x = ($cx - $rx) * $scale
        $y = ($cy - $ry) * $scale
        $w = 2 * $rx * $scale
        $h = 2 * $ry * $scale
        if ($filled) { $g.FillEllipse($brush, $x, $y, $w, $h) }
        $g.DrawEllipse($pen, $x, $y, $w, $h)
    }
    DrawEllipseAt 9.5 15.7 5.6 3 $false
    DrawEllipseAt 9.5 12.7 5.6 3 $false
    DrawEllipseAt 12.2 9 5.6 3 $true

    $outDir = Join-Path $resRoot $dir
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $outPath = Join-Path $outDir "ic_stat_notify.png"
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host "Wrote $outPath ($size x $size)"
}
