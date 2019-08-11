<#
Created By: Adam Russak
#>
    
    ####Global Vars###
    ##################

    #VM number (minimum = 1)
    $NumberVM = 2
    #OS admin User and Password
    $VMLocalAdminUser = "<User>"
    $VMLocalAdminSecurePassword = ConvertTo-SecureString "<Password>" -AsPlainText -Force
    #VM prefix name (can be edited but less then 15 charachters)
    $VMNAME = "win" + "-${NumberVM}"
    #External IP Resourfce name
    $VMipNAME = "${VMNAME}" + "-IP"
    #VM network interface Card Name
    $VMinName = "${VMNAME}" + "-IC"
    #Vm OS disk Name
    $VmdiskNAME = "${VMNAME}" + "-disk"
    #URI for the VHD of the OS disk
    $imageURI =  <URL to VHD> # Example: https://adamRussak.blob.core.windows.net/vhds/demovhd.vhd"
    #resource group to work in (can take only 1 resource group)
    $rgName = <resourceGroup>
    #Subnet name (can use exisiting Subnet)
    $subnetName = "<SubnetName>"
    #region of the Data Center we wish to use
    $location = "<Location to use>"
    #Vnet to use (can use exisiting Vnet)
    $vnetName = <YourVnet"
    #Vnet IP Range
    $IPVnetpreFix = <IPNetwork>  Example: "192.168.0.0/16"
    #Subnet IP range
    $IPSubnetPrefix = <IPNetwork>  Example: "192.168.0.0/24"
    #security group to use (can use exisitng security group)
    $nsgName = "adam-image-nsg"
    # storage account name as "myStorageAccount"
    $storageAccName = <myStorageAccount>
    # Size of the virtual machine. This example creates "Standard_D2_v2" sized VM. 
    # See the VM sizes documentation for more information: 
    # https://azure.microsoft.com/documentation/articles/virtual-machines-windows-sizes/
    $vmSize = "Standard_D4s_v3" #usual VMs are: Standard_B4ms	
    # Assign a SKU name. This example sets the SKU name as "Standard_LRS" 
    $storageType ='StandardSSD_LRS'
    
    #####################
    ###Start Of Script###
    #####################
    $singleSubnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $IPSubnetPrefix
    $vnet = New-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName -Location $location -AddressPrefix $IPVnetpreFix -Subnet $singleSubnet -Force

    $ipName = $VMipNAME
    $pip = New-AzPublicIpAddress -Name $ipName -ResourceGroupName $rgName -Location $location `
        -AllocationMethod Dynamic -Force

    $rdpRule = New-AzNetworkSecurityRuleConfig -Name myRdpRule -Description "Allow RDP" `
        -Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
        -SourceAddressPrefix Internet -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange 3389

    $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $rgName -Location $location -Name $nsgName -SecurityRules $rdpRule -Force

    $nicName = $VMinName
    $nic = New-AzNetworkInterface -Name $nicName -ResourceGroupName $rgName -Location $location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id -Force

    $vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName

    # Enter a new user name and password to use as the local administrator account 
        # for remotely accessing the VM.
        $cred = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword); 
        # Name of the virtual machine. This example sets the VM name as "myVM".
        $vmName = $VMNAME
        # Computer name for the VM. This examples sets the computer name as "myComputer".
        $computerName = $VMNAME
        # Name of the disk that holds the OS. This example sets the 
        # OS disk name as "myOsDisk"
        $osDiskName = $VmdiskNAME
        # Get the storage account where the uploaded image is stored
        $storageAcc = Get-AzStorageAccount -ResourceGroupName $rgName -AccountName $storageAccName
        # Set the VM name and size
        $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize
        #Set the Windows operating system configuration and add the NIC
        $vm = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $computerName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
        $vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id
        # Create the OS disk URI
        $osDiskUri = '{0}vhds/{1}-{2}.vhd' -f $storageAcc.PrimaryEndpoints.Blob.ToString(), $vmName.ToLower(), $osDiskName
        # Configure the OS disk to be created from the existing VHD image (-CreateOption fromImage).
        $vm = Set-AzVMOSDisk -VM $vm -Name $osDiskName -VhdUri $osDiskUri -CreateOption fromImage -SourceImageUri $imageURI -Windows
        # Create the new VM
        New-AzVM -ResourceGroupName $rgName -Location $location -VM $vm
    
    ##############################
    #Convert Disk to managed Disk#
    ##############################
    Stop-AzVM -ResourceGroupName $rgName -Name $VMNAME -Force
    ConvertTo-AzVMManagedDisk -ResourceGroupName $rgName -VMName $VMNAME
    $vmstate = (Get-AzVM -ResourceGroupName $rgName -VMName $VMNAME -Status).Statuses.code[1]
    while ($vmstate -ne "PowerState/running") {
        Start-Sleep -Seconds 5
        $vmstate
        $vmstate = (Get-AzVM -ResourceGroupName $rgName -VMName $VMNAME -Status).Statuses.code[1]
    }
    write-host "The VM State Is now $vmstate and the Process will continue"
    Stop-AzVM -ResourceGroupName $rgName -Name $VMNAME -Force
   
    $vmstate = (Get-AzVM -ResourceGroupName $rgName -VMName $VMNAME -Status).Statuses.code[1]
    while ($vmstate -ne "PowerState/deallocated") {
        Start-Sleep -Seconds 5
        $vmstate
        $vmstate = (Get-AzVM -ResourceGroupName $rgName -VMName $VMNAME -Status).Statuses.code[1]
    }
    if ($vmstate -eq "PowerState/deallocated") {
        write-host "The VM State Is now $vmstate and the Process will continue"  
        #set Disk to Standard SSD
        $diskName = (Get-AzResource -ResourceGroupName $rgName | Where-Object {$_.Name -like "${osDiskName}*"}).Name
        $disk = Get-AzDisk -DiskName $diskName -ResourceGroupName $rgName
        # Update the storage type
        $diskUpdateConfig = New-AzDiskUpdateConfig -AccountType $storageType -DiskSizeGB $disk.DiskSizeGB
        Update-AzDisk -DiskUpdate $diskUpdateConfig -ResourceGroupName $rgName -DiskName $diskName
        Start-AzVM -ResourceGroupName $rgName -Name $VMNAME
    }
    $vmstate = (Get-AzVM -ResourceGroupName $rgName -VMName $VMNAME -Status).Statuses.code[1]
    while ($vmstate -ne "PowerState/running") {
        Start-Sleep -Seconds 5
        $vmstate
        $vmstate = (Get-AzVM -ResourceGroupName $rgName -VMName $VMNAME -Status).Statuses.code[1]    
    }
    $vmProvision = (Get-AzVM -ResourceGroupName $rgName -VMName $VMNAME -Status).Statuses.code[0]
    if ({$vmstate -eq "PowerState/running"} -and {$vmProvision -eq "ProvisioningState/succeeded"}) {
        $publicIP = (Get-AzPublicIpAddress).IpAddress
        Write-Host "$VMNAME is SUCCESSFULLY Created " -ForegroundColor Green
        Write-Host "Use for direct RDP:"
        write-host "mstsc -v $publicIP" -ForegroundColor Red
    }
        #################
        ##End of Script##
        #################
