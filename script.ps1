Import-Module ./gui.psm1

$ProgressPreference = 'SilentlyContinue'

$baseUrl = "https://packages.ubuntu.com"

$searchUrl = $baseUrl + "/en/"

$response = Invoke-WebRequest -Uri $searchUrl
if(-not $response) { Write-Host "Invoke-WebRequest failed.";exit}
# keywords (30 max), searchon(vals), exact(bool), suite(vals), section(vals)
$searchon_vals = [string[]]($response.InputFields | Where-Object name -eq "searchon" | Select-Object -ExpandProperty value)

# return list of values from select object (System.__ComObject)
function get_select_vals {
    param($select)
    $lst = New-Object System.Collections.Generic.List[System.__ComObject]
    for($i=0; $i -lt $select.children.length; $i++) { $lst.Add($select.children[$i]) }
    ($lst | Select-Object -ExpandProperty value)
}
$distro_vals = get_select_vals ($response.ParsedHtml.getElementsByTagName('select') | Where-Object name -eq "suite" | Select-Object -First 1)
$section_vals = get_select_vals ($response.ParsedHtml.getElementsByTagName('select') | Where-Object name -eq "section")

$searchRequest = showParamsDialog $searchon_vals $distro_vals $section_vals

if ([string]::IsNullOrEmpty($searchRequest)) {exit}

$reqUrl = $searchUrl + $searchRequest

Write-Output $reqUrl

[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
$response = Invoke-WebRequest -Uri $reqUrl
if(-not $response) { Write-Host "Invoke-WebRequest failed.";exit}
$links = $response.Links | Where-Object class -eq "resultlink" | Select-Object -ExpandProperty href

function getPackageDeps {
    param($packageUrl)
    Write-Host ("checking: " + $packageUrl)
    $deps = New-Object System.Collections.Generic.List[string]
    if (-not $packageUrl) {return $deps}
    $resp = Invoke-WebRequest -Uri ($baseUrl + $packageUrl)
    if(-not $resp) { Write-Host "Invoke-WebRequest failed.";exit}
    if ($resp.ParsedHtml.body.getElementsByClassName('uldep') -ne 0 ) {
        foreach($dep in ($resp.ParsedHtml.body.getElementsByClassName('uldep')[1]).children) {
            $deps.Add("/" + $dep.getElementsByTagName("a")[0].pathname)
        }
    }
    $deps
}
#$packageUrl = ($links | Select -First 1)

function getAllPackageDeps_rec {
    param($packageUrl,$all_deps)

    foreach($dep in (getPackageDeps ($packageUrl))) {
        #Write-Output (getPackageDeps ($baseUrl + $dep))
        if($all_deps -contains $dep) {
            Write-Host "$dep already found. Skipping."
            continue
        }
        
        $all_deps.Add($dep)
        $ldeps = getAllPackageDeps_rec $dep $all_deps
        if($ldeps) {
            $all_deps.AddRange([string[]]$ldeps)
        }
    }
    $all_deps | Sort-Object | Get-Unique
}

function getAllPackageDeps {
    param($packageUrl)
    $all_deps = New-Object System.Collections.Generic.List[string]
    getAllPackageDeps_rec $packageUrl $all_deps
}


#Write-Output (getAllPackageDeps $packageUrl)

function getPackageArchs {
    param($packageUrl)
    
    $dl_links = New-Object System.Collections.Generic.List[string]
    $resp = Invoke-WebRequest -Uri ($baseUrl + $packageUrl)
    if(-not $resp) { Write-Host "Invoke-WebRequest failed.(getPackageArchs)";exit}

    if(-not ($resp.ParsedHtml.getElementById("pdownload"))) {$dl_links.Add("virtual"); return $dl_links}
    $rows = ($resp.ParsedHtml.getElementById("pdownload").getElementsByTagName("tbody")[0].children) | Select-Object -Skip 1
    
    foreach($row in $rows) {
        $dl_links.Add($row.getElementsByTagName("a")[0].innerText)
    }
    $dl_links
}

function getPackageDownload {
    param($packageUrl, $arch, $mirror)

    if(-not $packageUrl) {Write-Host "packageUrl is null"}
    if(-not $arch) {Write-Host "arch is null"}
    if(-not $mirror) {Write-Host "mirror is null"}

    $array = ($packageUrl.Trim() -Split "/")
    $pkg = $array[$array.length-1]
    $array[$array.length-1] = $arch

    $dl_url = (($array -join "/"),$pkg,"download") -join "/"
    Write-Host "dl_url: $dl_url"
    $resp = Invoke-WebRequest -Uri ($baseUrl + $dl_url)
    if(-not $resp) { Write-Host "Invoke-WebRequest failed. (getPackageDownload)";exit}

    $filename = $resp.ParsedHtml.getElementsByTagName("kbd")[0].innerText
    if([String]::IsNullOrEmpty($filename)) { return "",""}
    $dl_path = $resp.ParsedHtml.getElementsByTagName("tt")[0].innerText
    Write-Host "filename: $filename"
    "$mirror$dl_path$filename",$filename
}

$mirror = "https://fr.archive.ubuntu.com/ubuntu/"
#$download_link,$filename= (getPackageDownload $packageUrl "amd64" $mirror)

function downloadPackage {
    param($download_link, $filename, $dir_path)
    New-Item -ItemType Directory -Force -Path $dir_path
    Write-Host $download_link,$filename,$dir_path
    $resp = Invoke-WebRequest -Uri $download_link -OutFile "$dir_path/$filename"
    #if(-not $resp) { Write-Host "Invoke-WebRequest failed. (downloadPackage)";exit}
}

#downloadPackage $download_link $filename "./tmp"

Function Get-Folder($initialDirectory) {
    [void] [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
    $FolderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowserDialog.RootFolder = 'MyComputer'
    if ($initialDirectory) { $FolderBrowserDialog.SelectedPath = $initialDirectory }
    [void] $FolderBrowserDialog.ShowDialog()
    return $FolderBrowserDialog.SelectedPath
}

function showResults {
    param($results)
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Packages search dialog'
    $form.StartPosition = 'CenterScreen'

    $label              = New-Object System.Windows.Forms.Label
    $label_archs        = New-Object System.Windows.Forms.Label
    $label_dir          = New-Object System.Windows.Forms.Label
    $label_archs.Text   = "Archs: "
    $label_dir.Text     = "Output: "


    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Anchor = 15
    $listBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $listBox.Items.AddRange($results)

    $archs_comboBox = New-Object System.Windows.Forms.ComboBox
    $archs_comboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList;

    $listBox.add_SelectedIndexChanged({ 
        $label.Text = $listBox.SelectedItems
        $archs_comboBox.Items.Clear()
        $archs = getPackageArchs $listBox.SelectedItems
        $archs_comboBox.Items.AddRange($archs)
        $archs_comboBox.SelectedIndex = 0
    })

    $select_path = New-Object System.Windows.Forms.Button
    $select_path.Text = "Select"
    $select_path.Add_Click({
        $label_dir.Text = Get-Folder Get-Location
    })

    $download_button = New-Object System.Windows.Forms.Button
    $download_button.Text = "Download"
    $download_button.Add_Click({
        foreach($dep in (getAllPackageDeps $listBox.SelectedItems)) {
            $arch = $archs_comboBox.Items[$archs_comboBox.SelectedIndex]
            $download_link,$filename = (getPackageDownload $dep $arch $mirror)
            if([string]::IsNullOrEmpty($download_link)) {Write-Host "Skipping $dep"; continue}
            downloadPackage $download_link $filename $label_dir.Text
        }
        Write-Host "Done."
    })

    $split_panel = New-Object System.Windows.Forms.SplitContainer
    $tableLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $tableLayout.ColumnCount = 2
    $tableLayoutRowCount = 2
    
    $split_panel.Anchor = 15
    $split_panel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $split_panel.Panel1.Controls.Add($listBox)
    $tableLayout.Anchor = 15
    $tableLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $tableLayout.AutoSize = $true
    $tableLayout.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

    $tableLayout.Controls.Add($label, -1, 0)
    $tableLayout.SetColumnSpan($label,2)
    $tableLayout.Controls.Add($label_archs,0,1)
    $tableLayout.Controls.Add($archs_comboBox, 1, 1)
    $tableLayout.Controls.Add($label_dir,0,2)
    $tableLayout.Controls.Add($select_path, 1, 2)
    $tableLayout.Controls.Add($download_button,0,3)

    $split_panel.Panel2.Controls.Add($tableLayout)
    
    $form.Controls.Add($split_panel)

    $listBox.SelectedIndex = 0
    
    $form.Topmost = $true
    $result = $form.ShowDialog()
}

showResults $links

Remove-Module gui