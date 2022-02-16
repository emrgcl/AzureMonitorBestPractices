# Azure Monitor Best Practices Demonstration

## Prerequisites
- Make sure disabling Auto-shutdown of VMS before session. 
- Workspace created
    - add Automation Hybrid Worker solution in the summary of the workspace
- VMS attached to Workspace with MMA
    - One or two Windows
    - one linux
- register the runbook workers
    ```PowerShell
    $NewOnPremiseHybridWorkerParameters = @{
    AutomationAccountName = <nameOfAutomationAccount>
    AAResourceGroupName   = <nameOfResourceGroup>
    OMSResourceGroupName  = <nameOfResourceGroup>
    HybridGroupName       = <nameOfHRWGroup>
    SubscriptionID        = <subscriptionId>
    WorkspaceName         = <nameOfLogAnalyticsWorkspace>
    }
    .\New-OnPremiseHybridWorker.ps1 @NewOnPremiseHybridWorkerParameters
    ```
- Automatio Account created
    - Change trakcing enabled
    - runbooks deployed
    - add Vms as runbook workers
- VMInsights enabled


# Demo  - Insights about insights & Actionable Alerts
Queries for Demonstration or Use with Slides
1. Show the environment
    - show two vms   
1. stop the spooler service on emreg-web01
1. Enable VMsinghts - on Spark22WinterWS4
1. Enable Change tracking on Spark22WinterAA4
1. Show VMInsights Enabled on the workspace. 
1. Show Change tracking Eanbled on workspace
1. Show the frequency of the services.
1. Use the below query to show what counters collected with Insight Metrics
    ```
    InsightsMetrics
    | where Origin == "vm.azm.ms"
    | distinct Namespace, Name
    ```
1. Note that there's no process Counter Collected. Highlight that counter names are normalized to a common consistent name.
```
    InsightsMetrics
    | where Origin == "vm.azm.ms"
    | where Namespace == 'LogicalDisk' and Name =='FreeSpacePercentage'
    | summarize MinSpace = min(Val) by Computer, Namespace,Name
```

1. show that Perf Collection is also enabled in Agent Configurations
1. Show that the counter duplicates are in Perf Table especially the mmemory


1. No name difference between Windows and Linux ... AvailableMB or UtilizationPercentage are named the same for both operating systems

````
Perf | where ObjectName == 'Memory'  and CounterName == 'Available MBytes'
| take 1
```

1. Create alert when a service stops using kusto, and create a service start powershell script using a runbook.




1. Run the following query show that theres the alert there.

```
ConfigurationChange
| where ConfigChangeType == "WindowsServices"
| where SvcDisplayName == "Print Spooler"
| where SvcStartupType == "Auto"
| where SvcChangeType == "State"
| summarize arg_max(TimeGenerated, *) by Computer, SvcName
| where SvcState == "Stopped"
| project TimeGenerated, Computer, SvcName, SvcDisplayName, SvcStartupType, SvcAccount, SvcState, SvcPreviousState
```


# Runbook

>Note:  Please dont go in detail for the runbook. The Idea is to trigger the runbook via webhook and show the resultant status of the service started. If theres enough time of asked specically mention about the 

```Powershell
// ## Modular approach
 
 // AAM-Caller
Param
(
    [Parameter(Mandatory = $false)]
                [object]
                $WebhookData
)
 
#$WebhookData = Get-Content -Raw -Path "c:\temp\Sample.Json" | ConvertFrom-Json
 
$rbkName = "AAM-RecoveryAction"
 
#If a runbook was called from Webhook, WebhookData will not be null.
if($WebhookData.RequestBody)
{​​​​​​​​​​​​​​​​​​​​​​​​​​​​
    $WebhookBody =  (ConvertFrom-Json $WebhookData.RequestBody)
        
    if($WebhookBody.schemaId = "azureMonitorCommonAlertSchema")
    {​​​​​​​​​​​​​​​​​​​​​​​​​​​​
        $subscriptionid = $WebhookBody.data.essentials.alertId.Split("{​​​​​​​​​​​​​​​​​​​​​​​​​​​​/}​​​​​​​​​​​​​​​​​​​​​​​​​​​​")[2]
        $tenantId = $WebhookBody.data.alertContext.LinkToSearchResults.Split("{​​​​​​​​​​​​​​​​​​​​​​​​​​​​@}​​​​​​​​​​​​​​​​​​​​​​​​​​​​")[1].Split("{​​​​​​​​​​​​​​​​​​​​​​​​​​​​/}​​​​​​​​​​​​​​​​​​​​​​​​​​​​")[0]
        $ResourceGroupName = $WebhookBody.data.essentials.alertTargetIDs[0].Split("{​​​​​​​​​​​​​​​​​​​​​​​​​​​​/}​​​​​​​​​​​​​​​​​​​​​​​​​​​​")[4]
        $workspaceId = $WebhookBody.data.alertContext.WorkspaceId
        $alertRuleName = $WebhookBody.data.essentials.alertRule
        $srvList = $WebhookBody.data.alertContext.AffectedConfigurationItems
        $alertId = $WebhookBody.data.essentials.alertId
 
        #Printing values from WebhookRows
        Write-Output "Subscription Id === $subscriptionid"
        Write-Output "TenantId === $workspaceId"
        Write-Output "ResourceGroup Name === $resourceGroupName"
        Write-Output "Worskpace Id === $workspaceId"
        Write-Output "Rule Name === $alertRuleName"
        Write-Output "Alert Id === $alertId"
    }​​​​​​​​​​​​​​​​​​​​​​​​​​​​
    else
    {​​​​​​​​​​​​​​​​​​​​​​​​​​​​
        #Assiging row values to vaiables
        $subscriptionid=$WebhookBody.SubscriptionId
        $tenantId = ($WebhookBody.LinkToSearchResults).Split("{​​​​​​​​​​​​​​​​​​​​​​​​​​​​@}​​​​​​​​​​​​​​​​​​​​​​​​​​​​")[1].Split("{​​​​​​​​​​​​​​​​​​​​​​​​​​​​/}​​​​​​​​​​​​​​​​​​​​​​​​​​​​")[0]
        $resourceGroupName = $WebhookBody.LinkToSearchResults.Split(([string[]]@('resourceGroups%2f')),[System.StringSplitOptions]::RemoveEmptyEntries)[1].Split(([string[]]@('%2fproviders%2f')),[System.StringSplitOptions]::RemoveEmptyEntries)[0]
        $workspaceId = $WebhookBody.WorkspaceId
 
        #Printing values from WebhookRows
        Write-Output "SubscriptionId === $subscriptionid"
        Write-Output "TenantId === $workspaceId"
        Write-Output "ResourceGroupName === $resourceGroupName"
        Write-Output "WorskpaceId === $workspaceId"
    }​​​​​​​​​​​​​​​​​​​​​​​​​​​​
 
    #Connect-AzureRmAccount
    
    #Autenthicating to Azure
    [String]$connectionName = "AzureRunAsConnection"
    try
    {​​​​​​​​​​​​​​​​​​​​​​​​​​​​
        #Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName
 
        "Logging in to Azure..."
        Add-AzAccount `
         -ServicePrincipal `
         -TenantId $servicePrincipalConnection.TenantId `
         -ApplicationId $servicePrincipalConnection.ApplicationId `
         -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
        
        "Setting context to a specific subscription"  
        Set-AzContext -SubscriptionId $subscriptionid
    }​​​​​​​​​​​​​​​​​​​​​​​​​​​​
    catch
    {​​​​​​​​​​​​​​​​​​​​​​​​​​​​
        if (!$servicePrincipalConnection)
        {​​​​​​​​​​​​​​​​​​​​​​​​​​​​
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        }​​​​​​​​​​​​​​​​​​​​​​​​​​​​
        else
        {​​​​​​​​​​​​​​​​​​​​​​​​​​​​
            Write-Error -Message $_.Exception
            throw $_.Exception
        }​​​​​​​​​​​​​​​​​​​​​​​​​​​​
    }​​​​​​​​​​​​​​​​​​​​​​​​​​​​
    
    #Getting parameters to run further runbooks
    [String]$automationAccountName = (Get-AutomationVariable -Name "AAM-AutomationAccountName")
            
    #Invoking the recovery action runbook
    foreach($srv in $srvList)
    {​​​​​​​​​​​​​​​​​​​​​​​​​​​​
        #parsing NetBIOS computer name out of the FQDN we got as part of the alert payload.
        #This line is necessary IF and ONLY IF the HRV has been registered using NetBIOS otherwise can be commented.
        $srv = $srv.Substring(0,$srv.IndexOf("."))
        
        #Getting the row index for SvcName column
        $idx = $WebhookBody.data.alertContext.SearchResults.Tables.columns.Name.IndexOf("SvcName")
        
        #Getting the value corresponding to the SvcName column
        $svcName=$WebhookBody.data.alertContext.SearchResults.Tables.rows[$idx]
        
        #Assembling runbook parameters
        $Params = @{​​​​​​​​​​​​​​​​​​​​​​​​​​​​"alertId"=$alertId; "svcName"=$svcName; "ResourceGroupName"=$ResourceGroupName; "automationAccountName"="$automationAccountName"}​​​​​​​​​​​​​​​​​​​​​​​​​​​​
        #$Params = @{​​​​​​​​​​​​​​​​​​​​​​​​​​​​"svcName"=$svcName}​​​​​​​​​​​​​​​​​​​​​​​​​​​​
                
        #Invoking runbook execution
        Write-Output "Starting runbook $rbkName on HRV $srv"
        $rbkResult = (Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $rbkName -RunOn $srv -Parameters $params -Wait)
 
        if($rbkResult -ccontains "SUCCESS")
        {​​​​​​​​​​​​​​​​​​​​​​​​​​​​
            Update-AzAlertState -AlertId $alertId -State Closed
        }​​​​​​​​​​​​​​​​​​​​​​​​​​​​
        else
        {​​​​​​​​​​​​​​​​​​​​​​​​​​​​
            Update-AzAlertState -AlertId $alertId -State Acknowledged
        }​​​​​​​​​​​​​​​​​​​​​​​​​​​​
        
    }​​​​​​​​​​​​​​​​​​​​​​​​​​​​
}​​​​​​​​​​​​​​​​​​​​​​​​​​​​
else
{​​​​​​​​​​​​​​​​​​​​​​​​​​​​
    Write-Output "Invalid or null Webhook or Webhook RequestBody."
}​​​​​​​​​​​​​​​​​​​​​​​​​​​​
 
```

```Powershell
// AAM-RecoveryAction
Param
(
    [Parameter(Mandatory = $true)]
                $alertId,
 
    [Parameter(Mandatory = $true)]
                [string]
                $svcName,
 
    [Parameter(Mandatory = $true)]
                [string]
                $ResourceGroupName,
                
    [Parameter(Mandatory = $true)]
                [string]
                $automationAccountName
)
 
#Setting constants
$rbkName = "AAM-SetAlertState"
 
#Performing recovery action
$svcState = (Get-Service $svcName).Status
switch($svcState)
{​​​​​​​​​​​​​​​​​​​​​​
    "Stopped"
    {​​​​​​​​​​​​​​​​​​​​​​
        $result = (Start-Service -Name $svcName -PassThru).Status
        if($result -eq "Running")
        {​​​​​​​​​​​​​​​​​​​​​​
            Write-Output "SUCCESS - Service $svcName restarted successfully on server $srv"
        }​​​​​​​​​​​​​​​​​​​​​​
        else
        {​​​​​​​​​​​​​​​​​​​​​​
            Write-Output "ERROR - Something went wrong during service restart !!!"
        }​​​​​​​​​​​​​​​​​​​​​​
    }​​​​​​​​​​​​​​​​​​​​​​
        
    "Running"
    {​​​​​​​​​​​​​​​​​​​​​​
        Write-Output "SUCCESS - Service was already started"
    }​​​​​​​​​​​​​​​​​​​​​​
 
    default
    {​​​​​​​​​​​​​​​​​​​​​​
        Write-Output "ERROR - Unexpected service status !!!"
    }​​​​​​​​​​​​​​​​​​​​​​
}​​​​​​​​​​​​​​​​​​​​​​
 
<#
Write-Output "Starting runbook $rbkName to set the alert to '$newState' state"
 
#Invoking runbook
$Params = @{​​​​​​​​​​​​​​​​​​​​​​"alertId"=$alertId; "NewState"="$newState"}​​​​​​​​​​​​​​​​​​​​​​
Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $rbkName -Parameters $Params
#>
```