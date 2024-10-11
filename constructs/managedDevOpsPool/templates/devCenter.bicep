@description('Required. ')
param location string

@description('Required. The name of the Dev Center to use for the DevOps Infrastructure Pool. Must be lower case and may contain hyphens.')
@minLength(3)
@maxLength(26)
param devCenterName string

@description('Required. The name of the Dev Center project to use for the DevOps Infrastructure Pool.')
@minLength(3)
@maxLength(63)
param devCenterProjectName string

resource devCenter 'Microsoft.DevCenter/devcenters@2024-02-01' = {
  name: devCenterName
  location: location
}

resource devCenterProject 'Microsoft.DevCenter/projects@2024-02-01' = {
  name: devCenterProjectName
  location: location
  properties: {
    devCenterId: devCenter.id
  }
}

@description('The resource ID of the Dev Center project.')
output devCenterProjectResourceId string = devCenterProject.id
