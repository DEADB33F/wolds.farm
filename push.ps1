Write-Host "Current Directory: $((Get-Location).Path)" -ForegroundColor Yellow
$untrackedFiles = git ls-files --others --exclude-standard
Write-Host "Found $($untrackedFiles.Count) files to upload." -ForegroundColor Yellow

if ($untrackedFiles.Count -eq 0) {
    Write-Host "No files left to process! Your repository is up to date." -ForegroundColor Green
    return
}

# Target 50MB batches to keep network strain low
$maxBatchSize = 50 * 1024 * 1024
$currentBatchSize = 0
$filesToCommit = New-Object System.Collections.Generic.List[string]
$batchCount = 1

foreach ($file in $untrackedFiles) {
    $absolutePath = Join-Path (Get-Location).Path $file
    
    if (Test-Path $absolutePath) {
        $fileSize = (Get-Item $absolutePath).Length
        
        # If adding this file pushes us past 50MB, ship the current batch immediately
        if (($currentBatchSize + $fileSize) -gt $maxBatchSize -and $filesToCommit.Count -gt 0) {
            Write-Host "--- Uploading Batch $batchCount ($([math]::Round($currentBatchSize / 1MB, 2)) MB) ---" -ForegroundColor Cyan
            
            # Stage, commit, and immediately push this specific batch
            foreach ($f in $filesToCommit) { git add $f }
            git commit -m "Upload batch $batchCount" --quiet
            git push origin main
            
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Push failed! The network dropped. Run the script again to resume." -ErrorAction Stop
            }
            
            # Clear out the batch queue for the next set of files
            $filesToCommit.Clear()
            $currentBatchSize = 0
            $batchCount++
        }
        
        $filesToCommit.Add($file)
        $currentBatchSize += $fileSize
    }
}

# Final batch loop for any leftover files
if ($filesToCommit.Count -gt 0) {
    Write-Host "--- Uploading Final Batch $batchCount ($([math]::Round($currentBatchSize / 1MB, 2)) MB) ---" -ForegroundColor Cyan
    foreach ($f in $filesToCommit) { git add $f }
    git commit -m "Upload batch $batchCount" --quiet
    git push origin main
}