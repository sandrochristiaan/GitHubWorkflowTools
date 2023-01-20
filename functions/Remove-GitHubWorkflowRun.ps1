function Remove-GitHubWorkflowRun {
    <#
        .SYNOPSIS
            Removes GitHub Actions workflow run(s).

        .DESCRIPTION
            The function in this script file removes GitHub Actions workflow run(s).

            !! This function requires gh cli to be installed & an authenticated session to GitHub via gh cli. !!

            Dot source this file before being able to use the function in this file. 
            To load the function into memory execute the following in the shell or create an entry in the $PROFILE:
            . .\Remove-GitHubWorkflowRun.ps1

        .PARAMETER GitHubOwner
            Specifies the name of the GitHub owner where the repository is hosted, from which workflow runs are executed.

        .PARAMETER GitHubRepo
            Specifies the name of the GitHub repository, from which workflow runs are executed.

        .PARAMETER workflowRunId
            Specifies the name of the workflow for which run(s) information will be fetched.

        .INPUTS
            None.

        .OUTPUTS
            None.

        .NOTES
            Version:        0.9
            Author:         @sandrochristiaan
            Creation Date:  20230120
            Purpose/Change: Documented version.
                            
        .EXAMPLE
            Remove-GitHubWorkflowRun -GitHubOwner 'someExampleOwner' -GitHubRepo 'someExampleRepo' -workflowRunId '3344412567'
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$GitHubOwner,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$GitHubRepo,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$workflowRunId
    )
    
    begin {
        # intentionally empty 
    }
    
    process {
        if ($workflowRunId) {
            foreach ($id in $workflowRunId) {
                Write-Verbose "Deleting the filtered run: /repos/$GitHubOwner/$GitHubRepo/actions/runs/$id"
                gh api -X DELETE "/repos/$GitHubOwner/$GitHubRepo/actions/runs/$id"
            }
        }
        else {
            Write-Verbose "No workflow run ids found"
        }

    }
    
    end {
        # intentionally empty  
    }
}