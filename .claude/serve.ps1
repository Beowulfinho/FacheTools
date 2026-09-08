param(
    [int]$Port = 8080,
    [string]$Root = (Join-Path $PSScriptRoot "..")
)

$Root = (Resolve-Path $Root).Path
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $Root on http://localhost:$Port/"

$mime = @{
    ".html" = "text/html"; ".htm" = "text/html"; ".js" = "application/javascript"
    ".css" = "text/css"; ".json" = "application/json"; ".png" = "image/png"
    ".jpg" = "image/jpeg"; ".jpeg" = "image/jpeg"; ".svg" = "image/svg+xml"
    ".ico" = "image/x-icon"
}

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $req = $context.Request
    $res = $context.Response
    try {
        $relPath = [Uri]::UnescapeDataString($req.Url.AbsolutePath.TrimStart('/'))
        if ([string]::IsNullOrWhiteSpace($relPath)) { $relPath = "index.html" }
        $filePath = Join-Path $Root $relPath
        $fullPath = [System.IO.Path]::GetFullPath($filePath)
        if (-not $fullPath.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) {
            $res.StatusCode = 403
        } elseif (Test-Path $fullPath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($fullPath).ToLower()
            $contentType = $mime[$ext]
            if (-not $contentType) { $contentType = "application/octet-stream" }
            $bytes = [System.IO.File]::ReadAllBytes($fullPath)
            $res.ContentType = $contentType
            $res.ContentLength64 = $bytes.Length
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $res.StatusCode = 404
            $msg = [System.Text.Encoding]::UTF8.GetBytes("Not found: $relPath")
            $res.OutputStream.Write($msg, 0, $msg.Length)
        }
    } catch {
        $res.StatusCode = 500
    } finally {
        $res.OutputStream.Close()
    }
}
