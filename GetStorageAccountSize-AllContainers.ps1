<#
Writen By: Adam Russak
Version: 1.0.1v

Description: 

-- The Script will generate an output with all Blobs in storage account with size and container the blob is in.
-- Output parameters:
    = Container
    = Blob Name
    = Size (KB,GB,TB)

    - Script assume you are connected to Azure
    - Script uses AZ PowerShell Module
    - You will need to provide Resouce Group And Storage Account to the CLI 
#>

Function Format-FileSize() {
    Param ([object]$BlobSize)
    If ($BlobSize -gt 1TB) {[string]::Format("{0:0.00} TB", $BlobSize / 1TB)}
    ElseIf ($BlobSize -gt 1GB) {[string]::Format("{0:0.00} GB", $BlobSize / 1GB)}
    ElseIf ($BlobSize -gt 1MB) {[string]::Format("{0:0.00} MB", $BlobSize / 1MB)}
    ElseIf ($BlobSize -gt 1KB) {[string]::Format("{0:0.00} kB", $BlobSize / 1KB)}
    ElseIf ($BlobSize -gt 0) {[string]::Format("{0:0.00} B", $BlobSize)}
    Else {""}
    }

$rgName = Read-Host "Provide a Resource Group Name"
$storageAccountName = Read-Host "Provide Storage Account"
$SASkey = (Get-AzStorageAccountKey -ResourceGroupName $rgName -AccountName $storageAccountName).Value[0] 
$destinationContext = New-AzStorageContext –StorageAccountName $storageAccountName -StorageAccountKey $SASkey
$Containers = Get-AzStorageContainer -Context $destinationContext
ForEach ($CList in $Containers) {
    $BlobList = (Get-AzStorageBlob -Context $destinationContext -Container $CList.Name)
            ForEach ($Blob in $BlobList){
                $blobname = (Get-AzStorageBlob -Context $destinationContext -Container $CList.Name) | Where-Object{$_.Name -like $blob.Name}
                $bloburl = $blobname.ICloudBlob.uri.AbsoluteUri
                $containerName = $bloburl.Split("{/}")[3]
                $BlobSize = Format-FileSize($Blob.Length)
                [PSCustomObject]@{
                    "Container" = $containerName
                    "Blob Name" = $blobname.Name
                    "Size" = $BlobSize
                    }
                }
    }
