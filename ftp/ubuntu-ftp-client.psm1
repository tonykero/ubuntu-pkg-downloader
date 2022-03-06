Import-module "./ftp.psm1"

function Get-Distribs {
    param($baseUrl)

    (ftpListDir ($baseUrl + "/dists/"))
}

function Get-Sections {
    param($baseUrl)

    (ftpListDir ($baseUrl + "/pool/"))
}

function Download-Sources {
    param($baseUrl, $distrib, $section)

    $path = "/dists/$distrib/$section/source"
    $fullpath = $path + "/Sources.gz"
    $url = $baseUrl + $fullpath
    New-Item -Path ("." + $path) -ItemType Directory -Force
    
    (ftpDownloadFile $url ("." + $fullpath))
    DeGZip-File ("." + $fullpath)
}

function Search-Package {
    param($baseUrl, $distrib, $section, $keyword)

    $path = "./dists/$distrib/$section/source/Sources"

    Select-String $path -Pattern $keyword -SimpleMatch |
    Select-String -Pattern "Package: " | 
    Select-Object @{Name = 'Filename'; Expression = {$path}}, LineNumber, @{Name = 'Name'; Expression = {($_.Line -split ' ')[1]}}
}

function Search-Binary {
    param($baseUrl, $distrib, $section, $keyword)

    $path = "./dists/$distrib/$section/source/Sources"

    $res = Select-String $path -Pattern $keyword -SimpleMatch |
    Select-Object @{Name = 'Filename'; Expression = {$path}}, LineNumber, Line

    $content = Get-Content $path
    $candidates = [System.Collections.ArrayList]::new()
    foreach($mi in $res) {
        if((-not ($mi.Line.Contains(':'))) -and (-not ($mi.Line.Contains(','))) -and ($mi.Line.Contains(' '))) {
            continue
        }
        # might be in Binary field
        # go up until we reach a field
        $lineNumber = $mi.LineNumber
        do {
            $str = $content | Select -First 1 -Skip ($lineNumber - 1)
            $arr = $str -split ':'
            $lineNumber = $LineNumber - 1
        } while(-not ($arr.length -eq 2))
        
        if($arr[0] -eq "Binary") {
            # go up until we reach the package field
            do {
                $str = $content | Select -First 1 -Skip ($lineNumber - 1)
                $arr = $str -split ':'
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

    return @{
        Name            = $mi.Name
        Architecture    = Get-FieldFromPkg $mi "Architecture"
        Version         = Get-FieldFromPkg $mi "Version"
        Directory       = Get-FieldFromPkg $mi "Directory"
    }
}

function Get-FieldFromPkg {
    param($mi, $field)
    $content = Get-Content $mi.Filename
    $lineNumber = $mi.LineNumber
    do {
        $str = $content | Select -First 1 -Skip ($lineNumber - 1)
        $arr = $str -split ':'
        $lineNumber = $LineNumber + 1
    } while(-not ($arr[0] -Like $field))
    $arr[1].Trim()
}