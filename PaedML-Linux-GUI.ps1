
######## GUI für Vbox-Schulungsumgebung fÃ¼r paedml-linux ################################################
######## Jesko Anschütz 2022   Lizenz: GPL 3 (http://www.gnu.org/licenses/gpl.html) #####################
######## v0.9.2 # 22.06.2022 ############################################################################

##### Importieren von Funktionen für "Consolen-Magic" (Fenster ausblenden...)
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

##### Erstmal das "Design"...

$BASISVERZEICHNIS="V:\LFB-Netze\Linux\paedml7x"
$LEEREMASCHINEN_BASISVERZEICHNIS="V:\LFB-Netze\Linux\leeremaschinen"

function paedml {
    Add-Type -assembly System.Windows.Forms
    $main_form = New-Object System.Windows.Forms.Form
    $main_form.Text ='paedML Schulungsumgebung'
    $main_form.Width = 700
    $main_form.Height = 400
    $main_form.AutoSize = $true
    $bgImage = [system.drawing.image]::FromFile("$BASISVERZEICHNIS\gui\logo.png")
    $main_form.BackgroundImage = $bgImage
    $main_form.BackgroundImageLayout = "None"   # None, Tile, Center, Stretch, Zoom
    $main_form.TopMost = $True

    # DialogResults:  OK, Cancel, Abort, Retry, Ignore, Yes, No
    # OK: Import
    # Cancel - Ende
    # Abort: Stop
    # Yes: Start
    # Retry: Rese

    $importButton = knopf -name 'VMs importieren' -breite 140 -hoehe 140 -xPos 40 -yPos 200 -png "$BASISVERZEICHNIS\gui\import.png" -bgcolor 'white'
    $importButton.Add_Click( { $main_form.DialogResult = "OK"; $main_form.Close } )
    $startButton = knopf -name 'Server und AdminVM starten' -breite 140 -hoehe 140 -xPos 200 -yPos 200 -png "$BASISVERZEICHNIS\gui\start.png" -bgcolor 'white'
    $startButton.Add_Click( { $main_form.DialogResult = "Yes"; $main_form.Close } )
    $stopButton = knopf -name 'Alle VMs herunterfahren' -breite 140 -hoehe 140 -xPos 360 -yPos 200 -png "$BASISVERZEICHNIS\gui\stop.png" -bgcolor 'white'
    $stopButton.Add_Click( { $main_form.DialogResult = "Abort"; $main_form.Close } )
    $resetButton = knopf -name 'Komplette Umgebung zurücksetzen' -breite 140 -hoehe 140 -xPos 520 -yPos 200 -png "$BASISVERZEICHNIS\gui\reset.png" -bgcolor 'white'
    $resetButton.Add_Click( { $main_form.DialogResult = "Retry"; $main_form.Close } )
    
    $main_form.Controls.Add($importButton)
    $main_form.Controls.Add($startButton)
    $main_form.Controls.Add($stopButton)
    $main_form.Controls.Add($resetButton)   

    $main_form.ShowDialog()
}


function main {
  hideConsole

  switch ( paedml ) {
        'OK'     { showConsole ; Clear-Host ; Write-Host "import"; registerMasterVMs ; addWindowsClients}
        'Yes'    { showConsole ; Clear-Host ; Write-Host "Start" ; startVMs    }
        'Abort'  { showConsole ; Clear-Host ; Write-Host "Stop"  ; shutdownVMs }
        'Retry'  { showConsole ; Clear-Host ; Write-Host "Reset" ; resetVMs    }
        'Cancel' { exit        } # beim SchlieÃŸen des Haupt-Fensters
  }
  startVBox
  main

}

######### Hier die Funktionalität: ##########


#Pfad zu VBoxManage.exe und VirtualBox.exe
$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$VBoxGui = "C:\Program Files\Oracle\VirtualBox\VirtualBox.exe"
$maschinen_basefolder = $BASISVERZEICHNIS
# bei direktstart ist das die bessere Wahl, bei EXE klappt das nicht.
# $maschinen_basefolder = $PSScriptRoot

# Namen der Maschinen: Die müssen in einem Ordner mit eigenem Namen liegen und die HDD MUSS name-disk-1.vdi sein!
$maschinen = @("firewall", "server", "opsi-server", "adminvm", "win10-client-1", "win10-client-2")

# Namen der leeren Maschinen. Diese MÜSSEN win10-client-X heißen!!! (--> Mac-Adresse wird abgeleitet...)
$leeremaschinen =@("win10-client-3", "win10-client-4", "win10-client-5", "win10-client-6", "win10-client-7")
#$maschinen = @("firewall")

# Hier müssen alle Maschinen rein, die NICHT LsiLogic als Controller haben.
$HDDcontrollers= @{}
$HDDcontrollers.Add("win10-client-1","SATA")
$HDDcontrollers.Add("win10-client-2","SATA")
$HDDcontrollers.Add("adminvm","SATA") 

# Konfiguration der leeren Maschinen
$leeremaschinen_basefolder = "$LEEREMASCHINEN_BASISVERZEICHNIS"
$leeremaschine_ram = 2048
$leeremaschine_grafikram = 128
$leeremaschine_acpi = "on"
$leeremaschine_cpus = 1
$leeremaschine_graphicscontroller = "vboxsvga"
$leeremaschine_nic1 = "intnet"
$leeremaschine_netz = "PAEDAGOGIK"
$leeremaschine_hddsize = "100000"


function knopf ([String]$name, [int]$breite, [int]$hoehe, [int]$xPos, [int]$yPos, [String]$png, [String]$bgcolor) {
  
  $tmpbutton = New-Object System.Windows.Forms.Button
  $tmpbutton.Location = New-Object System.Drawing.Size( $xPos, $yPos )
  $tmpbutton.Size = New-Object System.Drawing.Size($breite, $hoehe)
  $tmpbutton.BackColor = $bgcolor
  If (Test-Path $png ) {$tmpbutton.Image = [System.Drawing.Image]::FromFile($png)} else { $tmpbutton.Text = $name }

  return $tmpbutton
}

function hideConsole {
  $pointerToConsole = [Console.Window]::GetConsoleWindow()
  [Console.Window]::ShowWindow($pointerToConsole, 0)
}
function showConsole {
  $pointerToConsole = [Console.Window]::GetConsoleWindow()
  [Console.Window]::ShowWindow($pointerToConsole, 1)

}


function startVBox {
    $VBoxProcessName = "Virtualbox"
    $alreadyrunning = ""
    $alreadyrunning = Get-Process | Where-Object {$_.ProcessName -eq $VBoxProcessName }
    If($alreadyrunning -eq $null){
      & $VBoxGui
    }
}

function addWindowsClients {
  Write-Host "Leere-Windows-Clients erzeugen" -ForegroundColor Green
  foreach ($leeremaschine in $leeremaschinen) {
       Write-Host "Erzeuge $leeremaschine" -ForegroundColor Green
       Write-Host ":: erzeuge MAC" -ForegroundColor DarkGreen
       $mac = "00505610000"+$leeremaschine.Substring(13,1)
        Write-Host ":: Konfiguriere VM" -ForegroundColor DarkGreen
       & $vboxmanage createvm --basefolder "$leeremaschinen_basefolder" --name $leeremaschine --ostype Windows10_64 --register  2>$null
       & $vboxmanage modifyvm $leeremaschine --boot1 net --memory $leeremaschine_ram --vram $leeremaschine_grafikram --acpi $leeremaschine_acpi --cpus $leeremaschine_cpus --graphicscontroller $leeremaschine_graphicscontroller --nic1 $leeremaschine_nic1 --intnet1 $leeremaschine_netz --macaddress1 $mac 2>$null
       $hddcontroller = "LsiLogic"
       $filename = "$leeremaschinen_basefolder\$leeremaschine\$leeremaschine.vdi"
       Write-Host ":: erzeuge HD-Controller" -ForegroundColor DarkGreen
       & $vboxmanage storagectl $leeremaschine --name LsiLogic --add sas 2>$null
       Write-Host ":: erzeuge virtual Disk" -ForegroundColor DarkGreen
       & $vboxmanage createmedium --filename $filename --size $leeremaschine_hddsize --format VDI 2>$null
       Write-Host ":: baue Disk in HD-Controller ein" -ForegroundColor DarkGreen
       & $vboxmanage storageattach "$leeremaschine" --storagectl "$hddcontroller" --device 0 --port 1 --type hdd --medium $filename 2>$null
       # Registriere Maschine
       & $VBoxManage registervm "$leeremaschinen_basefolder\$leeremaschine\$leeremaschine.vbox"  2> $null
       # Bootreihenfolge Netzwerk hoch
       # noch Snapshot drauf und gut...
       Write-Host ":: Snapshot Auslieferungstustand von VM $leeremaschine wird bearbeitet..."
       & $VBoxManage snapshot "$leeremaschine" delete "Auslieferungszustand" 2>$null
       & $VBoxManage snapshot "$leeremaschine" take "Auslieferungszustand" 2>$null
      
       Write-Host "Fertig" -ForegroundColor Green
  }
}

function removeWindowsClients {
  Write-Host "Leere-Windows-Clients entfernen" -ForegroundColor Green
  foreach ($leeremaschine in $leeremaschinen) {
       Write-Host ":: entferne $leeremaschine" -ForegroundColor Green
       $filename = "$leeremaschinen_basefolder\$leeremaschine\$leeremaschine.vdi"
       $uuid_raw = (& $VBoxManage showmediuminfo $filename | Select-String -pattern ^UUID: ) 2>$null
       $uuid = ([String]$uuid_raw -replace 'UUID:','' -replace ' ','') 2>$null
       $hddcontroller = "LsiLogic"
       Write-Host ":::: Snapshot lÃ¶schen" -ForegroundColor DarkGreen
       & $VBoxManage snapshot "$leeremaschine" delete "Auslieferungszustand" 2>$null
 
       Write-Host ":::: Festplatte von VM trennen" -ForegroundColor DarkGreen
       & $vboxmanage storageattach "$leeremaschine" --storagectl "$hddcontroller" --device 0 --port 1 --type hdd --medium none 2>$null
       Write-Host ":::: Festplatte von VBox trennen" -ForegroundColor DarkGreen
       & $VBoxManage closemedium $uuid --delete 2>$null
       Write-Host ":::: VM deregistrieren" -ForegroundColor DarkGreen
       & $vboxmanage unregistervm $leeremaschine 2>$null
       Write-Host ":::: Verzeichnis lÃ¶schen" -ForegroundColor DarkGreen
       Remove-Item -Path "$LEEREMASCHINEN_BASISVERZEICHNIS\$leeremaschine" -Recurse 2>$null
       Write-Host ":: Fertig" -ForegroundColor Green
  }
}
       
function registerMasterVMs {
    Write-Host "Registriere Maschinen..." -ForegroundColor Green
    foreach($maschine in $maschinen) {

        # Registrieren in der Verwaltungskonsole
	    & $VBoxManage registervm "$maschinen_basefolder\$maschine\$maschine.vbox" # 2> $null

        # Nachsehen, ob für die maschine ein abweichender HDD-Controller definiert wurde.
        $hddcontroller=$HDDcontrollers.get_Item($maschine)
        # Setzen des Controllers:
        if ( $hddcontroller -eq $null ) { $hddcontroller = "LsiLogic" } else {$hddcontroller = $HDDcontrollers.get_Item($maschine) } 
        Write-Host ":: HDD-Controller von $maschine ist $hddcontroller" -ForegroundColor Green
        $mediumpath="$maschinen_basefolder/$maschine/$maschine-disk1.vdi"
        If (Test-Path $mediumpath ) {
         & $VboxManage storageattach "$maschine" --storagectl "$hddcontroller" --device 0 --port 0 --type hdd --medium "$mediumpath" 
        }
        Write-Host ":: $machine fertig" -ForegroundColor Green
    }
    # OPSI zusätzlich Platte 2
    Write-Host ":: zweite Platte von Opsi-Server..." -ForegroundColor Green
    
    $maschine = "opsi-server"
    $hddcontroller = "LsiLogic"
    & $VboxManage storageattach "$maschine" --storagectl "$hddcontroller" --device 0 --port 1 --type hdd --medium "$maschinen_basefolder/$maschine/$maschine-disk2.vdi" 

    Snapshots -snapshotname "Auslieferungszustand" -action 1
}

function Snapshots {
    param( [string]$snapshotname, [int]$action )
 	    Write-Host "Snapshots werden bearbeitet" -ForegroundColor Green
        foreach($maschine in $maschinen) {
        Write-Host ":: Snapshot $snapshotname von VM \"$maschine\" wird bearbeitet..."
        & $VBoxManage snapshot "$maschine" delete $snapshotname 2>$null
        if ($action -eq 1) { 
            & $VBoxManage snapshot "$maschine" take $snapshotname 2>$null
        }        
        Write-Host ":: $maschine FERTIG"
    }

}

function VMunregister {
    Write-Host "Maschinen von VBOX entfernen..." -ForegroundColor Green
    Snapshots -snapshotname "Auslieferungszustand" -action 0
    foreach($maschine in $maschinen) {
	    # Registrierung aufheben, falls vm bereits in der Verwaltungskonsole vorhanden ist
        Write-Host ":: VM $maschine wird deregistriert..."
	    & $VBoxManage unregistervm "$maschine" 2> $null
        Write-Host ":: $maschine FERTIG"
    }
}

function startVMs {
	# starte vm
    $timeServerStart = 60 # wie lange braucht der Server zum Starten, bevor die Clients gestartet werden dürfen?
	Write-Host "VMs werden gestartet" -ForegroundColor Green
    Write-Host ":: firewall" -ForegroundColor Green
	& $VBoxManage startvm "firewall"
    Write-Host ":: server" -ForegroundColor Green
	& $VBoxManage startvm "server"
    Write-Host ":: opsi-server" -ForegroundColor Green
    & $VBoxManage startvm "opsi-server"
    Write-Host ":: Warte $timeServerStart Sekunden bevor AdminVM gestartet wird..." -ForegroundColor Green
	Start-Sleep -s $timeServerStart
    Write-Host ":: adminvm" -ForegroundColor Green
    & $VBoxManage startvm "adminvm"
    Write-Host "Die Clients müssen bei Bedarf von Hand gestartet werden..." -ForegroundColor Green
}

function shutdownVMs {
	# VMs herunterfahren
	Write-Host "Maschinen werden gestoppt" -ForegroundColor Green
    foreach($maschine in $maschinen) {
    & $VBoxManage controlvm "$maschine" acpipowerbutton
    Write-Host ":: $maschine FERTIG"
    }
    foreach($maschine in $leeremaschinen) {
    & $VBoxManage controlvm "$maschine" acpipowerbutton
    Write-Host ":: $maschine FERTIG"
    }
}

function resetVMs {
    Write-Host "Maschinen zurÃ¼cksetzen" -ForegroundColor Green
    foreach($maschine in $maschinen) {
	    # Snapshot zurücksetzen auf den aktuellen
        Write-Host ":: $maschine wird zurückgesetzt..."
        & $VBoxManage controlvm $maschine poweroff 2> $null
	    & $VBoxManage snapshot "$maschine" restore "Auslieferungszustand" 2> $null
        Write-Host ":: $maschine zurückgesetzt"
    }
    foreach($maschine in $leeremaschinen) {
	    # Snapshot zurÃ¼cksetzen auf den aktuellen
        Write-Host ":: $maschine wird zurückgesetzt..."
        & $VBoxManage controlvm $maschine poweroff 2> $null
	    & $VBoxManage snapshot "$maschine" restore "Auslieferungszustand" 2> $null
        Write-Host ":: $maschine zurückgesetzt"
    }

}

#### und los gehts...

main
