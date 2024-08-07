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
    #>
    param()
    return docker container ls | Select -first 1
}
function Rocktil.ContainerId.FromName {
    <#
    .SYNOPSIS
        returns container id as [string]
    #>
    param(
        # Uses first if not specified
        [ArgumentCompletions('git-logger')]
        [string] $ContainerName = ($script:ModuleConfig.Default.ContainerName ?? 'git-logger')
    )
}

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
