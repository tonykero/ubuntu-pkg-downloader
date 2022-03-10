function Get-Line {
    param($path, $index)

    if([String]::isNullOrEmpty($path)) {
        Write-Error "Get-Line: given path is null"
        return
    }

    #([System.IO.File]::ReadAllLines($path ))[$index]
    [Linq.Enumerable]::ElementAt([System.IO.File]::ReadLines($path), $index)
}

function Check-FileSize {
    param($path, $size)

    if(Test-Path $path -PathType Leaf) {
        if((Get-Item $path).Length -eq $size) {
            $true
        }
    }
    $false
}


function Write-Info {
    Write-Host $args
}
function Write-Success {
    Write-Host $args -ForegroundColor green
}
function Write-Warning {
    Write-Host $args -ForegroundColor yellow
}
function Write-Error {
    Write-Host $args -ForegroundColor red
}