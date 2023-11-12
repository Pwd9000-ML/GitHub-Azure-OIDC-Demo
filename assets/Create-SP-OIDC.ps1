### Create-SP-OIDC.ps1 ###
# Log into Azure
az login --tenant 'b4fd7cff-510b-4da5-b133-f7aa6f692ee2'--use-device-code

# Show current subscription (use 'Az account set' to change subscription)
az account set --subscription '829efd7e-aa80-4c0d-9c1c-7aa2557f8e07'
az account show

# variables
$subscriptionId = $(az account show --query id -o tsv)
$appName = "GitHub-Azure-Actions-OIDC"
$RBACRole = "Contributor"

$githubOrgName = "Pwd9000-ML"
$githubRepoName = "GitHub-Azure-OIDC-Demo"
$githubBranch = "master"

# Create AAD App and Principal
$appId = $(az ad app create --display-name $appName --query appId -o tsv)
az ad sp create --id $appId

#Ref entity types: https://learn.microsoft.com/en-us/azure/active-directory/workload-identities/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azcli#github-actions-example
# Create federated GitHub credentials (Entity type 'Branch')
$githubBranchConfig = [PSCustomObject]@{
    name        = "GH-[$githubOrgName-$githubRepoName]-Branch-[$githubBranch]"
    issuer      = "https://token.actions.githubusercontent.com"
    subject     = "repo:" + "$githubOrgName/$githubRepoName" + ":ref:refs/heads/$githubBranch"
    description = "Federated credential linked to GitHub [$githubBranch] branch @: [$githubOrgName/$githubRepoName]"
    audiences   = @("api://AzureADTokenExchange")
}
$githubBranchConfigJson = $githubBranchConfig | ConvertTo-Json
$githubBranchConfigJson | az ad app federated-credential create --id $appId --parameters "@-"

# Create federated GitHub credentials (Entity type 'Pull Request')
$githubPRConfig = [PSCustomObject]@{
    name        = "GH-[$githubOrgName-$githubRepoName]-PR"
    issuer      = "https://token.actions.githubusercontent.com"
    subject     = "repo:" + "$githubOrgName/$githubRepoName" + ":pull_request"
    description = "Federated credential linked to GitHub Pull Requests @: [$githubOrgName/$githubRepoName]"
    audiences   = @("api://AzureADTokenExchange")
}
$githubPRConfigJson = $githubPRConfig | ConvertTo-Json
$githubPRConfigJson | az ad app federated-credential create --id $appId --parameters "@-"

### Additional federated GitHub credential entity types are 'Tag' and 'Environment' (see: https://docs.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azcli#github-actions-example) ###

# Assign RBAC permissions to Service Principal (Change as necessary)
$appId | foreach-object {

    # Permission 1 (Example)
    az role assignment create `
        --role $RBACRole `
        --assignee $_ `
        --subscription $subscriptionId

    # Permission 2 (Example)
    #az role assignment create `
    #    --role "Reader and Data Access" `
    #    --assignee "$_" `
    #    --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageName"
}