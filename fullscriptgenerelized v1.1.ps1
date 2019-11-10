<#
Version: 1.2v
Written by: Adam Russak
About: This Script Creates a Generlized Image From VM to Storage VHD
    The Script Goes trugh the following steps:
        - Checks if Users is connected to Azure (Az Comdlet)
        - collecting Info for Operation in UI commands
        - set azure subscription for the Scripts
        - Deallocating resurces VM
        - Create a Snapshot
        - Create VHD from Sapshoot & transfer to Storage-Account
        - Check Transfer Status
#>

###########
#Functions#
###########
#testing if Azure is connected (if not it will prompt loggin gui)
function Login
{
    $needLogin = $true
    Try 
    {
        $content = Get-AzContext
        if ($content) 
        {
            $needLogin = ([string]::IsNullOrEmpty($content.Account))
        } 
    } 
    Catch 
    {
        if ($_ -like "*Login-AzAccount to login*") 
        {
            $needLogin = $true
        } 
        else 
        {
            throw
        }
    }

    if ($needLogin)
    {
        Login-AzAccount
    }
}


#run Func to see login status
Login
##################
#Global-Variables#
##################

#login Subscription
$Subscription = Read-Host -Prompt 'Input the Subscription ID'

#Resources Group
$defaultRG = Read-Host -Prompt 'Input the Resource Group'

#VM Name
$VMNAME = Read-Host -Prompt 'Input the VM name'

#snapshoot Name
$snapshotName = Read-Host -Prompt 'Input Snapshoot Desired name'

#Vm location
$location = Read-Host -Prompt 'Input the Region you need to use'
  
##Provide storage account name where you want to copy the snapshot. 
$storageAccountName = Read-Host -Prompt 'Input the Storage Account Name'

#Name of the storage container where the downloaded snapshot will be stored
$storageContainerName = Read-Host -Prompt 'Input the Container name'

#Provide the key of the storage account where you want to copy snapshot. 
$storageAccountKey = Read-Host -Prompt 'Input the Storage Account Key'

#Provide the name of the VHD file to which snapshot will be copied.
$destinationVHDFileName = Read-Host -Prompt 'Input the VHD name'

#Provide Shared Access Signature (SAS) expiry duration in seconds e.g. 3600.
#Know more about SAS here: https://docs.microsoft.com/en-us/azure/storage/storage-dotnet-shared-access-signature-part-1
$sasExpiryDuration = "36000"

#####################
###Start of Script###
#####################
#runtime for the script
$startTime = (Get-Date).Minute
Set-AzContext -SubscriptionId $Subscription

##############################
#Deallocate the VM resources#
##############################
$startTime1 = (Get-Date).Minute
Stop-AzVM -ResourceGroupName $defaultRG -Name $VMNAME -Force
#Set the status of the virtual machine to Generalized.
Set-AzVm -ResourceGroupName $defaultRG -Name $VMNAME -Generalized
#Check the status of the VM. The OSState/generalized section for the VM should have the DisplayStatus set to VM generalized.
$vm = Get-AzVM -ResourceGroupName $defaultRG -Name $VMNAME -Status
$vm.Statuses
#End of Deallocation Time output
$EndTime1 = (Get-Date).Minute
Write-Host "The Deallocation Took $($EndTime1 - $startTime1) Minutes to Run"

####################
# create-Snapshoot #
####################
$startTime2 = (Get-Date).Minute
#getting RG and VM name 
$createSnapshoot = Get-AzVM -ResourceGroupName $defaultRG -Name $vmName
#create the Snapshoot
$snapshot =  New-AzSnapshotConfig -SourceUri $createSnapshoot.StorageProfile.OsDisk.ManagedDisk.Id -Location $location -CreateOption copy
New-AzSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $defaultRG
#End of Snapshoot Time output
$EndTime2 = (Get-Date).Minute
Write-Host "The Snapshoot Took $($EndTime2 - $startTime2) Minutes to Run"

##########################
#create VHD from Sapshoot#
##########################
$startTime3 = (Get-Date).Minute
#Generate the SAS for the snapshot 
$sas = Grant-AzSnapshotAccess -ResourceGroupName $defaultRG -SnapshotName $SnapshotName  -DurationInSecond $sasExpiryDuration -Access Read 
#Create the context for the storage account which will be used to copy snapshot to the storage account 
$destinationContext = New-AzStorageContext –StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey  
#Copy the snapshot to the storage account 
Start-AzStorageBlobCopy -AbsoluteUri $sas.AccessSAS -DestContainer $storageContainerName -DestContext $destinationContext -DestBlob $destinationVHDFileName
#End of Script Time output
$EndTime3 = (Get-Date).Minute
Write-Host "Creating the VHD Took $($EndTime3 - $startTime3) Minutes to Run"
$EndTime = (Get-Date).Minute
Write-Host "The Script Took $($EndTime - $startTime) Minutes to Run"

#######################
#Check VHD Copy Status#
#######################
Get-AzStorageBlobCopyState -Blob $destinationVHDFileName -Container $storageContainerName -Context $destinationContext -WaitForComplete

###################
###End Of Script###
###################
