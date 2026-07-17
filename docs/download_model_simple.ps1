# Simple Model Downloader for CHW Augment
# Navigate to models directory
$modelsDir = "C:\Users\eugene.ogembo\Documents\Projects\Augment-CHWs\assets\ai_models"

if (!(Test-Path $modelsDir)) {
    New-Item -ItemType Directory -Path $modelsDir -Force | Out-Null
    Write-Host "Created models directory" -ForegroundColor Green
}

Set-Location $modelsDir
Write-Host ""
Write-Host "CHW Augment - Model Downloader" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Available Models:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1 - Phi-3.5 Mini (2.39 GB) RECOMMENDED" -ForegroundColor Green
Write-Host "2 - Qwen2.5-1.5B (1.89 GB) Lightweight" -ForegroundColor Yellow
Write-Host "3 - MedGemma 4B (2.31 GB) High quality" -ForegroundColor Cyan
Write-Host ""

$choice = Read-Host "Enter your choice (1-3)"

$models = @{
    "1" = @{
        url = "https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf"
        filename = "phi-3.5-mini-instruct-Q4_K_M.gguf"
        name = "Phi-3.5 Mini"
    }
    "2" = @{
        url = "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q8_0.gguf"
        filename = "qwen2.5-1.5b-instruct-q8_0.gguf"
        name = "Qwen2.5-1.5B"
    }
    "3" = @{
        url = "https://huggingface.co/Fadhili254/medgemma-4b-it-q4_k_m.gguf/resolve/main/medgemma-4b-it-q4_k_m.gguf"
        filename = "medgemma-4b-it-q4_k_m.gguf"
        name = "MedGemma 4B"
    }
}

if ($models.ContainsKey($choice)) {
    $model = $models[$choice]
    Write-Host ""
    Write-Host "Downloading: $($model.name)" -ForegroundColor Cyan
    Write-Host "File: $($model.filename)" -ForegroundColor Gray
    Write-Host "This may take 5-10 minutes..." -ForegroundColor Yellow
    Write-Host ""
    
    try {
        curl.exe -L -o $model.filename --progress-bar $model.url
        
        if (Test-Path $model.filename) {
            $sizeMB = [math]::Round((Get-Item $model.filename).Length / 1MB, 2)
            Write-Host ""
            Write-Host "SUCCESS! Downloaded $sizeMB MB" -ForegroundColor Green
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Cyan
            Write-Host "1. Run: flutter run" -ForegroundColor White
            Write-Host "2. In app, switch to Offline Mode" -ForegroundColor White
            Write-Host "3. Select your model" -ForegroundColor White
            Write-Host ""
        }
    } catch {
        Write-Host ""
        Write-Host "ERROR: Download failed - $_" -ForegroundColor Red
    }
} else {
    Write-Host "Invalid choice!" -ForegroundColor Red
}

Write-Host ""
Write-Host "Downloaded models in this directory:" -ForegroundColor Cyan
Get-ChildItem -Filter *.gguf | ForEach-Object {
    $sizeMB = [math]::Round($_.Length / 1MB, 2)
    Write-Host "  $($_.Name) - $sizeMB MB" -ForegroundColor Green
}
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
