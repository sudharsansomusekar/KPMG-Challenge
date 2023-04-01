# Define variables
$resourceGroupName = "myResourceGroup"
$location = "eastus"
$vnetName = "myVNet"
$webSubnetName = "WebSubnet"
$appSubnetName = "AppSubnet"
$dbSubnetName = "DbSubnet"
$webVmName = "WebVM"
$appVmName = "AppVM"
$dbVmName = "DbVM"

# Create resource group
New-AzResourceGroup -Name $resourceGroupName -Location $location
# Create a new virtual network and subnet
$vnet = New-AzVirtualNetwork `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -Name $vnetName `
  -AddressPrefix "10.0.0.0/16"
$subnet = Add-AzVirtualNetworkSubnetConfig `
  -Name $subnetName `
  -AddressPrefix "10.0.1.0/24" `
  -VirtualNetwork $vnet
Set-AzVirtualNetwork -VirtualNetwork $vnet

# Create a new public IP address
$publicIP = New-AzPublicIpAddress `
  -ResourceGroupName $resourceGroupName `
  -Name "MyPublicIP" `
  -Location $location `
  -AllocationMethod Dynamic

# Create a new load balancer
$lb = New-AzLoadBalancer `
  -ResourceGroupName $resourceGroupName `
  -Name $lbName `
  -Location $location `
  -FrontendIpConfiguration `
    (New-AzLoadBalancerFrontendIpConfig `
      -Name $frontendIPName `
      -PublicIpAddress $publicIP) `
  -BackendAddressPool `
    (New-AzLoadBalancerBackendAddressPoolConfig `
      -Name $backendPoolName)

# Create a new availability set
$avSet = New-AzAvailabilitySet `
  -ResourceGroupName $resourceGroupName `
  -Name "MyAvailabilitySet" `
  -Location $location `
  -Sku Aligned `
  -PlatformFaultDomainCount 2 `
  -PlatformUpdateDomainCount 5
# NW Rules & sec for WebAPp
$webNsg = New-AzNetworkSecurityGroup -Name "WebNSG" -ResourceGroupName $resourceGroupName -Location $location
$webNsgRule1 = New-AzNetworkSecurityRuleConfig -Name "AllowHTTP" -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange 80 -Access Allow
$webNsgRule2 = New-AzNetworkSecurityRuleConfig -Name "AllowHTTPS" -Protocol Tcp -Direction Inbound -Priority 200 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange 443 -Access Allow
$webNsg | Add-AzNetworkSecurityRuleConfig -NetworkSecurityRuleConfig $webNsgRule1,$webNsgRule2 | Set-AzNetworkSecurityGroup

# Create four virtual machines
for ($i = 1; $i -le 4; $i++) {
  $vmName = $vmNamePrefix + $i
  $nicName = $vmName + "Nic"
  $privateIP = "10.0.1." + $i

  # Create a new network interface
  $nic = New-AzNetworkInterface `
    -Name $nicName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -SubnetId $subnet.Id `
    -LoadBalancerBackendAddressPoolIds $lb.BackendAddressPools[0].Id `
    -LoadBalancerInboundNatRuleIds $lb.InboundNatRules[$i-1].Id `
    -PrivateIpAddress $privateIP

  # Create a new virtual machine
  New-AzVM `
    -ResourceGroupName $resourceGroupName `
    -Name $vmName `
    -Location $location `
    -Image UbuntuLTS `
    -Size $vmSize `
    -AvailabilitySetId $avSet.Id `
    -NetworkInterfaceIds $nic.Id `
    -Credential (New-Object System.Management.Automation.PSCredential ($username, $(ConvertTo-SecureString $password -AsPlainText -Force))) `
    -OpenPorts 80, 443
}
##############################################Creating Application VM ###############
$AppvmName = 'Application VM'
$AppimagePublisher = "MicrosoftWindowsDesktop"
$AppimageOffer = "Windows-10"
$AppimageSku = "20h2-pro"
$AppvmSize = "Standard_DS1_v2"
$AppadminUsername = "azureuser"
$AppadminPassword = "mypassword"

# Create a new resource group
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Create a new network interface
$Appnic = New-AzNetworkInterface `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -Name "myNic" `
  -SubnetId $vnet.Subnets[0].Id `
  -PublicIpAddressId $pip.Id
# NW Rules & sec for APP
$appNsg = New-AzNetworkSecurityGroup -Name "AppNSG" -ResourceGroupName $resourceGroupName -Location $location
$appNsgRule1 = New-AzNetworkSecurityRuleConfig -Name "AllowWeb" -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix "10.0.1.0/24" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange 8080 -Access Allow
$appNsgRule2 = New-AzNetworkSecurityRuleConfig -Name "AllowDB" -Protocol Tcp -Direction Inbound -Priority 200 -SourceAddressPrefix "10.0.2.0/24" -SourcePortRange "*" -DestinationAddressPrefix "10.0.3.0/24" -DestinationPortRange 1433 -Access Allow
$appNsg | Add-AzNetworkSecurityRuleConfig -NetworkSecurityRuleConfig $appNsgRule1,$appNsgRule2 | Set-AzNetworkSecurityGroup


# Create a new virtual machine configuration
$AppvmConfig = New-AzVMConfig `
  -VMName $AppvmName `
  -VMSize $AppvmSize

# Set the OS disk image
$AppvmConfig = Set-AzVMOperatingSystem `
  -VM $AppvmConfig `
  -Windows `
  -ComputerName $vmName `
  -Credential (New-Object System.Management.Automation.PSCredential ($AppadminUsername, (ConvertTo-SecureString $AppadminPassword -AsPlainText -Force))) `
  -ProvisionVMAgent `
  -EnableAutoUpdate


# Set the VM source image
$AppvmConfig = Set-AzVMSourceImage `
  -VM $AppvmConfig `
  -PublisherName $AppimagePublisher `
  -Offer $AppimageOffer `
  -Skus $AppimageSku `
  -Version "latest"

# Add the network interface
$AppvmConfig = Add-AzVMNetworkInterface `
  -VM $AppvmConfig `
  -Id $nic.Id

# Create the new virtual machine
New-AzVM `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -VM $AppvmConfig


##################DBVM COnfig ################
# Set variables
$DBvmName = "myVM"
$DBimagePublisher = "MicrosoftSQLServer"
$DBimageOffer = "SQL2019-WS2019"
$DBimageSku = "Enterprise"
$DBvmSize = "Standard_DS3_v2"
$DBadminUsername = "azureuser"
$DBadminPassword = "mypassword"
$DBsqlEdition = "Enterprise"
$DBsqlAuthenticationMode = "SQL"
$DBsaPassword = "MySAPassword"

# Create a new resource group
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Create a new virtual network
$DBvnet = New-AzVirtualNetwork `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -Name "myVnet" `
  -AddressPrefix "10.0.0.0/16" `
  -Subnet `
    -Name "mySubnet" `
    -AddressPrefix "10.0.0.0/24"

# Create a new public IP address
$DBpip = New-AzPublicIpAddress `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -Name "myPublicIP" `
  -AllocationMethod Dynamic

# Create a new network interface
$DBnic = New-AzNetworkInterface `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -Name "myNic" `
  -SubnetId $vnet.Subnets[0].Id `
  -PublicIpAddressId $pip.Id
$dbNsg = New-AzNetworkSecurityGroup -Name "DbNSG" -ResourceGroupName $resourceGroupName -Location $location
$dbNsg | Add-AzNetworkSecurityRuleConfig -NetworkSecurityRuleConfig $dbNsgRule1 | Set-AzNetworkSecurityGroup
# Create a new virtual machine configuration
$DBvmConfig = New-AzVMConfig `
  -VMName $DBvmName `
  -VMSize $DBvmSize

# Set the OS disk image
$DBvmConfig = Set-AzVMOperatingSystem `
  -VM $DBvmConfig `
  -Windows `
  -ComputerName $DBvmName `
  -Credential (New-Object System.Management.Automation.PSCredential ($DBadminUsername, (ConvertTo-SecureString $DBadminPassword -AsPlainText -Force))) `
  -ProvisionVMAgent `
  -EnableAutoUpdate

# Set the VM source image
$DBvmConfig = Set-AzVMSourceImage `
  -VM $DBvmConfig `
  -PublisherName $DBimagePublisher `
  -Offer $DBimageOffer `
  -Skus $DBimageSku `
  -Version "latest"

# Add the network interface
$DBvmConfig = Add-AzVMNetworkInterface `
  -VM $DBvmConfig `
  -Id $DBnic.Id

# Install SQL Server on the virtual machine
$DBvmConfig = Set-AzVMExtension `
  -ResourceGroupName $DBresourceGroupName `
  -Location $DBlocation `
  -VMName $DBvmName `
  -Name "SqlIaasExtension" `
  -Publisher "Microsoft.SqlServer.Management" `
  -Type "SqlIaaSAgent" `
  -TypeHandlerVersion "1.2" `
  -AutoUpgradeMinorVersion $true `
  -Settings `
    @{
      "AutoTelemetrySettings"=@{
          "Region"=$location;
          "TenantId"=(Get-AzContext).Tenant.Id
      };
      "SQLSysAdminAccounts"=@(
        @{
          "UserName"="sa";
          "Password"=$saPassword;
        }
      );
    } `
  -ProtectedSettings `
    @{
      "SQLAuth"=@{
          "Login"="sa";
          "Password"=$saPassword;
        };
      "SqlConnectivityContext"=@{
          "Login"="sa";
          "Password"=$saPassword
	  }

# NW Rules & sec for DB



