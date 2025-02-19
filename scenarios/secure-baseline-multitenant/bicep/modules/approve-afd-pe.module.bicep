
@description('Optional. The location to deploy the Redis cache service.')
param location string 

@description('Default value is OK. Sets how the deployment script should be forced to execute even if the script resource has not changed. Can be current time stamp')
param utcValue string = utcNow()

@description('Optional. The name of the user-assigned identity to be used to auto-approve the private endpoint connection of the AFD. Changing this forces a new resource to be created.')
param idAfdPeAutoApproverName string = guid(resourceGroup().id, 'userAssignedIdentity')


var roleAssignmentName = guid(resourceGroup().id, 'contributor')
var contributorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
var deploymentScriptName = 'runAfdApproval'


@description('The User Assigned MAnaged Identity that will be given Contributor role on the Resource Group in order to auto-approve the Private Endpoint Connection of the AFD.')
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: idAfdPeAutoApproverName
  location: location
}

@description('The role assignment that will be created to give the User Assigned Managed Identity Contributor role on the Resource Group in order to auto-approve the Private Endpoint Connection of the AFD.')
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: roleAssignmentName
  scope: resourceGroup()
  properties: {
    roleDefinitionId: contributorRoleDefinitionId
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('The deployment script that will be used to auto-approve the Private Endpoint Connection of the AFD.')
resource runAfdApproval 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: deploymentScriptName
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.47.0'
    timeout: 'PT30M'
    environmentVariables: [
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name
      }
    ]
    scriptContent: 'rg_name="$ResourceGroupName"; webapp_id=$(az webapp list -g $rg_name --query "[].id" -o tsv); fd_conn_id=$(az network private-endpoint-connection list --id $webapp_id --query "[?properties.provisioningState == \'Pending\'].{id:id}" -o tsv);az network private-endpoint-connection approve --id $fd_conn_id --description "ApprovedByCli"'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
  dependsOn: [
    roleAssignment
  ]
}

@description('The logs of the deployment script that will be used to auto-approve the Private Endpoint Connection of the AFD.')
resource log 'Microsoft.Resources/deploymentScripts/logs@2020-10-01' existing = {
  parent: runAfdApproval
  name: 'default'
}

@description('The output of the deployment script that will be used to auto-approve the Private Endpoint Connection of the AFD.')
output logs string = log.properties.log
