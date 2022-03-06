$ProgressPreference = 'SilentlyContinue'
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

function ftpListDir {
    param($url)

    $list = [System.Collections.ArrayList]::New()
    $ftpMethod = [System.Net.WebRequestMethods+Ftp]::ListDirectory
    $ftpReq = [System.Net.FtpWebRequest]::Create($url)
    $ftpReq.Method = $ftpMethod
    
    $resp = $ftpReq.GetResponse()
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

function ftpDownloadFile {
    param($url, $localFile= ($url -split "/" | Select-Object -Last 1))
    $ftpMethod = [System.Net.WebRequestMethods+Ftp]::DownloadFile
    $ftpReq = [System.Net.FtpWebRequest]::Create($url)
    $ftpReq.Method = $ftpMethod

    $resp = $ftpReq.GetResponse()
    $respStream = $resp.GetResponseStream()
    $fileStream = [System.IO.File]::Create($localFile)
    $buffer = New-Object byte[] 1024
    
    do {
        $data_len = $respStream.Read($buffer,0,$buffer.Length)
        $fileStream.Write($buffer,0,$data_len)
    }
    while ($data_len -ne 0)
    $fileStream.Close()
    $respStream.Close()
    $resp.Close()
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