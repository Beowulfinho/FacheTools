Add-Type -AssemblyName System.Drawing

# App icons (favicon/manifest/apple-touch), not the Android status-bar notification icon.
# Draws the same location-pin mark used in Lugares/index.html's header (a teardrop pin with a
# hollow dot), filled solid on the accent background, at every size the manifest/apple-touch-icon
# expect.
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
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    $u = $size / 24.0
    # Pin: "M12 21s-7-7.75-7-12.5A7 7 0 1119 8.5C19 13.25 12 21 12 21z" + circle at (12, 8.5) r=2.5
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc((5*$u), (1.5*$u), (14*$u), (14*$u), 180, 180)
    $path.AddLine(19*$u, 8.5*$u, 12*$u, 21*$u)
    $path.AddLine(12*$u, 21*$u, 5*$u, 8.5*$u)
    $path.CloseFigure()
    $g.DrawPath($pen, $path)
    $g.DrawEllipse($pen, 9.5*$u, 6*$u, 5*$u, 5*$u)

    $bmp.Save((Join-Path $outDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

Write-Host "Generated icons in $outDir"
