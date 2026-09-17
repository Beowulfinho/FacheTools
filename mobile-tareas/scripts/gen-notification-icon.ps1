Add-Type -AssemblyName System.Drawing

# Android status-bar notification icons must be a plain alpha-channel silhouette — the OS ignores
# whatever RGB you draw and always renders it as a solid tint (white, normally), so only the
# shape's transparency mask matters, not its color. This redraws the app's compass mark (same
# strokes as the favicon SVG in Tareas/index.html: four ticks around a circle) as that silhouette
# at every density Android expects for a 24dp notification icon.
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
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), (1.8 * $scale)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    function Pt($x, $y) {
        New-Object System.Drawing.PointF (($x * $scale), ($y * $scale))
    }

    # Cross ticks: (12,3)-(12,6) (12,18)-(12,21) (3,12)-(6,12) (18,12)-(21,12)
    $g.DrawLine($pen, (Pt 12 3), (Pt 12 6))
    $g.DrawLine($pen, (Pt 12 18), (Pt 12 21))
    $g.DrawLine($pen, (Pt 3 12), (Pt 6 12))
    $g.DrawLine($pen, (Pt 18 12), (Pt 21 12))

    # Compass needle circle, r=9 centered at (12,12)
    $r = 9 * $scale
    $g.DrawEllipse($pen, (12*$scale - $r), (12*$scale - $r), 2*$r, 2*$r)

    $outDir = Join-Path $resRoot $dir
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $outPath = Join-Path $outDir "ic_stat_notify.png"
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host "Wrote $outPath ($size x $size)"
}
