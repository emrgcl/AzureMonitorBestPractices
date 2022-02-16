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
{
    $WebhookBody =  (ConvertFrom-Json $WebhookData.RequestBody)
        
    if($WebhookBody.schemaId = "azureMonitorCommonAlertSchema")
    {
        $subscriptionid = $WebhookBody.data.essentials.alertId.Split("{/}")[2]
        $tenantId = $WebhookBody.data.alertContext.LinkToSearchResults.Split("{@}")[1].Split("{/}")[0]
        $ResourceGroupName = $WebhookBody.data.essentials.alertTargetIDs[0].Split("{/}")[4]
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
    }
    else
    {
        #Assiging row values to vaiables
        $subscriptionid=$WebhookBody.SubscriptionId
        $tenantId = ($WebhookBody.LinkToSearchResults).Split("{@}")[1].Split("{/}")[0]
        $resourceGroupName = $WebhookBody.LinkToSearchResults.Split(([string[]]@('resourceGroups%2f')),[System.StringSplitOptions]::RemoveEmptyEntries)[1].Split(([string[]]@('%2fproviders%2f')),[System.StringSplitOptions]::RemoveEmptyEntries)[0]
        $workspaceId = $WebhookBody.WorkspaceId

        #Printing values from WebhookRows
        Write-Output "SubscriptionId === $subscriptionid"
        Write-Output "TenantId === $workspaceId"
        Write-Output "ResourceGroupName === $resourceGroupName"
        Write-Output "WorskpaceId === $workspaceId"
    }

    #Connect-AzureRmAccount
    
    #Autenthicating to Azure
    [String]$connectionName = "AzureRunAsConnection"
    try
    {
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
    }
    catch
    {
        if (!$servicePrincipalConnection)
        {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        }
        else
        {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
    
    #Getting parameters to run further runbooks
    [String]$automationAccountName = (Get-AutomationVariable -Name "AAM-AutomationAccountName")
            
    #Invoking the recovery action runbook
    foreach($srv in $srvList)
    {
        #parsing NetBIOS computer name out of the FQDN we got as part of the alert payload.
        #This line is necessary IF and ONLY IF the HRV has been registered using NetBIOS otherwise can be commented.
        $srv = $srv.Substring(0,$srv.IndexOf("."))
        
        #Getting the row index for SvcName column
        $idx = $WebhookBody.data.alertContext.SearchResults.Tables.columns.Name.IndexOf("SvcName")
        
        #Getting the value corresponding to the SvcName column
        $svcName=$WebhookBody.data.alertContext.SearchResults.Tables.rows[$idx]
        
        #Assembling runbook parameters
        $Params = @{"alertId"=$alertId; "svcName"=$svcName; "ResourceGroupName"=$ResourceGroupName; "automationAccountName"="$automationAccountName"}
        #$Params = @{"svcName"=$svcName}
                
        #Invoking runbook execution
        Write-Output "Starting runbook $rbkName on HRV $srv"
        $rbkResult = (Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $rbkName -RunOn $srv -Parameters $params -Wait)

        if($rbkResult -ccontains "SUCCESS")
        {
            Update-AzAlertState -AlertId $alertId -State Closed
        }
        else
        {
            Update-AzAlertState -AlertId $alertId -State Acknowledged
        }
    }
}
else
{
    Write-Output "Invalid or null Webhook or Webhook RequestBody."
}
