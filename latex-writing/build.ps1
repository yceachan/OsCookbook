[CmdletBinding()]
param(
    [string]$Main = "main.tex",
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourcePath = Join-Path $projectDir $Main
$stem = [IO.Path]::GetFileNameWithoutExtension($Main)
$buildDir = Join-Path $projectDir "build"
$pdfDir = Join-Path $projectDir "output\pdf"
$pdfPath = Join-Path $pdfDir "$stem.pdf"
$miktexBin = Join-Path $env:LOCALAPPDATA "Programs\MiKTeX\miktex\bin\x64"

function Find-Tool {
    param([string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $fallback = Join-Path $miktexBin "$Name.exe"
    if (Test-Path -LiteralPath $fallback) { return $fallback }

    throw "$Name was not found. Restart the terminal or repair MiKTeX."
}

function Remove-RootAuxiliaryFiles {
    foreach ($extension in @(
        ".aux", ".bbl", ".bcf", ".blg", ".log", ".out",
        ".run.xml", ".synctex.gz", ".toc", ".pdf"
    )) {
        $path = Join-Path $projectDir "$stem$extension"
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}

if ($Clean) {
    Remove-RootAuxiliaryFiles
    foreach ($directory in @($buildDir, (Join-Path $projectDir "output"))) {
        if (Test-Path -LiteralPath $directory) {
            Remove-Item -LiteralPath $directory -Recurse -Force
        }
    }
    Write-Host "Generated files removed."
    exit 0
}

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Source file not found: $sourcePath"
}

$xelatex = Find-Tool "xelatex"
$biber = Find-Tool "biber"

Remove-RootAuxiliaryFiles
New-Item -ItemType Directory -Force -Path $buildDir, $pdfDir | Out-Null

$xelatexArguments = @(
    "-synctex=1",
    "-interaction=nonstopmode",
    "-file-line-error",
    "-aux-directory=$buildDir",
    "-output-directory=$pdfDir",
    $Main
)

Push-Location $projectDir
try {
    Write-Host "[1/4] XeLaTeX: collect structure and citation requests"
    & $xelatex @xelatexArguments
    if ($LASTEXITCODE -ne 0) { throw "Initial XeLaTeX pass failed." }

    $bcfPath = Join-Path $buildDir "$stem.bcf"
    if (Test-Path -LiteralPath $bcfPath) {
        Write-Host "[2/4] Biber: resolve bibliography"
        & $biber --input-directory=$buildDir --output-directory=$buildDir $stem
        if ($LASTEXITCODE -ne 0) { throw "Biber failed." }
    }
    else {
        Write-Host "[2/4] Biber: skipped (no .bcf file)"
    }

    Write-Host "[3/4] XeLaTeX: insert bibliography and references"
    & $xelatex @xelatexArguments
    if ($LASTEXITCODE -ne 0) { throw "Second XeLaTeX pass failed." }

    Write-Host "[4/4] XeLaTeX: stabilize labels, pages, and bookmarks"
    & $xelatex @xelatexArguments
    if ($LASTEXITCODE -ne 0) { throw "Final XeLaTeX pass failed." }

    if (-not (Test-Path -LiteralPath $pdfPath)) {
        throw "Build finished without producing $pdfPath"
    }
    Write-Host "PDF created: $pdfPath"
}
finally {
    Pop-Location
}
