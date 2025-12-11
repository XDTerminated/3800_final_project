$nasmPath = "C:\Users\sgupt\AppData\Local\bin\NASM\nasm.exe"
$qemuPath = "C:\Program Files\qemu\qemu-system-x86_64.exe"
$asmFile = "bootloader.asm"
$binFile = "bootloader.bin"

if (-Not (Test-Path $asmFile)) {
    Write-Host "Error: $asmFile not found!" -ForegroundColor Red
    Write-Host "Make sure you're in the correct directory." -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "Assembling $asmFile..." -ForegroundColor Yellow
& $nasmPath -f bin $asmFile -o $binFile

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Assembly failed!" -ForegroundColor Red
    pause
    exit 1
}

if (-Not (Test-Path $binFile)) {
    Write-Host ""
    Write-Host "Error: $binFile was not created!" -ForegroundColor Red
    pause
    exit 1
}

$fileSize = (Get-Item $binFile).Length
Write-Host "Assembly successful! Binary size: $fileSize bytes" -ForegroundColor Green

if ($fileSize -ne 512) {
    Write-Host "Warning: Bootloader should be exactly 512 bytes!" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Starting QEMU..." -ForegroundColor Yellow
Write-Host "(Close the QEMU window when done)" -ForegroundColor Cyan
Write-Host ""

& $qemuPath -drive format=raw,file=$binFile

Write-Host ""
Write-Host "Done!" -ForegroundColor Green