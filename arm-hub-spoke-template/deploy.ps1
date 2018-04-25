# Login to Azure
Write-Output "Login to Azure RM account"
Login-AzureRmAccount
Write-Output "Logged into Azure RM account"

# Set Template Variables
$templateUri="https://raw.githubusercontent.com/nathanguk/azure/master/arm-hub-spoke-template/azuredeploy.json"
$parametersUri="https://raw.githubusercontent.com/nathanguk/azure/master/arm-hub-spoke-template/azuredeploy.parameters.json"
$loc="westeurope"
$parameters = Invoke-RestMethod -Uri $parametersUri

# Set Policy Variables
$policydefinitions = "https://raw.githubusercontent.com/Azure/azure-policy/master/samples/PolicyInitiatives/multiple-billing-tags/azurepolicyset.definitions.json"
$policysetparameters = "https://raw.githubusercontent.com/Azure/azure-policy/master/samples/PolicyInitiatives/multiple-billing-tags/azurepolicyset.parameters.json"

$policyset= New-AzureRmPolicySetDefinition -Name "multiple-billing-tags" -DisplayName "Billing Tags Policy Initiative" -Description "Specify cost Center tag and product name tag" -PolicyDefinition $policydefinitions -Parameter $policysetparameters

# Deploy the Hub resource group
$hubrg = $parameters.parameters.hub.value.resourceGroup
Write-Output "Creating Resource Group: "$hubrg
$hubrgObj = New-AzureRmResourceGroup -Location $loc -Name $hubrg
Write-Output "Assigning Policy To: "$hubrg
New-AzureRmPolicyAssignment -PolicySetDefinition $policyset -Name "ProductionPolicy" -Scope $hubrgObj.ResourceId  -costCenterValue "ProductionCC" -productNameValue "Production"  -Sku @{"Name"="A1";"Tier"="Standard"}

# Deploy the Spoke resource group/s
foreach($spoke in $parameters.parameters.spokes.value){
    $rg = $spoke.resourceGroup
    Write-Output "Creating Resource Group: "$rg
    $rgObj = New-AzureRmResourceGroup -Location $loc -Name $rg
    Write-Output "Assigning Policy To: "$rg
    New-AzureRmPolicyAssignment -PolicySetDefinition $policyset -Name (concat[$rg,"ProductionPolicy"]) -Scope $rgObj.ResourceId  -costCenterValue "ProductionCC" -productNameValue "Production"  -Sku @{"Name"="A1";"Tier"="Standard"}
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