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
        get the first container without filtering. return by object else id
    #>
    [Alias('Rk.Container.First')]
    param(
        [Alias('Id')]
        [switch] $AsIdName,

        [Alias('Image')]
        [switch] $AsImageName
    )
    $query = docker container ls | Select -first 1
    if( $AsIdName ) { return $query.Id }
    if( $AsImageName ) { return $query.Image }
    return $query
}
function Rocktil.Container.FromName {
    <#
    .SYNOPSIS
        returns container id as [string]
    #>
    [Alias(
        'Rk.Container.From',
        'Rk.FromName'
    )]
    param(
        # Uses first if not specified
        [ArgumentCompletions('git-logger')]
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

# function Rocktil.ContainerId.FromName {
#     param( [string] $Name = 'git-logger' )
# }
# Docker.ContainerId.FromName -Name 'git-logger'

$exportModuleMemberSplat = @{
    Function = @(
        $ExportMemberPatterns
    )
    Alias = @(
        $ExportMemberPatterns
    )
    Variable = @(
        'Docktil'
    )
}

Export-ModuleMember @exportModuleMemberSplat
