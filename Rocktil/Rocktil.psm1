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
        [ArgumentCompletions('Warn', 'Info', 'Dim')]
        [Alias('Color')]
        [string] $Theme = 'Info'
    )

    $colorPair = switch( $Theme ) {
        'Info' {
            @{  Fg = 'gray80'
                Bg = 'gray30' }
        }
        'Dim' {
            @{  Fg = 'gray55'
                Bg = 'gray15' }
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
        [ArgumentCompletions('Warn', 'Info', 'Dim')]
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
        switch( $Theme ) {
            'Dim' { # also predent this theme
                $InputObject
                    | Join-String -f '    {0}'
                    | Write-Host @colorPair
                break
            }
            default {
                $InputObject | Write-Host @ColorPair
            }
        }
    }
}

function Rocktil.Container.Ls {
    <#
    .SYNOPSIS
        runs 'docker container ls'
    .EXAMPLE
        Rocktil.Container.Ls
    #>
    [Alias('Rk.Container.ls')]
    [CmdletBinding()]
    param()

    $query = docker container ls
        | CountOf -CountLabel 'Containers Running: '

    $query
}
function Rocktil.Container.StopAll {
    <#
    .SYNOPSIS
        runs 'docker container stop' on all running containers
    #>
    [Alias('Rk.Container.StopAll')]
    [CmdletBinding()]
    param()

    $existing =
        docker container ls

    if( $Existing.count -gt 0 ) {
        $null = # out: stoppedIds
            $Existing
                | CountOf -CountLabel 'Found Running:'
                | docker container stop

    }

    # hr
    $stoppedId =
        $exising | docker container ls
            | CountOf -CountLabel 'Running After:'
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

function Rocktil.Container.FromClosestId {
    <#
    .SYNOPSIS
        lookup container id that matches the start of the full id
    .EXAMPLE
        > $newId = 'fa3194be001e9b27b6dc266d6efbfad64cdb0363bf365c9211ef091b3edd1d01'
        > Rocktil.Container.FromClosestId $newId

        ID           Image      State   Size
        --           -----      -----   ----
        fa3194be001e git-logger running 36.2kB
    #>
    # [Alias('Rk.Container.ls')]
    [CmdletBinding()]
    param(
        [Alias('Id')]
        [string] $FullId
    )
    # first try running
    $query = docker container ls
        | ?{ $FullId.StartsWith( $_.ID ) }

    if( $query.count -eq 0 ) {
        $query = docker container ls --all
            | ?{ $FullId.StartsWith( $_.ID ) }
    }

    if( $Query.Count -eq 0 ) {
        "Did not find a container that starts with: '$FullId'"
        | Write-Host -fg $Fg1 -bg $fg2
    }
    'Found: ' | WriteHost -As Info
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


function Rocktil.Run.Publish {
    <#
    .SYNOPSIS
        Default mode that lets you run --detach and publish ports
    .DESCRIPTION
        By default it opens a toast, letting you know that it finished launching.
        Clicking on it opens localhost with the port number

        Default / implicit behavior:
            - If the same image name is already running a copy, stop it
            - after launching, show Toast notification. Click to open.
    .EXAMPLE
        # Using default ports
        > Rk.Run.Publish -ImageName git-logger
    .EXAMPLE
        # Using -WhatIf to test whether arguments are correct
        > Rocktil.Run.Publish -WhatIf -Port 8081 81 -ImageName git-logger
            Invoke Cmd => docker run --detach --publish 8081:81 git-logger

        > Rocktil.Run.Publish -WhatIf -ImageName git-logger
            Invoke Cmd => docker run --detach --publish 8080:80 git-logger
    .EXAMPLE
        Rk.Run.Publish -Port 8080 -ImageName git-logger
        Rk.Run.Publish -Port 8081 80 -ImageName pssvg
    #>
    [Alias('Rk.Run.Publish')]
    [CmdletBinding()]
    param(
        # The exposed / external port
        [ArgumentCompletions( 8080, 8081, 8082, 9999 )]
        [int] $Port = 8080,

        # mapped port
        [ArgumentCompletions( 80, 81, 8080 )]
        [int] $InternalPort = 80,

        # Container Image Name
        [ArgumentCompletions('git-logger', 'git-logger-pwsh', 'pssvg')]
        [string] $ImageName,

        # never show toast?
        [Alias('NoToastStatus')]
        [switch] $WithoutToast,

        # Do Not run, display the command line arguments that would be used and quit.
        [switch] $WhatIf,

        [switch] $NeverStopExistingContainers
    )
    [string] $portArg = "${Port}:${InternalPort}"

    [List[Object]] $binArgs = @(
        'run', '--detach', '--publish', $PortArg, $ImageName )

    $binArgs
        | Join-String -op 'Invoke Cmd => docker ' -sep ' '
        | WriteHost -As Dim

    if( $WhatIf ) { return }

    if( -not $NeverStopExistingContainers ) {
        $existingIds = # out: runningIds
            docker container ls
                | ?{ $_.Image -eq $ImageName }

        if( $existingIds ) {
            $null = # out: stoppedIds
                $existingIds
                    | CountOf -Label "Stopping Containers of '$ImageName'"
                    | docker container stop
        }
    }

    $newId = & docker @binArgs # docker run --detach --publish $PortArg $Tag

    "Bound ${ImageName} to: http://localhost:${Port} - $newId"
        | WriteHost Info

    if( $WithoutToast ) { return }

    $Msg = "Launched ${ImageName} on localhost:${Port}"
    New-BurntToastNotification -Text $Msg -ActivatedAction {
        Start-Process -FilePath "http://localhost:${Port}"
    }
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
