Import-module "./ftp.psm1"
Import-module "./utils.psm1"

function Get-Distribs {
    param($baseUrl)

    (ftpListDir ($baseUrl + "/dists/"))
}

function Get-Sections {
    param($baseUrl)

    (ftpListDir ($baseUrl + "/pool/"))
}

function Download-SourcesList {
    param($baseUrl, $distrib, $section)

    $path = "/dists/$distrib/$section/source"
    $fullpath = $path + "/Sources.gz"
    $url = $baseUrl + $fullpath
    New-Item -Path ("." + $path) -ItemType Directory -Force | Out-Null
    
    $size = (ftpFileSize $url)
    $filepath = ("." + $fullpath)
    if(-not (Check-FileSize $filepath $size)) {
        Write-Info "Downloading: $url"
        (ftpDownloadFile $url $filepath)
        DeGZip-File $filepath    
    } else {
        Write-Info "Already downloaded: $filepath"
    }
}

function Download-PackagesList {
    param($baseUrl, $distrib, $section, $arch)

    $path = "/dists/$distrib/$section/binary-$arch"
    $fullpath = $path + "/Packages.gz"
    $url = $baseUrl + $fullpath
    New-Item -Path ("." + $path) -ItemType Directory -Force | Out-Null
    
    $size = (ftpFileSize $url)
    $filepath = ("." + $fullpath)
    if(-not (Check-FileSize $filepath $size)) {
        Write-Info "Downloading: $url"
        (ftpDownloadFile $url $filepath)
        DeGZip-File $filepath    
    } else {
        Write-Info "Already downloaded: $filepath"
    }
}

function Search-Source {
    param($baseUrl, $distrib, $section, $keyword)

    $path = "./dists/$distrib/$section/source/Sources"

    Select-String $path -Pattern $keyword -SimpleMatch |
    Select-String -Pattern "Package: " | 
    Select-Object @{Name = 'Filename'; Expression = {$path}}, LineNumber, @{Name = 'Name'; Expression = {($_.Line -split ' ')[1]}}
}

$global:cache_pkg_line = @{}
function Search-Package {
    param($distrib, $section, $arch, $keyword, $exact = $false)

    $path = "./dists/$distrib/$section/binary-$arch/Packages"
    if(-not ($cache_pkg_line.keys -contains $path)) {
        $cache_pkg_line[$path] = @{}
        if(-not ($cache_pkg.keys -contains $path)) {
            $cache_pkg[$path] = [System.IO.File]::ReadLines($path)
        }
        $cache_pkg[$path] | Select-String -Pattern "Package: " -SimpleMatch |
                            Select-Object @{Name = 'Filename'; Expression = {$path}}, LineNumber, @{Name = 'Name'; Expression = {($_.Line -split ' ')[1]}} |
                            ForEach-Object {$cache_pkg_line[$path][$_.Name] = $_}
    }
    
    $res = $cache_pkg_line[$path][$keyword]
    
    if($exact) {
        return ($res | Where-Object {$_.Name -eq $keyword})
    }
    $res
}

function Search-VirtualPackage {
    param($distrib, $section, $arch, $keyword)
    $path = "./dists/$distrib/$section/binary-$arch/Packages"

    $term = $keyword
    $res = Select-String $path -Pattern "Provides: " -SimpleMatch |
            Select-String -Pattern $term -SimpleMatch | 
            Select-Object @{Name = 'Filename'; Expression = {$path}},
                            LineNumber,
                            @{Name = 'Name'; Expression = {
                                (((($_.Line -split ":")[1]) -split ",").Trim()) -eq $term
                            }}
    if($res -eq $null) {
        Write-Error "Virtual package: " $term " Not found"
        return 
     }
    Write-Info $term
    $lineNumber = $res.LineNumber
    do {
        $str = Get-Line $path $lineNumber
        $arr = $str -split ': '
        $lineNumber = $lineNumber - 1
    } while(-not ($arr[0] -eq "Package"))
    
    Search-Package $distrib $section $arch $arr[1] $true
}

function Search-Binary {
    param($distrib, $section, $keyword)

    $path = "./dists/$distrib/$section/source/Sources"

    $res = Select-String $path -Pattern $keyword -SimpleMatch |
    Select-Object @{Name = 'Filename'; Expression = {$path}}, LineNumber, Line

    #$content = Get-Content $path
    $candidates = [System.Collections.ArrayList]::new()
    foreach($mi in $res) {
        if((-not ($mi.Line.Contains(': '))) -and (-not ($mi.Line.Contains(','))) -and ($mi.Line.Contains(' '))) {
            continue
        }
        # might be in Binary field
        # go up until we reach a field
        $lineNumber = $mi.LineNumber
        do {
            $str = Get-Line $path $lineNumber
            $arr = $str -split ': '
            $lineNumber = $LineNumber - 1
        } while(-not ($arr.length -eq 2))
        
        if($arr[0] -eq "Binary") {
            # go up until we reach the package field
            do {
                $str = Get-Line $path $lineNumber
                $arr = $str -split ': '
                $lineNumber = $LineNumber - 1
            } while(-not ($arr[0] -eq "Package"))
            $candidates.Add($str) | Out-Null
        }
    }
    $candidates = $candidates | Sort-Object | Get-Unique

    $ret = [System.Collections.ArrayList]::new()
    foreach($pkgName in $candidates) {
        $mi = Select-String $path -Pattern $pkgName -SimpleMatch
        $ret.Add($mi) | Out-Null
    }

    $ret | Select-Object @{Name = 'Filename'; Expression = {$path}}, LineNumber, @{Name = 'Name'; Expression = {($_.Line -split ' ')[1]}}
}

function Get-Package {
    param([Parameter(ValueFromPipeline)]$mi)

    $ver = (Get-FieldFromPkg $mi "Version")
    $split = ($ver -split ":")
    if($split.Length -gt 1) {$ver = $split[1]}

    $obj = @{
        Name            = $mi.Name
        Architecture    = Get-FieldFromPkg $mi "Architecture"
        Version         = $ver
        Filename        = Get-FieldFromPkg $mi "Filename"
        Depends         = Get-FieldFromPkg $mi "Depends"
        Description         = Get-FieldFromPkg $mi "Description"
    }
    $predep = Get-FieldFromPkg $mi "Pre-Depends"
    if(-not [string]::IsNullOrEmpty($predep)) {
        $depStr = $obj.Depends
        $obj.Depends = "$depStr,$predep"
        if([string]::IsNullOrEmpty($depStr)) {
            $obj.Depends = $predep
        }
    }
    New-Object PSObject -Property $obj
}

function Get-PackageDeps {
    param($distrib, $section, $pkg)

    $arch = $pkg.Architecture

    $depsStr = $pkg.Depends
    $deps = ($depsStr -split ",") | Select-Object    @{Name = 'Name'; Expression = {($_.Trim() -split " ")[0]}},
                                                    @{Name = 'Requirement'; Expression = {($_ -split " ")[1].Replace('(','')}},
                                                    @{Name = 'Version'; Expression = {($_ -split " ")[2].Replace(')','') }}
    
    $deps = $deps | Select-Object Name,
                                @{Name = 'Architecture'; Expression = {$arch.Trim()}},
                                @{Name = 'Requirement'; Expression = {if ($_.Requirement -eq '|') {''} else {$_.Requirement} }},
                                @{Name = 'Version'; Expression = {if ($_.Requirement -eq '|') {''} else {$_.Version} }}
    $deps
}

function Get-FieldFromPkg {
    param($mi, $field)
    $lineNumber = $mi.LineNumber
    do {
        $str = Get-Line $mi.Filename $lineNumber #$content | Select-Object -First 1 -Skip ($lineNumber - 1)
        $arr = $str -split ': '
        $lineNumber = $LineNumber + 1
    } while(-not (($arr[0] -Like $field) -or ($arr[0] -eq "Package")))
    if(-not ($arr[0] -eq $field)) { return }  

    $arr[1].Trim()
}

function Search-Dependency {
    param($distrib, $section, $dep, $arch_default = "amd64")

    #Write-Host "Search-Dependency:" + (@($distrib,$section) -join ",")
    $arch = $dep.Architecture
    if($arch -eq "all") {
        $arch = $arch_default
    }
    $pkg = Search-Package $distrib $section ($arch) ($dep.Name) $true
    if($pkg -eq $null) {
        $pkg = (Search-VirtualPackage $distrib $section ($arch) $dep.Name)
        if($pkg -eq $null) {
            Write-Error "Error: " $dep.Name "Not found"
            return
        }
    }
    $pkg = (Get-Package $pkg)
    Write-Info "Found " $pkg.Name
    
    $version    = $pkg.Version
    if($dep.Requirement -eq "=") {
        Write-Warning "Enforcing" $pkg.Name "version: $version"
        $pkg.Version = $version
        
        $name       = $pkg.Name
        $arch       = $pkg.Architecture
        $_fname     =  (@($name,$version,$arch) -join "_") + ".deb"
        $split_fname= ($pkg.Filename -split '/')
        $split_fname[$split_fname.Length - 1] = $_fname
        $pkg.Filename = $split_fname -join "/"
    }
    $pkg
}

function GetDepsLinks_rec {
    param($distrib, $section, $pkg ,$all_deps, $exclude=@(), $arch_default = "amd64")

    
    if(-not ($all_deps -contains $pkg.Filename)) {
        $all_deps.Add($pkg.Filename) | Out-Null
    }

    $deps = (Get-PackageDeps $distrib $section $pkg)

    foreach($dep in $deps) {
        $dep_pkg = (Search-Dependency $distrib $section $dep $arch_default)
        if($dep_pkg -eq $null) {
            continue
        }
        if(($all_deps -contains $dep_pkg.Filename)) {
            Write-Info "Already planned: " $dep_pkg.Filename
            continue
        }
        if($exclude -contains $dep.Name) {
            Write-Info "Excluded: " $dep.Name
            continue
        }
        if($dep_pkg.Architecture -eq "all") { $dep_pkg.Architecture = $arch_default}
        
        $all_deps.Add($dep_pkg.Filename) | Out-Null
        $sub_deps = (GetDepsLinks_rec $distrib $section $dep_pkg $all_deps $exclude $arch_default)
        foreach($dep_link in $sub_deps) {
            $all_deps.Add($dep_link) | Out-Null
        }
        Write-Success "Added " $dep_pkg.Name
    }
    $ret = ($all_deps)# | Sort-Object | Get-Unique)
    Write-Success "Added dependencies of" $pkg.Name
    $ret
}

