function Get-GitHubWorkflowRun {
    <#
        .SYNOPSIS
            Gets run information from a GitHub Actions workflow.

        .DESCRIPTION
            The function in this script file gets information about a GitHub Actions workflow run.
            The GitHub owner, GitHub repository, Workflow name & Workflow run id are provided as output result.
            The Workflow run id, GitHub ownner and GitHub repository can be used to delete the run from GitHub logging.

            !! This function requires gh cli to be installed & an authenticated session to GitHub via gh cli. !!

            Dot source this file before being able to use the function in this file. 
            To load the function into memory execute the following in the shell or create an entry in the $PROFILE:
            . .\Get-GitHubWorkflowRun.ps1

        .PARAMETER GitHubOwner
            Specifies the name of the GitHub owner where the repository is hosted, from which workflow runs are executed.

        .PARAMETER GitHubRepo
            Specifies the name of the GitHub repository, from which workflow runs are executed.

        .PARAMETER workflowName
            Specifies the name of the workflow for which run(s) information will be fetched.

        .PARAMETER workflowConclusion
            Specifies the type of workflow run conclusion to fetch information for.

            There are 4 possible values for this parameter:
            'success', 'skipped', 'cancelled', 'failure'

        .PARAMETER workflowActor
            Specifies the actor of a workflow run or runs to fetch information for.

        .PARAMETER workflowRunStarted
            Specifies the date of a workflow run or runs to fetch information for.
            The parameter value is specified in days.
            
            For example specifying 20 days, will result in the date 20 days ago.
            The workflow run(s) start date execution, will be evaluated against the date 20 days ago.

        .INPUTS
            None.

        .OUTPUTS
            Pscustomobject containing the GitHub ownner, GitHub repository, Workflow name & Workflow run id.

        .NOTES
            Version:        0.9
            Author:         @sandrochristiaan
            Creation Date:  20230120
            Purpose/Change: Documented version.
                            
        .EXAMPLE
            Get-GitHubWorkflowRun -workflowName 'ExampleWorkflowName' -workflowRunStarted 20 -Verbose

        .EXAMPLE
            Get-GitHubWorkflowRun -GitHubOwner 'someExampleOwner' -GitHubRepo 'someExampleRepo' -workflowName 'ExampleWorkflowName' -workflowConclusion 'cancelled'
        
        .EXAMPLE
            Get-GitHubWorkflowRun -workflowName 'ExampleWorkflowName' -workflowActor 'exampleActorName'

        .EXAMPLE
            $workflowNames = @('workflowExample1','workflowExample2','workflowwwww')
            
            foreach ($workflow in $workflowNames) {
                Get-GitHubWorkflowRun -workflowName $workflow -workflowConclusion success
            }
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$GitHubOwner,
        [Parameter()]
        [string]$GitHubRepo,
        [Parameter(ValueFromPipeline)]
        [string]$workflowName,
        [Parameter(ParameterSetName = 'conclusion')]
        [ValidateSet('success', 'skipped', 'cancelled', 'failure')]
        [string]$workflowConclusion,
        [Parameter(ParameterSetName = 'actor')]
        [string]$workflowActor,
        [Parameter(ParameterSetName = 'runstarted')] # Parameter which sets the filter to get workflow runs older then a desired date. Can be set using days.
        [int]$workflowRunStarted
    )
    
    begin {
        # list workflows
        Write-Verbose "Retrieving all workflows in Github repo: '$($GitHubOwner)/$($GitHubRepo)'"
        $workflows = gh api -X GET /repos/$GitHubOwner/$GitHubRepo/actions/workflows | 
        ConvertFrom-Json | 
        Select-Object workflows -ExpandProperty workflows
        
        # copy the ID of the workflow you want to clear and set it
        if ($workflows) {
            Write-Verbose "Retrieving the workflow id of '$($workflowName)'"
            $workflowId = $workflows | 
            Where-Object { $_.name -eq $workflowName } | 
            Select-Object id -ExpandProperty id
        }
        
        # list runs
        if ($workflowId) {
            Write-Verbose "Retrieving all workflow runs of '$($workflowName)' with id '$($workflowId)'"
            $workflowRuns = gh api -X GET /repos/$GitHubOwner/$GitHubRepo/actions/workflows/$workflowId/runs | 
            ConvertFrom-Json | 
            Select-Object workflow_runs -ExpandProperty workflow_runs
        }

        # set date variable to use to get workflow runs which have been started before the set date
        if ($workflowRunStarted) {
            $removalDate = (Get-Date).AddDays(-$workflowRunStarted)
            Write-Verbose "Workflow runs which have been started before '$($removalDate)' will be removed."
        }
        
    }
    
    process {
        try {
            if ($workflowRuns) {
                # If workflow runs have been retrieved, filter it to get the targeted workflow run ids.
                if ($workflowConclusion) {
                    Write-Verbose "Filtering the '$($workflowConclusion)' workflow runs of '$($workflowName)' with id '$($workflowId)'"
                    $filteredRunIds = $workflowRuns | 
                    Where-Object { $_.conclusion -eq $workflowConclusion } | 
                    Select-Object id -ExpandProperty id
                }
    
                if ($workflowActor) {
                    foreach ($actor in $workflowActor) {
                        Write-Verbose "Filtering '$($actor)' as the actor of workflow runs for '$($workflowName)' with id '$($workflowId)'"
                        $filteredRunIds = $workflowRuns | 
                        Where-Object { $($_.triggering_actor.login) -eq $actor } | 
                        Select-Object id -ExpandProperty id
                    }
        
                }
        
                if ($workflowRunStarted) {
                    Write-Verbose "Filtering the workflow runs of '$($workflowName)' to remove runs which are older then '$($removalDate)'"
                    $filteredRunIds = $workflowRuns | 
                    Where-Object { $_.run_started_at -lt $removalDate } | 
                    Select-Object id -ExpandProperty id
                }

            }
            else {
                Write-Warning "No workflow runs retrieved."
            }
        }
        catch {
            Write-Error "Failed to retrieve worklow runs. $($_.Exception.Message)" -ErrorAction 'Stop'
        }
    }

    end {
        # If there are filtered workflow run ids fetched, output these.
        if ($filteredRunIds) {
            Write-Verbose "Creating a custom object for output"
            foreach ($id in $filteredRunIds) {
                $workflowRunInfo = [pscustomobject]@{
                    GitHubOwner   = $GitHubOwner
                    GitHubRepo    = $GitHubRepo
                    WorkflowName  = $workflowName
                    WorkflowRunId = $id
                }
                Write-Output $workflowRunInfo
            }
        }
        else {
            if ($workflowConclusion) {
                Write-Verbose "No workflow runs matched the set criteria; run conclusion '$($workflowConclusion)'"
            }
            elseif ($workflowActor) {
                Write-Verbose "No workflow runs matched the set criteria; run by workflowActor '$($workflowActor)'"
            }
            elseif ($workflowRunStarted) {
                Write-Verbose "No workflow runs matched the set criteria; removal of runs older then '$($removalDate)'"
            }
            else {
                Write-Verbose "No workflow runs matched to any criteria."
            }
            $workflowRunInfo = [pscustomobject]@{
                GitHubOwner   = $GitHubOwner
                GitHubRepo    = $GitHubRepo
                WorkflowName  = $workflowName
                WorkflowRunId = $null
            }
            Write-Output $workflowRunInfo
        }
    }
}

