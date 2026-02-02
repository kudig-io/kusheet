# File validation script
Write-Host "=== README Link Validation ===" -ForegroundColor Green

$files = @(
    "README.md",
    "topic-presentations/kubernetes-coredns-presentation.md",
    "topic-presentations/kubernetes-ingress-presentation.md",
    "topic-presentations/kubernetes-service-presentation.md", 
    "topic-presentations/kubernetes-storage-presentation.md",
    "topic-presentations/kubernetes-terway-presentation.md",
    "topic-presentations/kubernetes-workload-presentation.md"
)

$validCount = 0
$totalCount = $files.Length

foreach ($file in $files) {
    if (Test-Path $file) {
        $info = Get-Item $file
        Write-Host "OK: $file (Size: $($info.Length) bytes)" -ForegroundColor Green
        $validCount++
    } else {
        Write-Host "ERROR: $file not found" -ForegroundColor Red
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total files: $totalCount"
Write-Host "Valid files: $validCount" 
Write-Host "Invalid files: $($totalCount - $validCount)"

if ($validCount -eq $totalCount) {
    Write-Host "SUCCESS: All links are valid!" -ForegroundColor Green
} else {
    Write-Host "WARNING: Some links are invalid!" -ForegroundColor Yellow
}