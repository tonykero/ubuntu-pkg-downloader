
Import-Module "./ubuntu-ftp-client.psm1"

$baseUrl = "ftp://ftp.ubuntu.com/ubuntu"
#ports
#$baseUrl = "ftp://ftp.ubuntu.com/ubuntu-ports"


#Get-Distribs $baseUrl

#Get-Sections $baseUrl

#Download-SourcesList $baseUrl "bionic" "main"
#Download-SourcesList $baseUrl "bionic" "multiverse"
#Download-SourcesList $baseUrl "bionic" "restricted"
#Download-SourcesList $baseUrl "bionic" "universe"

#Search-Source $baseUrl "bionic" "main" "gcc"

#Search-Binary $baseUrl "bionic" "main" "libgles"
#$r = (((Search-Binary $baseUrl "bionic" "main" "libgles") | Select-Object -ExpandProperty Line) -split ":")[0]
#Write-Output $r
#if($r -eq "Binary") { Write-Host "yes"}
#$list = Search-Binary $baseUrl "bionic" "main" "libgles"
#foreach($pkg in $list) {
#    Write-Output (Get-Package $pkg)
#}

Download-PackagesList $baseUrl "bionic" "main" "amd64"
$res = Search-Package $baseUrl "bionic" "main" "amd64" "libgl"

foreach($r in $res) {
    $pkg =  (Get-Package $r)
    $deps = (Get-PackageDeps "bionic" "main" "amd64" $pkg)

    Write-Output $pkg
    Write-Output $deps
}