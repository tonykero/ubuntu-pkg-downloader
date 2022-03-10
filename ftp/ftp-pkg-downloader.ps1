
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
$res = Search-Package "bionic" "main" "amd64" "openssh-server" $true

#foreach($r in $res) {
#    $pkg =  (Get-Package $r)
#    $deps = (Get-PackageDeps "bionic" "main" $pkg)

#    Write-Output $pkg
#    Write-Output $deps
#    Write-Output $pkg.Architecture
#    Write-Output "----"

#    foreach($dep in $deps) {
#        Write-Output (Search-Dependency "bionic" "main" $dep)
#    }
#}

#Search-VirtualPackage "bionic" "main" "amd64" "perlapi-5.26.0"

$pkg = (Get-Package $res)
$all_deps = New-Object System.Collections.Generic.List[string]
$link_paths = GetDepsLinks_rec "bionic" "main" $pkg $all_deps
foreach($link in $link_paths) {
    $fname = GetFilename $link
    $path = "./tmp/" + $fname
    $url = "$baseUrl/$link"
    $size = ftpFileSize $url
    if(-not (Check-FileSize $path $size)) {
        ftpDownloadFile $url $path
    } else {
        Write-Host "Already downloaded: $path"
    }
}
