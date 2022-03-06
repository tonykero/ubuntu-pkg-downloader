
Import-Module "./ubuntu-ftp-client.psm1"

$baseUrl = "ftp://ftp.ubuntu.com/ubuntu"
#ports
#$baseUrl = "ftp://ftp.ubuntu.com/ubuntu-ports"


#Get-Distribs $baseUrl

#Get-Sections $baseUrl

#Download-Sources $baseUrl "bionic" "main"
#Download-Sources $baseUrl "bionic" "multiverse"
#Download-Sources $baseUrl "bionic" "restricted"
#Download-Sources $baseUrl "bionic" "universe"

#Search-Package $baseUrl "bionic" "main" "gcc"

#Search-Binary $baseUrl "bionic" "main" "libgles"
#$r = (((Search-Binary $baseUrl "bionic" "main" "libgles") | Select-Object -ExpandProperty Line) -split ":")[0]
#Write-Output $r
#if($r -eq "Binary") { Write-Host "yes"}
$list = Search-Binary $baseUrl "bionic" "main" "libgles"
foreach($pkg in $list) {
    Write-Output (Get-Package $pkg)
}