Add-Type -AssemblyName System.Drawing

# Genera la marca de Tratamientos (calendario con check) en todos los tamaños:
#  - icono de la app (assets/icon.png para @capacitor/assets + icon-180/192/512 del PWA)
#  - icono de notificación de Android (silueta blanca sobre transparente, un tamaño por densidad)
# Coordenadas en una grilla de 24x24 (igual que el SVG del header en Tratamientos/index.html).

function New-Pen($size, $scale, $widthUnits, $color) {
    $p = New-Object System.Drawing.Pen $color, ($widthUnits * $scale)
    $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    return $p
}

function Draw-Glyph($g, $pen, $scale, $ox, $oy) {
    function P($x, $y) { New-Object System.Drawing.PointF ($ox + $x * $scale), ($oy + $y * $scale) }
    # Cuerpo del calendario (rect redondeado 3.5..20.5 x 5..21, r=3)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $x = $ox + 3.5 * $scale; $y = $oy + 5 * $scale; $w = 17 * $scale; $h = 16 * $scale; $d = 6 * $scale
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $g.DrawPath($pen, $path)
    $g.DrawLine($pen, (P 3.5 10), (P 20.5 10))
    $g.DrawLine($pen, (P 8 3), (P 8 7))
    $g.DrawLine($pen, (P 16 3), (P 16 7))
    $g.DrawLines($pen, @((P 9 15.5), (P 11.2 17.7), (P 15.2 13.3)))
}

function Write-AppIcon($path, $size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.ColorTranslator]::FromHtml("#2F7D79"))
    # Glifo ocupando ~60% central (zona segura del maskable)
    $scale = ($size * 0.60) / 24.0
    $off = ($size - 24 * $scale) / 2
    $pen = New-Pen $size $scale 1.8 ([System.Drawing.ColorTranslator]::FromHtml("#F4F1EA"))
    Draw-Glyph $g $pen $scale $off $off
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host "Wrote $path ($size x $size)"
}

$root = Join-Path $PSScriptRoot ".."
$web = Join-Path $root "..\Tratamientos"
New-Item -ItemType Directory -Force -Path (Join-Path $root "assets") | Out-Null
Write-AppIcon (Join-Path $root "assets\icon.png") 1024
Write-AppIcon (Join-Path $web "icon-512.png") 512
Write-AppIcon (Join-Path $web "icon-192.png") 192
Write-AppIcon (Join-Path $web "icon-180.png") 180

$sizes = @{ "drawable-mdpi" = 24; "drawable-hdpi" = 36; "drawable-xhdpi" = 48; "drawable-xxhdpi" = 72; "drawable-xxxhdpi" = 96 }
$resRoot = Join-Path $root "android\app\src\main\res"
foreach ($dir in $sizes.Keys) {
    $size = $sizes[$dir]
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $scale = $size / 24.0
    $pen = New-Pen $size $scale 1.8 ([System.Drawing.Color]::White)
    Draw-Glyph $g $pen $scale 0 0
    $outDir = Join-Path $resRoot $dir
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $outPath = Join-Path $outDir "ic_stat_notify.png"
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host "Wrote $outPath ($size x $size)"
}
