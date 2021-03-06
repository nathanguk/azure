# Login to Azure
Write-Output "Login to Azure RM account"
Login-AzureRmAccount
Write-Output "Logged into Azure RM account"

# Set Variables
$parametersUri="https://raw.githubusercontent.com/nathanguk/azure/master/arm-hub-spoke-template/azuredeploy.parameters.json"
$parameters = Invoke-RestMethod -Uri $parametersUri

# Deletev the policies
Remove-AzureRmPolicyAssignment -Name "Allowed virtual machine SKUs" -Scope "/subscriptions/$((Get-AzureRmContext).Subscription.Id)" 
Remove-AzureRmPolicyAssignment -Name "Apply default tags and default values" -Scope "/subscriptions/$((Get-AzureRmContext).Subscription.Id)" 
Remove-AzureRmPolicyAssignment -Name "Allowed Locations" -Scope "/subscriptions/$((Get-AzureRmContext).Subscription.Id)" 
Remove-AzureRmPolicySetDefinition -Name "TagInitiative" -Force


# Delete the Hub resource group
$hubrg = $parameters.parameters.hub.value.resourceGroup
Write-Output "Deleting Resource Locks: "$hubrg
Get-AzureRmResourceLock -ResourceGroupName $hubrg | Remove-AzureRmResourceLock -Force
Write-Output "Deleting Resource Group: "$hubrg
Remove-AzureRmResourceGroup -Name $hubrg -Force

# Delete the Spoke resource group/s
foreach($spoke in $parameters.parameters.spokes.value){
    $rg = $spoke.resourceGroup
    Write-Output "Deleting Resource Locks: "$rg
    Get-AzureRmResourceLock -ResourceGroupName $rg | Remove-AzureRmResourceLock -Force
    Write-Output "Deleting Resource Group: "$rg
    Remove-AzureRmResourceGroup -Name $rg -Force
} 

#Logout of Azure
Remove-AzureRMAccount