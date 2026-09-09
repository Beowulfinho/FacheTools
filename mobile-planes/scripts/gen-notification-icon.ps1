Add-Type -AssemblyName System.Drawing

# Android status-bar notification icons must be a plain alpha-channel silhouette — the OS ignores
# whatever RGB you draw and always renders it as a solid tint (white, normally), so only the
# shape's transparency mask matters, not its color. This redraws the app's folded-map mark (same
# path as the header icon in Planes/index.html: "M9 20l-6-2V4l6 2 6-2 6 2v14l-6-2-6 2z" plus the
# two fold lines "M9 4v14" / "M15 6v14") as that silhouette at every density Android expects for a
# 24dp notification icon.
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
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    function Pt($x, $y) {
        New-Object System.Drawing.PointF (($x * $scale), ($y * $scale))
    }

    # Folded-map outline: (9,20) (3,18) (3,4) (9,6) (15,4) (21,6) (21,20) (15,18) back to (9,20)
    $outline = @(Pt 9 20; Pt 3 18; Pt 3 4; Pt 9 6; Pt 15 4; Pt 21 6; Pt 21 20; Pt 15 18; Pt 9 20)
    $g.DrawLines($pen, $outline)

    # Fold lines
    $g.DrawLine($pen, (Pt 9 4), (Pt 9 18))
    $g.DrawLine($pen, (Pt 15 6), (Pt 15 20))

    $outDir = Join-Path $resRoot $dir
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $outPath = Join-Path $outDir "ic_stat_notify.png"
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host "Wrote $outPath ($size x $size)"
}
