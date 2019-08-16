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
    - The Script will go trugh your Subscription and list all Storage accounts Blobs 
    - At the start of the script you will need to select 
        - 1: CSV Output
        - 2: HTML Output
        - 3: CLI Output
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
 function Output #function to select OS (windows or Linux)
{
     param (
           [string]$Title = 'OS Menu'
     )
     Clear-Host
     Write-Host "Welcome to $Title"

     Write-Host "1: CSV Output"
     Write-Host "2: HTML Output"
     Write-Host "3: CLI Output"
     Write-Host "Q: Press 'Q' to quit."
}
Output
$input = Read-Host "Please select The Output Format"
switch ($input)
{
    '1' {
        Write-Host "CSV output Selected"
        $Outputmethod = "CSV"
     }'2' { 
       Write-Host "HTML output Selected"
       $Outputmethod = "HTML"
     }'3'{
        Write-Host "CLI output Selected"
        $Outputmethod = "CLI"   
     }'q' {
       return
       }
}
$storageAcc = Get-AzStorageAccount
$list = foreach ($Storage in $storageAcc) {
            $SASkey = (Get-AzStorageAccountKey -ResourceGroupName $Storage.ResourceGroupName -AccountName $Storage.storageAccountName).Value[0] 
            $destinationContext = New-AzStorageContext –StorageAccountName $Storage.storageAccountName -StorageAccountKey $SASkey
            $Containers = Get-AzStorageContainer -Context $destinationContext
            ForEach ($CList in $Containers) {
                $BlobList = (Get-AzStorageBlob -Context $destinationContext -Container $CList.Name)
                ForEach ($Blob in $BlobList){
                    $blobname = (Get-AzStorageBlob -Context $destinationContext -Container $CList.Name) | Where-Object{$_.Name -like $blob.Name}
                    $bloburl = $blobname.ICloudBlob.uri.AbsoluteUri
                    $containerName = $bloburl.Split("{/}")[3]
                    $BlobSize = Format-FileSize($Blob.Length)
                    [PSCustomObject]@{
                        "Resource Group" = $storage.ResourceGroupName
                        "Storage Account" = $storage.storageAccountName
                        "Container" = $containerName
                        "Blob Name" = $blobname.Name
                        "Size" = $BlobSize
            }
        }
    }  
}
if ($Outputmethod -like "HTML") {
    #Report Title
    $TitleHeader = (Get-AzContext).Subscription.Name
    $title = "<h2>Blobs List and Size on Subscription $TitleHeader</h2>"
    $sortBy = "Resource Group"
    $repPath=(Get-ChildItem env:userprofile).value+"\desktop\Storage.html"
    $list | Sort-Object -Property @{Expression=$sortBy;Descending=$desc} | ConvertTo-Html -Head $(header) -PreContent $title | Set-Content -Path $repPath -ErrorAction Stop 
}
elseif ($Outputmethod -like "CSV") {
    #export to CSV
    $repPath=(Get-ChildItem env:userprofile).value+"\desktop\Storage.xls"
    $list | Export-Csv -Path $repPath -Delimiter `t -Encoding ASCII -NoTypeInformation
}
elseif ($Outputmethod -like "CLI") {
    $list
}
