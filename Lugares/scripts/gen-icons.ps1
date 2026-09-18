Add-Type -AssemblyName System.Drawing

# App icons (favicon/manifest/apple-touch), not the Android status-bar notification icon.
# Draws the same fork+plate mark used in Lugares/index.html's header, filled solid (not a
# silhouette) on the accent background, at every size the manifest/apple-touch-icon expect.
$sizes = @{
    "icon-180.png" = 180
    "icon-192.png" = 192
    "icon-512.png" = 512
}

$bg = [System.Drawing.Color]::FromArgb(255, 0x3F, 0x7A, 0x5C)
$fg = [System.Drawing.Color]::FromArgb(255, 0xF5, 0xF1, 0xE8)

$outDir = $PSScriptRoot | Split-Path -Parent

foreach ($name in $sizes.Keys) {
    $size = $sizes[$name]
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear($bg)

    $stroke = [Math]::Round($size * 0.062)
    $pen = New-Object System.Drawing.Pen $fg, $stroke
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    $u = $size / 24.0
    # Fork: two tines + shaft (path "M8 3v7a2.5 2.5 0 005 0V3" + "M10.5 10v11")
    $g.DrawLine($pen, 8*$u, 3*$u, 8*$u, 10*$u)
    $g.DrawLine($pen, 13*$u, 3*$u, 13*$u, 10*$u)
    $g.DrawArc($pen, (8*$u), (7.5*$u), (5*$u), (5*$u), 0, 180)
    $g.DrawLine($pen, 10.5*$u, 10*$u, 10.5*$u, 21*$u)
    # Spoon-ish knife: "M17 3c-1.7 0-3 2-3 5.5S15.3 14 17 14v8"
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddBezier(17*$u, 3*$u,  15.3*$u, 3*$u,  14*$u, 5*$u,  14*$u, 8.5*$u)
    $path.AddBezier(14*$u, 8.5*$u, 14*$u, 12*$u, 15.3*$u, 14*$u, 17*$u, 14*$u)
    $g.DrawPath($pen, $path)
    $g.DrawLine($pen, 17*$u, 14*$u, 17*$u, 22*$u)

    $bmp.Save((Join-Path $outDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

Write-Host "Generated icons in $outDir"
