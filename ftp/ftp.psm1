Import-module "./utils.psm1"

$ProgressPreference = 'SilentlyContinue'
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

function ftpListDir {
    param($url)

    $list = [System.Collections.ArrayList]::New()
    $ftpMethod = [System.Net.WebRequestMethods+Ftp]::ListDirectory
    $ftpReq = [System.Net.FtpWebRequest]::Create($url)
    $ftpReq.Method = $ftpMethod
    
    $resp = $ftpReq.GetResponse()
    if($resp -eq $null) {
        Write-Error "ftpListDir failed at $url"
        return
    }

    $respStream = $resp.GetResponseStream()
    #Write-Output $resp
    $reader = New-Object System.IO.StreamReader($respStream)
    while (-not $reader.EndOfStream)
    {
        $line = $reader.ReadLine()
        $list.Add($line) | Out-Null
    }
    $reader.Close()
    $respStream.Close()
    $resp.Close()
    
    $list
}

function ftpListDirDetails {
    param($url)
    
    $list = [System.Collections.ArrayList]::New()
    $ftpMethod = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
    $ftpReq = [System.Net.FtpWebRequest]::Create($url)
    $ftpReq.Method = $ftpMethod
    
    $resp = $ftpReq.GetResponse()
    if($resp -eq $null) {
        Write-Error "ftpListDirDetails failed at $url"
        return
    }

    $respStream = $resp.GetResponseStream()

    $reader = New-Object System.IO.StreamReader($respStream)
    while (-not $reader.EndOfStream)
    {
        $line = $reader.ReadLine()
        $list.Add($line) | Out-Null
    }
    $reader.Close()
    $respStream.Close()
    $resp.Close()
    
    $list
}
function getFilename {
    param($url)

    ($url -split "/" | Select-Object -Last 1)
}
function ftpDownloadFile {
    param($url, $localFile= (GetFilename $url))
    $ftpMethod = [System.Net.WebRequestMethods+Ftp]::DownloadFile
    $ftpReq = [System.Net.FtpWebRequest]::Create($url)
    $ftpReq.Method = $ftpMethod

    $path = [System.IO.Path]::GetDirectoryName($localFile)
    if($path -eq $null) {
        Write-Error "Failed to get directory from $localFile"
        return
    }
    New-Item -Path $path -ItemType Directory -Force | Out-Null

    $resp = $ftpReq.GetResponse()
    if($resp -eq $null) {
        Write-Error "ftpDownloadFile failed to downloaded at $url"
        return
    }

    $respStream = $resp.GetResponseStream()
    $fileStream = [System.IO.File]::Create($localFile)
    $buffer = New-Object byte[] 1024
    do {
        $data_len = $respStream.Read($buffer,0,$buffer.Length)
        $fileStream.Write($buffer,0,$data_len)
    }
    while ($data_len -ne 0)
    if($fileStream -and $respStream -and $resp) { Write-Success "Downloaded: " $url}
    $fileStream.Close()
    $respStream.Close()
    $resp.Close()
}

function ftpFileSize {
    param($url)

    $list = [System.Collections.ArrayList]::New()
    $ftpMethod = [System.Net.WebRequestMethods+Ftp]::GetFileSize
    $ftpReq = [System.Net.FtpWebRequest]::Create($url)
    $ftpReq.Method = $ftpMethod
    
    $resp = $ftpReq.GetResponse()
    if($resp -eq $null) {
        Write-Error "ftpFileSize: Failed to get size at $url"
        return
    }
    $size = $resp.ContentLength
    $resp.Close()
    $size
}

Function DeGZip-File{
    Param(
        $infile,
        $outfile = ($infile -replace '\.gz$','')
        )
    $input = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
    $output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
    $gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)
    $buffer = New-Object byte[](1024)
    do {
        $data_len = $gzipStream.Read($buffer,0,$buffer.Length)
        $output.Write($buffer,0,$data_len)
    }
    while ($data_len -ne 0)
    $gzipStream.Close()
    $output.Close()
    $input.Close()
}