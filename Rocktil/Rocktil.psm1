using namespace System.Collections.Generic
Import-Module Rocker -ea 'stop'

$script:ModuleConfig = @{
    Default = @{
        ContainerName = 'git-logger'
    }
}

[List[object]] $ExportMemberPatterns = @(
    'Rocktil.*'
    'Rk.*'
)

function Rocktil.Container.First {
    <#
    .SYNOPSIS
        get the first container without filtering. return by object (else drill into Name/Id)
    #>
    [Alias('Rk.Container.First')]
    [CmdletBinding()]
    param(
        [Alias('Id')]
        [switch] $AsIdName,

        [Alias('Image')]
        [switch] $AsImageName
    )
    $query = docker container ls | Select -first 1
    if( $AsIdName ) {       return $query.Id    }
    if( $AsImageName ) {    return $query.Image }
    return $query
}
function Rocktil.Container.FromName {
    <#
    .SYNOPSIS
        returns first match, unless using -ListAll
    #>
    [OutputType('docker.container.ls')]
    [Alias(
        'Rk.Container.From',
        'Rk.FromName'
    )]
    [CmdletBinding()]
    param(
        # Uses first if not specified
        [ArgumentCompletions('git-logger')]
        # [ArgCompleterDockerContainerName( FilterState = 'running')] # todo future: (#1)
        [string] $ContainerName = (
            $script:ModuleConfig.Default.ContainerName ?? 'git-logger'),

        [Alias('All')][switch] $ListAll
    )
    if( [string]::IsNullOrWhiteSpace( $ContainerName ) ) {
        return (Rocktil.Container.First)
    }
    if( $ListAll ) {
        $query =
            @( docker container ls ).
                Where({ $_.Image -eq $ContainerName } )

    } else {
        $query =
            @( docker container ls ).
                Where({ $_.Image -eq $ContainerName }, 'first', 1)
    }

    if( $Query.Count -eq 0 ) {
        "No containers found for ContainerName: '$ContainerName' !" | Write-error
        (docker container ls).Image
            | Join-String -sep ', ' -SingleQuote -op 'Valid Container names: '
            | Write-host -fore 'salmon'
        return
    }
    return $query
}

function Rocktil.Container.CopyTo {
    <#
    .SYNOPSIS
        copies files or folders to a running docker container. uses docker sytax: "docker cp source label:destPath"
    #>
    param(
        # file or folder to copy
        [Parameter(Mandatory)]
        [string] $Source,

        [ArgumentCompletions('git-logger')]
        # [ArgCompleterDockerContainerName( FilterState = 'running')] # todo future: (#1)
        [string] $ContainerName = (
            $script:ModuleConfig.Default.ContainerName ?? 'git-logger'),

        # absolute path on destination
        [Parameter(Mandatory)]
        [ArgumentCompletions(
            '/Repos',
            '/tmp'
        )]
        [string] $DestinationPath,

        # print final command but do not run iT.used to double check source and dest paths are correct
        [switch]$WhatIf

    )

    $dockContainer = Rocktil.Container.FromName -ContainerName  $ContainerName -ea 'Stop'
    $sourceItem    = Get-Item -ea 'stop' $Source
    $destTemplate  = '{0}:{1}' -f @(
        $dockContainer.Id # or .ContainerID
        $DestinationPath
    )

    [List[Object]] $BinArgs = @(
        'cp'
        $sourceItem
        $destTemplate
    )
    $logMsg = $binArgs | Join-String -op 'invoke => docker '


    if( $WhatIf ) {
        $logMsg | write-host -fore 'salmon'
        return
    }

    $logMsg | Write-Verbose
    docker @binArgs
}


$exportModuleMemberSplat = @{
    Function = @(
        $ExportMemberPatterns
    )
    Alias = @(
        $ExportMemberPatterns
    )
    Variable = @(
        'Rocktil'
    )
}

Export-ModuleMember @exportModuleMemberSplat
