<#
.SYNOPSIS
    This script deploys Azure Resource Groups, Azure Polices and a Cloud Start Hub Spoke ARM template.
.DESCRIPTION
    This script deploys Azure Resource Groups, Azure Polices and a Cloud Start Hub Spoke ARM template with a VPN Gateway, the ARM Template and parameters is retrieved from a central GitHub repo.
.NOTES
    File Name  : deploy.ps1
    Author     : Nathan Gaskill - nathan.gaskill@ansgroup.co.uk
    Owner      : ANS Group
    Web:       : http://www.ans.co.uk  
.LINK
    http://www.ans.co.uk
#>

# Install AzureRM Resources Module
Write-Output "Installing Modules"
Install-Module -Name "AzureRM"
Install-Module -Name "AzureRM.Resources"

# Import Azure RM Module
Write-Output "Importing Modules"
Import-Module -Name "AzureRM"
Import-Module -Name "AzureRM.Resources"

# Login to Azure
Write-Output "Login to Azure RM account"
Login-AzureRmAccount
Write-Output "Logged into Azure RM account"

# Set Template Variables
$templateUri="https://raw.githubusercontent.com/nathanguk/azure/master/arm-hub-spoke-template/azuredeploy.json"
$parametersUri="https://raw.githubusercontent.com/nathanguk/azure/master/arm-hub-spoke-template/azuredeploy.parameters.json"
$parameters = Invoke-RestMethod -Uri $parametersUri

# Get Deployment Location
$loc = ($parameters.parameters.region.value.deploymentRegion)
write-output "Region: "$loc

# Deploy Azure RM "Allowed Location" Policy
$Policy = Get-AzureRmPolicyDefinition | Where-Object {$_.Properties.DisplayName -eq 'Allowed locations' -and $_.Properties.PolicyType -eq 'BuiltIn'}
$AllowedLocations = @{"listOfAllowedLocations"=($parameters.parameters.policy.value.allowedLocations)}
New-AzureRmPolicyAssignment -Name "Allowed Locations" -PolicyDefinition $Policy -Scope "/subscriptions/$((Get-AzureRmContext).Subscription.Id)" -PolicyParameterObject $AllowedLocations

# Deploy Azure RM "Enforce Tag and its value" Policy
$Policy = Get-AzureRmPolicyDefinition | Where-Object {$_.Properties.DisplayName -eq 'Apply tag and its default value' -and $_.Properties.PolicyType -eq 'BuiltIn'}
$PolicyDefinition = New-Object System.Collections.Generic.List[System.Object]

foreach($tagName in $parameters.parameters.policy.value.enforcedTags){
    write-output $tagName
    $PolicyDefinition.Add(@{
        "policyDefinitionId"= "/providers/Microsoft.Authorization/policyDefinitions/$($Policy.name)";
        "parameters"=@{
            "tagName"=@{ 
                "value"="$tagName";
            };
            "tagValue"=@{
                "value"= "Unknown";
            };
        };
    })
}

New-AzureRmPolicySetDefinition -Name "TagInitiative" -DisplayName "Apply default tags and default values" -Description "Apply default tags and default values" -PolicyDefinition ($PolicyDefinition | ConvertTo-JSON -Compress -Depth 5)
$PolicySet = Get-AzureRmPolicySetDefinition | Where-Object {$_.Name -eq 'TagInitiative'}
Start-Sleep -s 10
New-AzureRmPolicyAssignment -Name "Apply default tags and default values" -PolicySetDefinition $PolicySet -Scope "/subscriptions/$((Get-AzureRmContext).Subscription.Id)" -Sku @{"name"="A1";"tier"="Standard"}


# Deploy Azure RM "Allowed Virtual Machine SKU's" Policy
$vmList = New-Object System.Collections.Generic.List[System.Object]
foreach($vmSeries in $parameters.parameters.policy.value.allowedVmSKUs){
    foreach($vmSize in (Get-AzureRmVMSize -location $loc | Where-Object {$_.Name -match $vmSeries}).Name){
        $vmList.Add($vmSize)
    }
}

$AllowedVmSKUs = @{"listOfAllowedSKUs"=($vmList.ToArray())}
$Policy = Get-AzureRmPolicyDefinition | Where-Object {$_.Properties.DisplayName -eq 'Allowed virtual machine SKUs' -and $_.Properties.PolicyType -eq 'BuiltIn'}
New-AzureRmPolicyAssignment -Name "Allowed virtual machine SKUs" -PolicyDefinition $Policy -Scope "/subscriptions/$((Get-AzureRmContext).Subscription.Id)" -PolicyParameterObject $AllowedVmSKUs




# Deploy the Hub resource group
$hubrg = $parameters.parameters.hub.value.resourceGroup
Write-Output "Creating Resource Group: "$hubrg
New-AzureRmResourceGroup -Location $loc -Name $hubrg
Write-Output "Assigning Policy To: "$hubrg

# Deploy the Spoke resource group/s
foreach($spoke in $parameters.parameters.spokes.value){
    $rg = $spoke.resourceGroup
    Write-Output "Creating Resource Group: "$rg
    New-AzureRmResourceGroup -Location $loc -Name $rg
    Write-Output "Assigning Policy To: "$rg
} 

# Deploy the ARM template into the Hub resource group
write-output "Deploying ARM Template Please Wait..."
New-AzureRmResourceGroupDeployment -Name "HubSpokeDeployment" -ResourceGroupName $hubrg -TemplateUri $templateUri -TemplateParameterUri $parametersUri
write-output "Deployed ARM Template"

$vpnGatewayPipId = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $hubrg -Name "HubSpokeDeployment").Outputs.vpnGatewayPipId.value
write-output $vpnGatewayPipId

# The VPN gateway's public IP is dynamic, and so will not be allocated until the gateway itself is up and running
# Once the deployment has cocompleted then we determine the address
Write-Output "Getting Public IP Address"
$vpnGatewayPipName = (Get-AzureRmResource -ResourceId $vpnGatewayPipId).Name

Write-Output "Public IP Address: " (Get-AzureRmPublicIpAddress -Name $vpnGatewayPipName -ResourceGroupName $hubrg).IpAddress

Logout of Azure
##Remove-AzureRMAccount