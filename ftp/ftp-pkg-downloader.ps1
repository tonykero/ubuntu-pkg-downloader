
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

$distrib = "bionic"
$section = "main"
$arch = "amd64"
Download-PackagesList $baseUrl $distrib $section $arch

$res = Search-Package $distrib $section $arch "libgles2-mesa-dev" $true
Write-Info $res

$pkg = (Get-Package $res)
Write-Info $pkg
$name = $pkg.Name
$all_deps = New-Object System.Collections.Generic.SortedSet[string]
$exclude = New-Object System.Collections.Generic.List[string]

$all_deps = (GetDepsLinks_rec $distrib $section $pkg $all_deps $exclude $arch) | Sort-Object | Get-Unique
foreach($link in $all_deps) {
    $fname = GetFilename $link
    $path = "./$name/" + $fname
    $url = "$baseUrl/$link"
    $size = ftpFileSize $url
    if(-not (Check-FileSize $path $size)) {
        ftpDownloadFile $url $path
    } else {
        Write-Info "Already downloaded: $path"
    }
}
