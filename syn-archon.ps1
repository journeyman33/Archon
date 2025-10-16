Write-Host "Fetching latest updates from upstream..."
git fetch upstream

Write-Host "Merging upstream/stable into local stable..."
git checkout stable
git merge upstream/stable

Write-Host "Pushing updates to your fork..."
git push origin stable

Write-Host "✅ Archon fork is now synced with upstream!"

