﻿Function Set-NAVDeploymentRemoteInstanceADRegistration {
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyname=$true)]
        [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyname=$true)]
        [PSObject]$Subscription,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyname=$true)]
        [String]$DeploymentName,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyname=$true)]
        [String]$ServerInstanceName
    )
    PROCESS 
    {          
        $RemoteConfig = Get-NAVRemoteConfig
        $Remotes = $RemoteConfig.Remotes | Where-Object -Property Deployment -eq $DeploymentName
        $IconFilePath = Get-NAVClickOnceApplicationIcon -Credential $Credential -DeploymentName $DeploymentName 
        $KeyVault = Get-NAVAzureKeyVault -DeploymentName $DeploymentName
        if (!$KeyVault) { break }

        Write-Host "Updating Instance for $DeploymentName..."
        $instanceNo = 0
        Foreach ($RemoteComputer in $Remotes.Hosts) {
            $Roles = $RemoteComputer.Roles
            if ($Roles -like "*Client*" -or $Roles -like "*NAS*") {
                Write-Host "Updating $($RemoteComputer.HostName)..."
                $instanceNo ++
                $Session = New-NAVRemoteSession -Credential $Credential -HostName $RemoteComputer.FQDN
                if (!$ServerInstances) {
                   $AllServerInstances = Get-NAVRemoteInstances -Session $Session 
                   $ServerInstances = Get-NAVSelectedInstances -ServerInstances $AllServerInstances
                    if (!$ServerInstances) { break }
                }
                $DefaultServerInstance = $AllServerInstances | Where-Object -Property Default -eq True
                
                $CertValue = Get-NAVServiceCertificateValue -Session $Session -ServerInstance $DefaultServerInstance 
                $KeyVaultKey = Get-NAVAzureKeyVaultKey -KeyVault $KeyVault -ServerInstanceName $DefaultServerInstance.ServerInstance
                $DefaultApplication = Get-NAVADApplication -DeploymentName $DeploymentName -ServerInstance $DefaultServerInstance -IconFilePath $IconFilePath -CertValue $CertValue

                foreach ($ServerInstance in $ServerInstances) {                    
                    $CertValue = Get-NAVServiceCertificateValue -Session $Session -ServerInstance $ServerInstance 
                    $KeyVaultKey = Get-NAVAzureKeyVaultKey -KeyVault $KeyVault -ServerInstanceName $ServerInstance.ServerInstance
                    $Application = Get-NAVADApplication -DeploymentName $DeploymentName -ServerInstance $ServerInstance -IconFilePath $IconFilePath -CertValue $CertValue
                    $ServicePrincipal = Get-NAVADServicePrincipal -ADApplication $Application                   
                    Remove-AzureRmKeyVaultAccessPolicy -VaultName $KeyVault.VaultName -ServicePrincipalName $ServicePrincipal.ServicePrincipalNames[1] -ErrorAction SilentlyContinue
                    Remove-AzureRmKeyVaultAccessPolicy -VaultName $KeyVault.VaultName -ApplicationId $Application.ApplicationId -ObjectId $Application.ObjectId -ErrorAction SilentlyContinue
                    $ServerInstance = Combine-Settings $ServerInstance $KeyVault -Prefix KeyVault
                    $ServerInstance = Combine-Settings $ServerInstance $KeyVaultKey -Prefix KeyVaultKey
                    $ServerInstance = Combine-Settings $ServerInstance $ServicePrincipal -Prefix ServicePrincipal
                    $ServerInstance = Combine-Settings $ServerInstance $DefaultApplication -Prefix GlobalADApplication
                    $ServerInstance = Combine-Settings $ServerInstance $Application -Prefix ADApplication
                    $ServerInstance | Add-Member -MemberType NoteProperty -Name ADApplicationFederationMetadataLocation -Value "https://login.windows.net/$($Subscription.Account.Id.Split("@").GetValue(1))/federationmetadata/2007-06/federationmetadata.xml"
                    Set-NAVRemoteInstanceADRegistration -Session $Session -ServerInstance $ServerInstance -RestartServerInstance
                    if ($instanceNo -eq 1) { Set-NAVRemoteInstanceTenantAzureKeyVaultSettings -Session $Session -ServerInstance $ServerInstance -KeyVault $KeyVault -RemoteConfig $RemoteConfig -RemoteComputer $RemoteComputer }
                }
                
                Remove-PSSession -Session $Session 
            }
        }
        Remove-Item -Path (Split-Path $IconFilePath -Parent) -Recurse -Force -ErrorAction SilentlyContinue
        $anyKey = Read-Host "Press enter to continue..."
    }
}