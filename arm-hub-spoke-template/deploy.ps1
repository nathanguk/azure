# Login to Azure
Write-Output "Login to Azure RM account"
Login-AzureRmAccount
Write-Output "Logged into Azure RM account"

# Set Variables
$templateUri="https://raw.githubusercontent.com/dalejmarshall/arm/master/azuredeploy.json"
$parametersUri="https://raw.githubusercontent.com/dalejmarshall/arm/master/azuredeploy.parameters.json"
$loc="westeurope"
$query="properties.outputs.vpnGatewayPipId.value"

# Check that az is installed
get-command az 2>&1 | Out-Null
if($? -ne "True"){
    write-output "Error: az must be installed.  Go to https://aka.ms/GetTheAzureCLI."
    break
}

$parameters = Invoke-RestMethod -Uri $parametersUri

# Deploy the Hub resource group
$hubrg = $parameters.parameters.hub.value.resourceGroup
Write-Output "Creating Resource Group: "$hubrg
New-AzureRmResourceGroup -Location $loc -Name $hubrg

# Deploy the Spoke resource group/s
foreach($spoke in $parameters.parameters.spokes.value){
    $rg = $spoke.resourceGroup
    Write-Output "Creating Resource Group: "$rg
    New-AzureRmResourceGroup -Location $loc -Name $rg
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
Write-Output (Get-AzureRmPublicIpAddress -Name $vpnGatewayPipId -ResourceGroupName $hubrg)

#Logout of Azure
Remove-AzureRMAccount