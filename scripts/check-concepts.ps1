# Check technical terms completeness in concept.md

# Get existing terms from concept.md
$conceptTerms = Select-String -Path "reference\concept.md" -Pattern "### (.*)" | 
    ForEach-Object { $_.Matches.Groups[1].Value.Trim() } | 
    Where-Object { $_ -notmatch "^(Official Docs|Academic Resources|Community Resources)$" }

Write-Host "Loaded $(($conceptTerms | Measure-Object).Count) technical terms" -ForegroundColor Green

# Common words that don't need explanation
$commonWords = @(
    "Kubernetes", "API", "HTTP", "HTTPS", "JSON", "YAML", "CPU", "GPU", "RAM", "Disk",
    "Linux", "Windows", "Docker", "Container", "Image", "Registry", "Repository",
    "Version", "Release", "Update", "Install", "Configure", "Setup", "Deploy",
    "Run", "Start", "Stop", "Restart", "Delete", "Remove", "Clean", "Backup"
)

# Get all markdown files
$mdFiles = Get-ChildItem -Recurse -Include "*.md" | Where-Object { $_.FullName -notlike "*reference*" }

Write-Host "Found $(($mdFiles | Measure-Object).Count) markdown files to check" -ForegroundColor Yellow

# Store missing concepts
$missingConcepts = @{}

foreach ($file in $mdFiles) {
    Write-Host "Checking file: $($file.Name)" -ForegroundColor Cyan
    
    $content = Get-Content $file.FullName -Raw
    
    # Extract potential technical terms (words starting with capital letters)
    $potentialTerms = [regex]::Matches($content, '\b[A-Z][a-zA-Z]*(?:\s+[A-Z][a-zA-Z]*)*\b') | 
        ForEach-Object { $_.Value.Trim() } |
        Where-Object { 
            $_.Length -gt 2 -and 
            $_ -notin $commonWords -and
            $_ -notin $conceptTerms -and
            $_ -notmatch '^\d+$' -and
            $_ -notmatch '^[A-Z]{2,}$'
        } |
        Sort-Object -Unique
    
    if ($potentialTerms.Count -gt 0) {
        $missingConcepts[$file.Name] = $potentialTerms
        Write-Host "  Found $($potentialTerms.Count) potential missing terms" -ForegroundColor Red
    }
}

# Output results
Write-Host "`n=== Check Complete ===" -ForegroundColor Green
$totalMissing = (($missingConcepts.Values | ForEach-Object { $_.Count }) | Measure-Object -Sum).Sum
Write-Host "Total potential missing terms: $totalMissing" -ForegroundColor Yellow

if ($missingConcepts.Count -gt 0) {
    Write-Host "`n=== Detailed Report ===" -ForegroundColor Cyan
    foreach ($file in $missingConcepts.Keys) {
        Write-Host "`nFile: $file" -ForegroundColor White
        $missingConcepts[$file] | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} else {
    Write-Host "Great! All technical terms are explained in concept.md" -ForegroundColor Green
}