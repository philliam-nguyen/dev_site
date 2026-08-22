<#
.SYNOPSIS
  Deploys site/dist to S3 and invalidates CloudFront, from a local AWS profile.

.DESCRIPTION
  The cache passes here mirror .github/workflows/deploy.yml. Change one,
  check the other.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Bucket,
    [Parameter(Mandatory)][string]$DistributionId,
    [string]$Profile = $env:AWS_PROFILE
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $repoRoot 'site')

try {
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "build failed with exit code $LASTEXITCODE" }

    $common = @('--profile', $Profile)

    Write-Host 'Pass 1: hashed assets'
    aws s3 sync dist "s3://$Bucket" --delete `
        --cache-control 'public,max-age=31536000,immutable' `
        --exclude '*.html' --exclude 'favicon.svg' --exclude 'fonts/*' @common
    if ($LASTEXITCODE -ne 0) { throw "pass 1 failed with exit code $LASTEXITCODE" }

    Write-Host 'Pass 2: unhashed assets'
    aws s3 sync dist "s3://$Bucket" `
        --cache-control 'public,max-age=86400' `
        --exclude '*' --include 'favicon.svg' --include 'fonts/*' @common
    if ($LASTEXITCODE -ne 0) { throw "pass 2 failed with exit code $LASTEXITCODE" }

    Write-Host 'Pass 3: HTML'
    aws s3 sync dist "s3://$Bucket" `
        --cache-control 'public,max-age=0,must-revalidate' `
        --exclude '*' --include '*.html' @common
    if ($LASTEXITCODE -ne 0) { throw "pass 3 failed with exit code $LASTEXITCODE" }

    Write-Host 'Invalidating'
    aws cloudfront create-invalidation --distribution-id $DistributionId --paths '/*' @common
    if ($LASTEXITCODE -ne 0) { throw "invalidation failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}
