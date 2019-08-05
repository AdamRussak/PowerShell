# This Script is a modification of : ListVMs.ps1 - Jason Fenech Mar. 2016 (https://www.altaro.com/vmware/how-to-generate-a-vsphere-report-using-powershell/)
   
# Script: VMware HTML Report.ps1 - Adam Russak. 2019
# 
# Usage  : .\VMware_HTML_Report.ps1 <vcenter or host ip>:[Manadatory] <user>:[Manadatory] <password>:[Manadatory] <sortBy>:[Optional]
# Example: .\VMware_HTML_Report.ps1 192.168.0.1 root mypassword ramalloc
#
# Desc   : Retrieves a list of virtual machines from an ESXi host or vCenter Server, extracting a subset of 
#          vm properties values returned by Get-View. The list is converted to HTML and written to disk. 
#          The script automatically displays the report by invoking the default browser.




#Command line parameters
[CmdletBinding()]
Param(
 [Parameter(Mandatory=$true,Position=1)]
 [string]$hostIP,
 
 [Parameter(Mandatory=$false,Position=2)]
 [string]$user,
 
 [Parameter(Mandatory=$false,Position=3)]
 [string]$pass,
 
 [Parameter(Mandatory=$false,Position=4)]
 [string]$sortBy
)

#Populate PSObject with the required vm properties 
function vmProperties
{
 param([PSObject]$view)
 
 $list=foreach ($vm in $view){
#test for dataCenter
$datacenter = $vm | Select-Object -Property @{ Label = "DataCenter"; Expression = {
    $parentObj = Get-View $_.Parent
    while ($parentObj -isnot [VMware.Vim.Datacenter])
    {$parentObj = Get-View $parentObj.Parent}
    $parentObj.Name} }
#Get net info
  $ips=$vm.guest.net.ipaddress | Select-String -Pattern "\d{1,3}(\.\d{1,3}){3}"
#Check for multi-homed vms - max. 2 ips
if ($ips.count -gt 1)
  {$ips=$vm.guest.net.ipaddress[0] + " " + $vm.guest.net.ipaddress[1]} 

  if ($macs.count -gt 1)
   {$macs=$vm.guest.net.macaddress[0] + " " + $vm.guest.net.macaddress[1]} 
#Check for VLAN ID
 $VlanID = Get-DataCenter $datacenter.DataCenter | Get-VM | Select-Object name, @{N="VLAN ID";E={[string]::Join('#',(Get-VirtualPortGroup -VM $vm.name | ForEach-Object{$_.Name}))}} | Where-Object {$_.name -like $VM.Name}
#Check for Tags
 $vmTags = Get-VM | Get-TagAssignment | Where-Object {$_.Entity -like $vm.Name}
#get notes for VM
 $VMNotes = Get-VM $vm.Name | Select-Object -ExpandProperty Notes
#Get the Cluster the VM is in
 $cluster = Get-VM | Where-Object {$_.name -like $singleVm.name} | Select-Object -Property Name, @{Name='Cluster';Expression={$_.VMhost.parent}}
#trim and cut OS name to fit minimal Desinge
$fullos = $vm.guest.guestfullname
if ($fullos -like "Microsoft*") {
    $firstCut = $fullos.IndexOf(" ")
    $rightpart = $fullos.Substring($firstCut+1)
    $FinalOutpot = $rightpart.TrimEnd('(64-bit)')
    
}
elseif (($fullos -like "Ubuntu*") -or ($fullos -like "FreeBSD*") -or ($fullos -like "SUSE*") -or ($fullos -like "Other*") -or ($fullos -like "Oracle*") -or ($fullos -like "VMware*") -or ($fullos -like "CentOS*")) {
    $FinalOutpot = $fullos.TrimEnd('(64-bit)')
}
else {
  $FinalOutpot = " "
  $FinalOutpot = $fullos
}

 #Populate object
 [PSCustomObject]@{
  "Purpose" = $VMNotes
  "OS" = $FinalOutpot
  "vLAN" = $VlanID."VLAN ID"
  "RAM Alloc" = $vm.Config.Hardware.MemoryMB
  "vCPUs" = $vm.Config.hardware.NumCPU
  "DataCenter" = $datacenter.DataCenter
  "IPs" = $ips
  "Cluster" = $cluster.cluster.name
  "Server" = "VM"
  "Business" = $vmTags.Tag.Name
  "Name" = $vm.Name
  }
 }
 
 return $list
}

#Stylesheet - this is used by the ConvertTo-html cmdlet
function header{
 $style = @"
 <style>
 body{
 font-family: Verdana, Geneva, Arial, Helvetica, sans-serif;
 }
 
 table{
  border-collapse: collapse;
  border: none;
  font: 10pt Verdana, Geneva, Arial, Helvetica, sans-serif;
  color: black;
  margin-bottom: 10px;
 }
 
 table td{
  font-size: 10px;
  padding-left: 0px;
  padding-right: 20px;
  text-align: left;
 }
 
 table th{
  font-size: 10px;
  font-weight: bold;
  padding-left: 0px;
  padding-right: 20px;
  text-align: left;
 }
 
 h2{
  clear: both; font-size: 130%;color:#00134d;
 }
 
 p{
  margin-left: 10px; font-size: 12px;
 }
 
 table.list{
  float: left;
 }
 
 table tr:nth-child(even){background: #e6f2ff;} 
 table tr:nth-child(odd) {background: #FFFFFF;}

 div.column {width: 320px; float: left;}
 div.first {padding-right: 20px; border-right: 1px grey solid;}
 div.second {margin-left: 30px;}

 table{
  margin-left: 10px;
 }
 –>
 </style>
"@

 return [string] $style
 }

#############################
### Script entry point ###
#############################

#Path to html report
 $repPath=(Get-ChildItem env:userprofile).value+"\desktop\test.htm"

#Report Title
 $title = "<h2>VMs hosted on $hostIP</h2>"

#Sort by
 if ($sortBy -eq "") {$sortBy="Name"; $desc=$False} 
  elseif ($sortBy.Equals("ramalloc")) {$sortBy = "RAM Alloc"; $desc=$True} 
   elseif ($sortBy.Equals("ramhost")) {$sortBy = "RAM Host"; $desc=$True} 
    elseif ($sortBy.Equals("os")) {$sortBy = "OS"; $desc=$False}

Try{
 #Drop any previously established connections
  Disconnect-VIServer -Confirm:$False -ErrorAction SilentlyContinue
 
 #Connect to vCenter or ESXi
  if (($user -eq "") -or ($pass -eq "")) 
   {Connect-VIServer $hostIP -ErrorAction Stop}
  else 
    {Connect-VIServer $hostIP -User $user -Password $pass -ErrorAction Stop}

 #Get a VirtualMachine view of all vms
  $vmView = Get-View -viewtype VirtualMachine

 #Iterate through the view object, write the set of vm properties to a PSObject and convert the whole lot to HTML
  (vmProperties -view $vmView) | Sort-Object -Property @{Expression=$sortBy;Descending=$desc} | ConvertTo-Html -Head $(header) -PreContent $title | Set-Content -Path $repPath -ErrorAction Stop
 
 #Disconnect from vCenter or ESXi
  Disconnect-VIServer -Confirm:$False -Server $hostIP -ErrorAction Stop
 
 #Load report in default browser
  Invoke-Expression "cmd.exe /C start $repPath"
 }
Catch
 {
  Write-Host $_.Exception.Message
 }
