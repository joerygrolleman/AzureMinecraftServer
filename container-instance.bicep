param location string = 'westeurope'
param dockerUsername string
@secure()
param dockerPassword string
param serverName string
targetScope = 'resourceGroup'

resource MinecraftServerManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-minecraft-server'
  location: location
}

resource MinecraftStorageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: 'sa${serverName}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

resource MinecraftFileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: MinecraftStorageAccount
  name: 'default'
}

resource MinecraftFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: MinecraftFileServices
  name: 'minecraft-server-file-share'
}

param RoleDefinitionId string = '/providers/Microsoft.Authorization/roleDefinitions/0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'

resource assignContainerPermissions 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('storage-acc-rbac', MinecraftStorageAccount.id, resourceGroup().id, MinecraftServerManagedIdentity.id, RoleDefinitionId)
  scope: MinecraftStorageAccount
  properties: {
    principalId: MinecraftServerManagedIdentity.properties.principalId
    roleDefinitionId: RoleDefinitionId
  }
}

resource MinecraftServerContainer 'Microsoft.ContainerInstance/containerGroups@2023-05-01'= {
  name:  'ci-minecraft-server'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${MinecraftServerManagedIdentity.id}': {}
    }
  }
  properties: {
    containers: [
      {
        name: 'minecraft-server'
        properties: {
          volumeMounts: [
            {
              name: 'minecraftvolume'
              mountPath: '/data'
            }
          ]
          image: 'itzg/minecraft-server:latest'
          ports: [
            {
              port: 25565
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
          environmentVariables: [
            {
              name: 'EULA'
              value: 'TRUE'
            }
            {
              name: 'SERVER_NAME'
              value: serverName
            }
            {
              name: 'RCON_PASSWORD'
              value: 'password'
            }
            {
              name: 'MEMORY'
              value: '4G'
            }
          ]
        }
      }
    ]
    volumes: [
      {
        name: 'minecraftvolume'
        azureFile: {
          readOnly: false
          shareName: MinecraftFileShare.name
          storageAccountName: MinecraftStorageAccount.name
          storageAccountKey: MinecraftStorageAccount.listKeys().keys[0].value
        }
      }
    ]
    osType: 'Linux'
    ipAddress: {
      type: 'Public'
      ports: [
        {
          protocol: 'TCP'
          port: 25565
        }
      ]
    }
    restartPolicy: 'OnFailure'
    imageRegistryCredentials: [
      {
        server: 'index.docker.io'
        username: dockerUsername
        password: dockerPassword
      }
    ]
  }
}
