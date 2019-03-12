#WorkAround Variables 

# path to confog script
# $PSScriptRoot - Start script's directory 
$vm_list_txt = "$PSScriptRoot\vm-backup-list.txt"

# Config file import from csv file
$CONFIG = Import-Csv $vm_list_txt -Delimiter ';'

$HOSTNAME = (Get-ChildItem -Path env:computername).Value
$Today = Get-Date -Format d

# $FileLog - log file
$FileLog  = "$PSScriptRoot\Export_Hyper-V_$Today-$HOSTNAME.rlog"

$global:VMachines = @()
$global:VM_BACKUP = @()

# Date and time of script's start
$ScriptStartTime = Get-Date -Format dd.MM.yyyy_HH_mm_ss

# For log parsing
$TODAY_DAY_OF_WEEK = switch ((Get-Date).DayOfWeek.value__) {
0 {"sun"}
1 {"mon"}
2 {"tue"}
3 {"wed"}
4 {"thu"}
5 {"fri"}
6 {"sat"}
}

function VM_from_config {
# This function parse configuration file and determine which virtual machines shouldbe backed up 

  foreach ($VMachine in $CONFIG) {

    if ( $VMachine.'VM name' -match '#') {
      continue
    }

    $MACHINE_ID = $VMachine.'VM id'
    $MACHINE_NAME = $VMachine.'VM name'
    $SCHEDUEL_MONTH = $VMachine.month
    $SCHEDUEL_DAYS = $VMachine.day -split(',',7) 
    $BACKUP_COPIES = $VMachine.'number of copies'
    $BACKUP_DIR= $VMachine.'backup dir'

    # variable trigger, default = false
    # Переменная тригер, по умолчанию = false; Отвечает за включение бэкапа
    $BACKUP_MONTH = 'False'

    if ( $SCHEDUEL_MONTH -eq '*' ) {
      $BACKUP_MONTH = 'True'
    }
    elseif ( $SCHEDUEL_MONTH -eq (Get-Date).Month ) {
      $BACKUP_MONTH = 'True'
    }
    else {
      continue
    }

    # variable trigger, default = false
    #Переменная тригер, по умолчанию = false
    $BACKUP_TODAY = 'False'

    foreach ( $DAY in $SCHEDUEL_DAYS ) {

        if ( $DAY -eq '*' ) { 
          $BACKUP_TODAY = 'True'
          break
        }
        elseif ( $DAY -eq $TODAY_DAY_OF_WEEK ) {
          $BACKUP_TODAY = 'True'
          break
        }
        else {
          continue
        }
    }

    if ( $BACKUP_TODAY -eq 'True') {
      # Append virtual machine into array if backup is scheduled today

      $VM_TO_BACKUP = "$MACHINE_ID,$MACHINE_NAME,$BACKUP_COPIES,$BACKUP_DIR"
      $global:VMachines += , $VM_TO_BACKUP
    }
  }
}

function ExportVM_HyperV {
  # This function gets virtual machines from current host and complement Vm objects with atributes from config file; then export virtual machines
  
  # Получаем список машин на данном хосте.
  # Это требуется ввиду того, что нет единого центра управления для кластера (или я не знаю как им пользоваться через powershell)

  # Здесь определяется список машин, которые хостятся на данном хосте
  # Get VMs from current Hyper-V host
  foreach ($vm in $global:VMachines){
    $VM_id = ( $vm -split(','))[0]

    # Добавляю необходимые свойства объекта для бэкапа
    # Add to VM Object new atributes as amount of backups, virtual machine name from config, backup folder
    $VirtualMachine = Get-VM | Where-Object {$_.Id -match $VM_id}
    $VirtualMachine | Add-Member Copies ( $vm -split(','))[2] # Количество бэкапов
    $VirtualMachine | Add-Member NameCfg ($vm -split(','))[1] # Имя машины как указано в конфиге
    $VirtualMachine | Add-Member FolderName ($VirtualMachine.Name + '_' + $ScriptStartTime) # Имя папки, в которой будет лежать машина
    $VirtualMachine | Add-Member BackupDirRoot (($vm -split(','))[3]+ '\' + $VirtualMachine.Name + '_' + $VM_id)
    $VirtualMachine | Add-Member BackupDir (($vm -split(','))[3]+ '\' + $VirtualMachine.Name + '_' + $VM_id + '\' + $VirtualMachine.FolderName ) # Корневая директория для бэкапов

    # Adding modified VM objects to $global:VM_BACKUP
    $global:VM_BACKUP += $VirtualMachine

  }

  # Экспорт виртуалок
  # Export Virtual Machines from $global:VM_BACKUP

  foreach ($vm in $global:VM_BACKUP) {
    
    # Write log exporting start time
    Write-Output "$HOSTNAME : $(date -Format yyyy.MM.dd-HH:mm:ss ) - Export virtual machine $($vm.Name) into $($vm.BackupDir) " | Out-File $FileLog -Append -Encoding utf8
    
    # Export Virtual Machine, if error occured - stop
    Export-VM -Name $vm.Name -Path $vm.BackupDir -ErrorAction Stop

  }

}

function Retention_backup {
  # This function emulate some retentions of exported virtual machines  
  # Эта функция обеспечивает ротацию копий виртуалок, исходя из параметра "number of copies" из конфигурационного файла
 
  foreach ($vm in $global:VM_BACKUP) {
    $COPY_AMOUNT = $vm.Copies
    $VM_NAME = $vm.NameCfg
    $VM_ID = $vm.Id

    # Get virtual machine exported directory
    $VM_BACKUPS = Get-ChildItem $vm.BackupDirRoot
    
    # Current amount of backups is more than "number of copies" ?
    if ( $VM_BACKUPS.Count -gt $COPY_AMOUNT ) {
      
      Write-Output "$HOSTNAME : $(date -Format yyyy.MM.dd-HH:mm:ss ) - $($vm.Name) - Amount of exported copies is more than $COPY_AMOUNT" | Out-File $FileLog -Append -Encoding utf8
      $RM_BACKUP = $VM_BACKUPS | Sort CreationTime | Select -First $($VM_BACKUPS.Count - $COPY_AMOUNT)

      # Delete the oldest copies
      # Удаляем самые старые бэкапы, оставляем самый свежий
      foreach ( $backup in $RM_BACKUP) {
        
        $RM_PATH = $vm.BackupDirRoot + '\' + $backup.Name
        
        Write-Output "$HOSTNAME : $(date -Format yyyy.MM.dd-HH:mm:ss ) - Removing $RM_PATH" | Out-File $FileLog -Append -Encoding utf8
        Remove-Item $RM_PATH -Recurse

      }
    }
    
    else {
      Write-Output "$HOSTNAME : $(date -Format yyyy.MM.dd-HH:mm:ss ) - $($vm.Name) - removal is not required due to amount of backups less than $COPY_AMOUNT" | Out-File $FileLog -Append -Encoding utf8
    }
    
  }
}

VM_from_config
ExportVM_HyperV
Retention_backup
