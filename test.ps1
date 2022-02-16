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
{
    "Stopped"
    {
        $result = (Start-Service -Name $svcName -PassThru).Status
        if($result -eq "Running")
        {
            Write-Output "SUCCESS - Service $svcName restarted successfully on server $srv"
        }
        else
        {
            Write-Output "ERROR - Something went wrong during service restart !!!"
        }
    }
        
    "Running"
    {
        Write-Output "SUCCESS - Service was already started"
    }

    default
    {
        Write-Output "ERROR - Unexpected service status !!!"
    }
}

<#
Write-Output "Starting runbook $rbkName to set the alert to '$newState' state"

#Invoking runbook
$Params = @{"alertId"=$alertId; "NewState"="$newState"}
Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $rbkName -Parameters $Params
#>