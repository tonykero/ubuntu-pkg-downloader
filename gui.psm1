Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()
function showParamsDialog {
    param($searchon_vals, $distro_vals, $section_vals)

    $form = New-Object System.Windows.Forms.Form
    $form.Padding = 20
    $form.Text = 'Packages search dialog'
    #$form.Size = New-Object System.Drawing.Size(1000,500)
    $form.StartPosition = 'CenterScreen'
    
    $mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $mainLayout.ColumnCount = 2
    $label_kw       = New-Object System.Windows.Forms.Label
    $label_exact    = New-Object System.Windows.Forms.Label
    $label_searchon = New-Object System.Windows.Forms.Label
    $label_distros  = New-Object System.Windows.Forms.Label
    $label_section  = New-Object System.Windows.Forms.Label
    $label_kw.Text          = 'Keywords:'
    $label_exact.Text       = 'Exact Match:'
    $label_searchon.Text    = 'Search on:'
    $label_distros.Text     = 'Distributions:'
    $label_section.Text     = 'Section:'

    foreach($lbl in @($label_kw,$label_exact,$label_searchon,$label_distros,$label_section)) {
        $lbl.TextAlign = "MiddleLeft"
    }
    $keywords_textBox   = New-Object System.Windows.Forms.TextBox
    $exact_checkBox     = New-Object System.Windows.Forms.CheckBox
    $searchon_comboBox  = New-Object System.Windows.Forms.ComboBox
    $distro_comboBox    = New-Object System.Windows.Forms.ComboBox
    $section_comboBox    = New-Object System.Windows.Forms.ComboBox
    $ok_button          = New-Object System.Windows.Forms.Button
    $cancel_button      = New-Object System.Windows.Forms.Button
    
    $ok_button.Text     = "OK"
    $cancel_button.Text = "Cancel"

    $searchon_comboBox.Items.AddRange($searchon_vals)
    $searchon_comboBox.SelectedIndex = 0
    $searchon_comboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList;
    $distro_comboBox.Items.AddRange($distro_vals)
    $distro_comboBox.SelectedIndex = 0
    $distro_comboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList;
    $section_comboBox.Items.AddRange($section_vals)
    $section_comboBox.SelectedIndex = 0
    $section_comboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList;


    $mainLayout.Controls.Add($label_kw)
    $mainLayout.Controls.Add($keywords_textBox)
    $mainLayout.Controls.Add($label_exact)
    $mainLayout.Controls.Add($exact_checkBox)
    $mainLayout.Controls.Add($label_searchon)
    $mainLayout.Controls.Add($searchon_comboBox)
    $mainLayout.Controls.add($label_distros)
    $mainLayout.Controls.Add($distro_comboBox)
    $mainLayout.Controls.add($label_section)
    $mainLayout.Controls.Add($section_comboBox)
    $mainLayout.Controls.Add($ok_button)
    $mainLayout.Controls.Add($cancel_button)
    $mainLayout.Dock = [System.Windows.Forms.DockStyle]::Fill

    $mainLayout.AutoSize = $true
    $mainLayout.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $form.Controls.Add($mainLayout)

    $ok_button.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $ok_button
    $form.CancelButton = $cancel_button
    
    $form.AutoSize = $true
    $form.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $form.MaximizeBox = $false
    
    $form.Topmost = $true
    
    $form.Add_Shown({$keywords_textBox.Select()})
    $result = $form.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        $kw = $keywords_textBox.Text.replace(' ', '+')
        $cb = if($exact_checkBox.checked) {"1"} else {"0"}
        $son = $searchon_comboBox.Text
        $dist = $distro_comboBox.Text
        $sect = $section_comboBox.Text
        $res = "search?keywords=$kw&exact=$cb&searchon=$son&suite=$dist&section=$sect"
        return $res
    }
    return ""
}

