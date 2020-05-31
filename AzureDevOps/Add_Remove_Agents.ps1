param (
  [string]$rootPath = "c:\",
  [string]$RemoveAzureURL,
  [string]$InstallAzureURL,
  [string]$Pass,
  [string]$user,
  [string]$AzurePool,
  [string]$pat,
  [string]$Check="true"
)
function SelectionMenu {
  param
  (
    # Menu caption
    [string[]]$LocalAgents
    )
  Clear-Host
  Write-Host "+ Select Azure DevOps Acction +"
  Write-Host "+++++++++++++++++++++++++++++++"
  Write-Host " "
  Write-Host "Local Agents Found on"$env:COMPUTERNAME.ToLower()":"
  foreach ($LocalAgent in $LocalAgents) {
    Write-Host "$LocalAgent " -foreground yellow
  }
 # $LocalAgents
  Write-Host " " 
  Write-Host "Select Azure DevOps Action:"

  Write-Host "1: Only Remove -- ALL"
  Write-Host "2: Only Remove -- Selected"
  Write-Host "3: Remove And Re-install -- ALL"
  Write-Host "4: Remove And Re-install -- Selected"
  Write-Host "5: Remove And Re-install New Agents (clean install)"
  Write-Host "6: install New Agents (clean install)"
  Write-Host "7: Only Download"
  Write-Host "Q: Press 'Q' to quit." -foreground red
}
function MultiSelection{
    param
    (
      # Menu caption
      [string]$Caption = 'Confirm',
      # Menu message
      [string]$Message = 'Are you sure you want to continue?',
      # Choice info pairs: item1, help1, item2, help2, ...
      [string[]]$Choices = ('&Yes', 'Continue', '&No', 'Stop'),
      # Default choice indexes (i.e. selected on [Enter])
      [int[]]$DefaultChoice = @(0)
    )
    $descriptions = @()
    for($i = 0; $i -lt $Choices.Count; $i++) {
      $c = [System.Management.Automation.Host.ChoiceDescription]("$($Choices[$i]) &$($i+1)")
      if (!$c.HelpMessage) {
        $c.HelpMessage = $Choices[$i].Replace('&', '')
      }
      $descriptions += $c
    }
    $Host.UI.PromptForChoice($Caption, $Message, [System.Management.Automation.Host.ChoiceDescription[]]$descriptions, $DefaultChoice)
}
function NewAgent {
  [cmdletbinding()]
  param (
    [string]$RootPath="c:\",
    [string]$NewAgentDirectory,
    [int]$NewAgentsAmount,
    [string]$Download= "https://vstsagentpackage.azureedge.net/agent/2.168.2/vsts-agent-win-x64-2.168.2.zip",
    [string]$install="true"
  )
  $AgentVersion=$Download.Split("/") | Where-Object{$_ -like "*.zip"}
  if (Test-Path -Path "$HOME\Downloads\${AgentVersion}") {
    Write-Host "Agnet allready Downloaded"
  }
  else {
    Write-Host "Downloading Agent from $Download" -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $Download -OutFile "$HOME\Downloads\${AgentVersion}" 
  }
  if ($install -like "true") {
    for($i = 0; $i -lt $NewAgentsAmount; $i++) {
      $number=$i+1
      $NewAgent="${NewAgentDirectory}0" + $number
      Write-Host "Creating Agnet $NewAgent" -ForegroundColor Yellow
      if (Test-Path "$RootPath$NewAgent") {
        Remove-Item -Path "$RootPath$NewAgent" -Recurse -Force
        Write-Host "Removing Directory of $NewAgent" -ForegroundColor Yellow
      }
      Write-Host "Creating Directory for $NewAgent" -ForegroundColor Yellow
      Set-Location $RootPath
      mkdir $NewAgent ; Set-Location $NewAgent
      Add-Type -AssemblyName System.IO.Compression.FileSystem ; [System.IO.Compression.ZipFile]::ExtractToDirectory("$HOME\Downloads\${AgentVersion}", "$PWD")
    }
    Set-Location $RootPath
  }
}
function InstallRemoveAgent {
  param (
    [int]$i,
    [array]$agentsList,
    [string]$RemoveAzureURL,
    [string]$InstallAzureURL,
    [string]$method,
    [string]$user,
    [string]$Pass,
    [string]$token,
    [string]$AzurePool,
    [string]$AgentName,
    [string]$NewAgentPath
  )
  if ($method -like "remove-negotiate") {
    & $agentsList[$i].fullname remove --unattended --url $RemoveAzureURL --auth negotiate --userName $user --password $Pass
  }
  elseif ($method -like "remove-pat") {
    & $agentsList[$i].fullname remove --unattended --url $RemoveAzureURL --auth pat --token $token
  }
  elseif ($method -like "install-negotiate") {
    & $agentsList[$i].fullname --unattended --url $InstallAzureURL --auth negotiate --userName $user --password $Pass --pool $AzurePool --agent $AgentName --runAsService --runAsAutoLogon  
  }
  elseif ($method -like "install-pat") {
    & $agentsList[$i].fullname  --unattended --url $InstallAzureURL --auth pat --token $token --pool $AzurePool --agent $AgentName --runAsService --runAsAutoLogon  
  }
  elseif ($method -like "install-pat-clean") {
    & $NewAgentPath --sslskipcertvalidation --unattended --url $InstallAzureURL --auth pat --token $token --pool $AzurePool --agent $AgentName --runAsService --runAsAutoLogon  
  }
}
#get all agents installed on C:
if ($Check -like "True") {
  $ScanComputer=Get-ChildItem -recurse c:\ -Directory -Depth 0 | Where-Object {($_.name -notmatch "Program Files|Users|Windows")}
  $agentsList=@()
  $t = {
  param ([string]$Path)
    Write-Host "Scanning"$_.Name"..." -ForegroundColor yellow
    $findConfigs=Get-ChildItem -Path $_.FullName -Include *.cmd -file -Filter config.cmd -Depth 0
    if ($null -ne $findConfigs) {
      foreach ($findConfig in $findConfigs) {
        $outputs=get-ChildItem -Path $findConfig.PSParentPath -Filter *.cmd
        foreach ($output in $outputs) {
          $compare=$agentsList | where-object {$_.DirectoryPath -like $output.Directory.fullname}
          if (($outputs.Count -eq 2) -and ($null -eq $compare)) {
            $agentsList+=[pscustomobject]@{Agent=$output.Directory.Name;FullName=$output.FullName;DirectoryPath=$output.Directory.fullname}
            $agentsList
          }
        }
      }
    }
  }
  $agentsList= @($ScanComputer | ForEach-Object -process { Invoke-Command -scriptblock $t -argumentlist $_ })
}
#Action Selection
SelectionMenu -LocalAgents $agentsList.Agent
$input1 = Read-Host "Please select The Output Format"
switch ($input1) {
  '1' {
      Write-Host "Only Remove -- ALL" 
      $ActionSelection = "remove-all"
  }'2' {
      Write-Host "Only Remove -- Selected"
      $ActionSelection = "remove-selcted"
  }'3'{
      Write-Host "Remove And Re-install -- ALL"
      $ActionSelection = "rm-install-all"
  }'4'{
      Write-Host "Remove And Re-install -- Selected"
      $ActionSelection = "rm-install-selected"
  }'5'{
    Write-Host "Remove And Re-install New Agents (clean install)"
    $ActionSelection = "rm-install-clean"
  }'6'{
    Write-Host "install New Agents (clean install)"
    $ActionSelection = "install-clean"
  }'7'{
    Write-Host "Only Download Agent"
    $ActionSelection = "download"
  }'q' {
      return
  }
}
while (($input1 -gt 7) -or ($input1 -lt 1)) {
  $input1 = Read-Host "Please select The Output Format"
  switch ($input1) {
    '1' {
        Write-Host "Only Remove -- ALL" 
        $ActionSelection = "remove-all"
    }'2' {
        Write-Host "Only Remove -- Selected"
        $ActionSelection = "remove-selcted"
    }'3'{
        Write-Host "Remove And Re-install -- ALL"
        $ActionSelection = "rm-install-all"
    }'4'{
        Write-Host "Remove And Re-install -- Selected"
        $ActionSelection = "rm-install-selected"
    }'5'{
      Write-Host "Remove And Re-install New Agents (clean install)"
      $ActionSelection = "rm-install-clean"
    }'6'{
      Write-Host "install New Agents (clean install)"
      $ActionSelection = "install-clean"
    }'7'{
      Write-Host "Only Download Agent"
      $ActionSelection = "download"
    }'q' {
        return
    }
  }
}
if ($ActionSelection -like "rm-install-selected") {
#Remove Agent Steps
  $selectionsToRemove=MultiSelection 'Azure DevOps Agents' 'Select Agents to remove' -Choices $agentsList.Agent
  foreach ($selectionToRemove in $selectionsToRemove) {
    $agentsList[$selectionToRemove].DirectoryPath
    $AgentName=$env:COMPUTERNAME.ToLower() + "-0$($selectionToRemove+1)"
    #remove agent
    Write-Host "Starting with Agent: $AgentName" -ForegroundColor Yellow
    Write-Host "Removing Agent: $AgentName" -ForegroundColor Yellow
    InstallRemoveAgent -method "remove-negotiate" -i $selectionToRemove -agentsList $agentsList -RemoveAzureURL $RemoveAzureURL -user $user -Pass $Pass -AzurePool $AzurePool -AgentName $AgentName
    $AgentDirectory=$agentsList[$selectionToRemove].DirectoryPath
    Remove-Item -Path "$AgentDirectory\_work" -Recurse -Force
    #re-install
    Write-Host "Installing Agent: $AgentName" -ForegroundColor Yellow
    InstallRemoveAgent -method "install-negotiate" -i $selectionToRemove -agentsList $agentsList -InstallAzureURL $InstallAzureURL -user $user -Pass $Pass -AzurePool $AzurePool -AgentName $AgentName
  }
}
elseif ($ActionSelection -like "remove-selcted") {
  #Remove Agent Steps
  $selectionsToRemove=MultiSelection 'Azure DevOps Agents' 'Select Agents to remove' -Choices $agentsList.Agent
  foreach ($selectionToRemove in $selectionsToRemove) {
    $agentsList[$selectionToRemove].DirectoryPath
    $AgentName=$env:COMPUTERNAME.ToLower() + "-0$($selectionToRemove+1)"
    #remove agent
    Write-Host "Starting with Agent: $AgentName" -ForegroundColor Yellow
    Write-Host "Removing Agent: $AgentName" -ForegroundColor Yellow
    InstallRemoveAgent -method "remove-negotiate" -i $selectionToRemove -agentsList $agentsList -RemoveAzureURL $RemoveAzureURL -user $user -Pass $Pass -AzurePool $AzurePool -AgentName $AgentName
    $AgentDirectory=$agentsList[$selectionToRemove].DirectoryPath
    Remove-Item -Path "$AgentDirectory\_work" -Recurse -Force
  }
}
elseif ($ActionSelection -like "remove-all") {
  #Remove Agent Steps
  for($i = 0; $i -lt $agentsList.Count; $i++) {
    $agentsList[$i].DirectoryPath
    $AgentName=$env:COMPUTERNAME.ToLower() + "-0$($i+1)"
    #remove agent
    Write-Host "Starting with Agent: $AgentName" -ForegroundColor Yellow
    Write-Host "Removing Agent: $AgentName" -ForegroundColor Yellow
    InstallRemoveAgent -method "remove-negotiate" -i $i -agentsList $agentsList -RemoveAzureURL $RemoveAzureURL -user $user -Pass $Pass -AzurePool $AzurePool -AgentName $AgentName
    $AgentDirectory=$agentsList[$i].DirectoryPath
    Remove-Item -Path "$AgentDirectory\_work" -Recurse -Force
    #re-install
  }
}
elseif ($ActionSelection -like "rm-install-all") {
  for($i = 0; $i -lt $agentsList.Count; $i++) {
    $agentsList[$i].DirectoryPath
    $AgentName=$env:COMPUTERNAME.ToLower() + "-0$($i+1)"
    Write-Host "Starting with Agent: $AgentName" -ForegroundColor Yellow
    Write-Host "Removing Agent: $AgentName" -ForegroundColor Yellow
    #remove agent
    InstallRemoveAgent -method "remove-negotiate" -i $i -agentsList $agentsList -RemoveAzureURL $RemoveAzureURL -user $user -Pass $Pass -AzurePool $AzurePool -AgentName $AgentName
    $AgentDirectory=$agentsList[$i].DirectoryPath
    Remove-Item -Path "$AgentDirectory\_work" -Recurse -Force
    #re-install
    Write-Host "Installing Agent: $AgentName" -ForegroundColor Yellow
    InstallRemoveAgent -method "install-negotiate" -i $i -agentsList $agentsList -InstallAzureURL $InstallAzureURL -user $user -Pass $Pass -AzurePool $AzurePool -AgentName $AgentName
  }
}
elseif ($ActionSelection -like "rm-install-clean") {
  for($i = 0; $i -lt $agentsList.Count; $i++) {
    $agentsList[$i].DirectoryPath
    $AgentName=$env:COMPUTERNAME.ToLower() + "-0$($i+1)"
    #remove agent
    Write-Host "Starting with Agent: $AgentName" -ForegroundColor Yellow
    Write-Host "Removing Agent: $AgentName" -ForegroundColor Yellow
    InstallRemoveAgent -method "remove-negotiate" -i $i -agentsList $agentsList -RemoveAzureURL $RemoveAzureURL -user $user -Pass $Pass -AzurePool $AzurePool -AgentName $AgentName
    $AgentDirectory=$agentsList[$i].DirectoryPath
    Remove-Item -Path "$AgentDirectory" -Recurse -Force
  }
  $NewAgentDirectory = Read-Host "Please enter Agents Folders Name (Limited to 2 character)"
  while(($NewAgentDirectory.ToCharArray() | Measure-Object).Count -ne 2 )
  {
    $NewAgentDirectory = Read-Host "Please enter Agents Folders Name (Limited to 2 character)"
  }
  [int]$NewAgentsAmount = Read-Host "Please enter the number of Agents to install (1-9)"
  while($NewAgentsAmount -gt 9)
  {
    [int]$NewAgentsAmount = Read-Host "Please enter the number of Agents to install (1-9)"
  }
  NewAgent -RootPath $rootPath -NewAgentDirectory $NewAgentDirectory -NewAgentsAmount $NewAgentsAmount
  for($i = 0; $i -lt $NewAgentsAmount; $i++) {
    $AgentName=$env:COMPUTERNAME.ToLower() + "-0$($i+1)"
    $number=$i+1
    $NewAgentPath= "$rootPath$NewAgentDirectory"+"0"+$number+"\config.cmd"
    InstallRemoveAgent -method "install-pat-clean" -NewAgentPath $NewAgentPath -InstallAzureURL $InstallAzureURL -token $pat -AzurePool $AzurePool -AgentName $AgentName
  }
}
elseif ($ActionSelection -like "install-clean") {
  $NewAgentDirectory = Read-Host "Please enter Agents Folders Name (Limited to 2 character)"
  while(($NewAgentDirectory.ToCharArray() | Measure-Object).Count -ne 2 )
  {
    $NewAgentDirectory = Read-Host "Please enter Agents Folders Name (Limited to 2 character)"
  }
  [int]$NewAgentsAmount = Read-Host "Please enter the number of Agents to install (1-9)"
  while($NewAgentsAmount -gt 9)
  {
    [int]$NewAgentsAmount = Read-Host "Please enter the number of Agents to install (1-9)"
  }
  NewAgent -RootPath $rootPath -NewAgentDirectory $NewAgentDirectory -NewAgentsAmount $NewAgentsAmount
  for($i = 0; $i -lt $NewAgentsAmount; $i++) {
    $AgentName=$env:COMPUTERNAME.ToLower() + "-0$($i+1)"
    $number=$i+1
    $NewAgentPath= "$rootPath$NewAgentDirectory"+"0"+$number+"\config.cmd"
    InstallRemoveAgent -method "install-pat-clean" -NewAgentPath $NewAgentPath -InstallAzureURL $InstallAzureURL -token $pat -AzurePool $AzurePool -AgentName $AgentName
  }
}
elseif ($ActionSelection -like "download") {
  NewAgent -install "false"
}