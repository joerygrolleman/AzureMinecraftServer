You can run this template using the following command

```
  az deployment group create --template-file .\container-instance.bicep --resource-group <name of resource group> --parameters dockerUsername=<Docker username> dockerPassword=<Docker password> serverName=<Your unique servername> 
```
