using namespace System.Collections.Generic
Import-Module Rocker -ea 'stop'

$script:ModuleConfig = @{
    Default = @{
        ContainerName = 'git-logger'
    }
}

# Export-ModuleMember -Function/-Alias uses these patterns:
[List[object]] $ExportMemberPatterns = @(
    'Rocktil.*'
    'Rk.*'
)

# private helper functions. later: refactor directories using modulebuilder
function GetColorPair {
    <#
    .SYNOPSIS
        Internal. select colors by theme or semantic names
    .EXAMPLE
        GetColorPair Warn|Ft -AutoSize

        Name Value
        ---- -----
        Bg   #ebcb8b
        Fg   #807560
    #>
    param(
        [Parameter(Mandatory, Position = 0 )]
        [ArgumentCompletions('Warn', 'Info')]
        [Alias('Color')]
        [string] $Theme = 'Info'
    )

     $colorPair = switch( $Theme ) {
        'Info' {
            @{  Fg = 'gray80'
                Bg = 'gray30' }
        }
        'Warn' {
            @{  Fg = '#807560'
                Bg = '#ebcb8b' }
        }
        'Bad' {
            @{  Fg = '#ff9795' }
        }
        default {
            @{}
        }
    }
    return $colorPair

}
function WriteHost {
    <#
    .SYNOPSIS
        Internal. Sugar to write text with semantic naming for colors
    .EXAMPLE
        0..3 | WriteHost -As Info
    #>
    param(
        [Parameter(Mandatory, Position = 0 )]
        [ArgumentCompletions('Warn', 'Info')]
        [Alias('Color', 'As')]
        [string] $Theme = 'Info',

        [Alias('Text')]
        [Parameter(ValueFromPipeline)]
        $InputObject
    )
    begin {

    }
    process {
        $colorPair = GetColorPair -Theme $Theme
        $InputObject | Write-Host @ColorPair
    }
}

function Rocktil.Container.Ls {
    <#
    .SYNOPSIS
        runs 'docker container ls'
    #>
    [Alias('Rk.Container.ls')]
    [CmdletBinding()]
    param()

    docker container ls | CountOf -CountLabel 'Running: '
}
function Rocktil.Container.StopAll {
    <#
    .SYNOPSIS
        runs 'docker container stop' on all running containers
    #>
    [Alias('Rk.Container.StopAll')]
    [CmdletBinding()]
    param()

    docker container ls
        | CountOf -CountLabel 'Running:'
        | docker container stop

    # hr
    docker container ls
        | OutNull -CountLabel 'Running After:'
}

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
    $logMsg = $binArgs | Join-String -sep ' ' -op 'invoke => docker '


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
