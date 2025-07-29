
# Variáveis fixas
$ResourceGroup = "AVD-RGroup"
$Location = "westeurope"
$HostPoolName = "AVDadminDomainJoined-h"
$VMSize = "Standard_D2s_v3"
$ImagePublisher = "microsoftwindowsdesktop"
$ImageOffer = "windows-11"
$ImageSku = "win11-24h2-avd-m365"
$ImageVersion = "latest"
$OsDiskType = "StandardSSD_LRS"
$OsDiskSizeGB = 256
$VirtualNetworkName = "VNet-AVD-DomainJoin"
$SubnetName = "default"
$AdminUsername = "administrator.azure"
$AdminPassword = ConvertTo-SecureString "QAZwsx123456!" -AsPlainText -Force
$AvailabilityZone = ""
$SecurityType = "TrustedLaunch"
$EnableSecureBoot = $true
$EnableVtpm = $true
$EnableIntegrityMonitoring = $true
$BootDiagnosticsEnabled = $false
$VMCount = 2
$VMNamePrefix = "AVDVM"

# Obter VNet e Subnet
$vnet = Get-AzVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $ResourceGroup
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $vnet

# Loop para criar múltiplas VMs
for ($i = 1; $i -le $VMCount; $i++) {
    $vmName = "$VMNamePrefix$i"

    # Criar NIC
    $nic = New-AzNetworkInterface -Name "$vmName-NIC" `
        -ResourceGroupName $ResourceGroup `
        -Location $Location `
        -SubnetId $subnet.Id `
        -EnableAcceleratedNetworking $false

    # Configuração da VM
    $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $VMSize -SecurityType $SecurityType |
        Set-AzVMOperatingSystem -Windows -ComputerName $vmName -Credential (New-Object System.Management.Automation.PSCredential($AdminUsername, $AdminPassword)) -ProvisionVMAgent -EnableAutoUpdate |
        Set-AzVMSourceImage -PublisherName $ImagePublisher -Offer $ImageOffer -Skus $ImageSku -Version $ImageVersion |
        Set-AzVMOSDisk -CreateOption FromImage -ManagedDiskStorageAccountType $OsDiskType -DiskSizeInGB $OsDiskSizeGB |
        Add-AzVMNetworkInterface -Id $nic.Id |
        Set-AzVMSecurityProfile -SecureBootEnabled $EnableSecureBoot -VTpmEnabled $EnableVtpm -SecurityEncryptionType "DiskWithVMGuestState" |
        Set-AzVMUefiSettings -EnableVtpm $EnableVtpm -EnableSecureBoot $EnableSecureBoot

    if (-not $BootDiagnosticsEnabled) {
        $vmConfig.DiagnosticsProfile = New-Object Microsoft.Azure.Management.Compute.Models.DiagnosticsProfile
        $vmConfig.DiagnosticsProfile.BootDiagnostics = New-Object Microsoft.Azure.Management.Compute.Models.BootDiagnostics
        $vmConfig.DiagnosticsProfile.BootDiagnostics.Enabled = $false
    }

    # Criar a VM
    New-AzVM -ResourceGroupName $ResourceGroup -Location $Location -VM $vmConfig

    # Registrar no Host Pool (AVD)
    Register-AzWvdSessionHost -HostPoolName $HostPoolName `
        -ResourceGroupName $ResourceGroup `
        -Name $vmName `
        -FriendlyName $vmName `
        -AllowNewSession $true
}
