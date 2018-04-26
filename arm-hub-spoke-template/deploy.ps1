# Login to Azure
Write-Output "Login to Azure RM account"
Login-AzureRmAccount
Write-Output "Logged into Azure RM account"

# Set Template Variables
$templateUri="https://raw.githubusercontent.com/nathanguk/azure/master/arm-hub-spoke-template/azuredeploy.json"
$parametersUri="https://raw.githubusercontent.com/nathanguk/azure/master/arm-hub-spoke-template/azuredeploy.parameters.json"
$loc="westeurope"
$parameters = Invoke-RestMethod -Uri $parametersUri

# Deploy Azure RM "Allowed Location" Policy
$Policy = Get-AzureRmPolicyDefinition | Where-Object {$_.Properties.DisplayName -eq 'Allowed locations' -and $_.Properties.PolicyType -eq 'BuiltIn'}
$AllowedLocations = @{"listOfAllowedLocations"=($parameters.parameters.policy.value.allowedLocations)}
New-AzureRmPolicyAssignment -Name "Allowed Locations" -PolicyDefinition $Policy -Scope "/subscriptions/$((Get-AzureRmContext).Subscription.Id)" -PolicyParameterObject $AllowedLocations

# Deploy Azure RM "Enforce Tag and its value" Policy
$Policy = Get-AzureRmPolicyDefinition | Where-Object {$_.Properties.DisplayName -eq 'Enforce tag and its value' -and $_.Properties.PolicyType -eq 'BuiltIn'}


# Deploy the Hub resource group
$hubrg = $parameters.parameters.hub.value.resourceGroup
Write-Output "Creating Resource Group: "$hubrg
$hubrgObj = New-AzureRmResourceGroup -Location $loc -Name $hubrg
Write-Output "Assigning Policy To: "$hubrg

# Deploy the Spoke resource group/s
foreach($spoke in $parameters.parameters.spokes.value){
    $rg = $spoke.resourceGroup
    Write-Output "Creating Resource Group: "$rg
    $rgObj = New-AzureRmResourceGroup -Location $loc -Name $rg
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

#Logout of Azure
Remove-AzureRMAccount