// az group create -n nbDemoGroup -l norwayeast
// az deployment group create -f ./iac.bicep -g nbDemoGroup -n nbDemoDeployment
// az deployment group create -f ./iac.bicep -g nbDemoGroup --parameters ./parameters.json
// az group delete -n nbDemoGroup

@description('The name of the application')
param projectName string
param sqlUser string
param sqlPwd string
param location string = resourceGroup().location
var suffix = uniqueString(resourceGroup().id)

resource sqlServer 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: toLower('${projectName}-sql-${suffix}')
  location: location
  properties: {
    administratorLogin: sqlUser
    administratorLoginPassword: sqlPwd
  }

  resource db 'databases@2021-02-01-preview' = {
    name: 'nbDemoDB'
    location: location
    properties: {
      collation: 'SQL_Latin1_General_CP1_CI_AS'
    }
  }

  resource fwRule 'firewallRules@2021-02-01-preview' = {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }

}

resource law 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: toLower('${projectName}-ws-${suffix}')
  location: location
  properties: {
    sku: {
      name: 'Free'
    }
  }
}

resource appSvcPlan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: '${projectName}-plan-${suffix}'
  location: location
  sku: {
    name: 'F1'
    capacity: 1
  }
}

resource web 'Microsoft.Web/sites@2021-01-15' = {
  name: '${projectName}-app-${suffix}'
  location: location
  properties: {
    serverFarmId: appSvcPlan.id
    siteConfig: {
      netFrameworkVersion: 'v5.0'
      connectionStrings: [
        {
          name: 'connectionstring'
          connectionString: 'Data Source=tcp:${reference(sqlServer.id).fullyQualifiedDomainName},1433;Initial Catalog=${sqlServer::db.name};User Id=${sqlUser};Password=\'${sqlPwd}\';'
          type: 'SQLAzure'
        }
      ]
    }
  }
}

resource ai 'Microsoft.Insights/components@2020-02-02' = {
  name: '${projectName}-ai-${suffix}'
  location: location
  kind: 'web'
  tags: {
    'hidden-link:${web.id}': 'Resource'
  }
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: law.id
  }
}

resource webAppSettings 'Microsoft.Web/sites/config@2021-01-15' = {
  name: '${web.name}/web'
  properties: {
    appSettings: [
      {
        name: 'APPINSIGHTS_INSTRUMENTATIONKEY' 
        value: reference(ai.id).InstrumentationKey
      }
      { 
        name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
        value: '~2' 
      }
      {
        name: 'XDT_MicrosoftApplicationInsights_Mode'
        value: 'recommended' 
      }
    ]
  }
}

//output websiteAddress string = 'https://${reference(web).defaultHostName}/'
