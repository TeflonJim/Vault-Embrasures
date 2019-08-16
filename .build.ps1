#Requires -Module Indented.RimWorld

param (
    [ValidateSet('Major', 'Minor', 'Build')]
    [String]$ReleaseType = 'Build'
)

task Build Setup,
           Clean,
           UpdateVersion,
           CreatePackage,
           UpdateLocal

task Setup {
    Import-Module Indented.RimWorld -Global

    $Global:buildInfo = [PSCustomObject]@{
        Name            = 'Vault Embrasures'
        PublishedFileID = ''
        Version         = $null
        Path            = [PSCustomObject]@{
            Build     = Join-Path $psscriptroot 'build'
            Source    = Join-Path $psscriptroot 'source'
        }
    }
    $path = Join-Path $psscriptroot 'source\About\Manifest.xml'
    $xDocument = [System.Xml.Linq.XDocument]::Load($path)
    $buildInfo.Version = [Version]$xDocument.Element('Manifest').Element('version').Value
}

task Clean {
    if (Test-Path $buildInfo.Path.Build) {
        Remove-Item $buildInfo.Path.Build -Recurse
    }
    $null = New-Item $buildInfo.Path.Build -ItemType Directory
}

task SetPublishedItemID {
    if ($buildInfo.PublishedFileID) {
        Set-Content (Join-Path $buildInfo.Path.Source 'About\PublishedFileId.txt') -Value $buildInfo.PublishedFileID
    }
}

task UpdateVersion {
    $version = $buildInfo.Version
    $version = switch ($ReleaseType) {
        'Major' { [Version]::new($version.Major + 1, 0, 0) }
        'Minor' { [Version]::new($version.Major, $version.Minor + 1, 0) }
        'Build' { [Version]::new($version.Major, $version.Minor, $version.Build + 1) }
    }

    $path = Join-Path $psscriptroot 'source\About\Manifest.xml'
    $xDocument = [System.Xml.Linq.XDocument]::Load($path)
    $xDocument.Element('Manifest').Element('version').Value = $version
    $xDocument.Save($path)
}

task CreatePackage {
    $params = @{
        Path            = $buildInfo.Path.Source
        DestinationPath = Join-Path $buildInfo.Path.Build ('{0}.zip' -f $buildInfo.Name)
    }
    Compress-Archive @params
}

task UpdateLocal {
    $path = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 294100' -Name 'InstallLocation').InstallLocation
    $modPath = [System.IO.Path]::Combine($path, 'Mods', $buildInfo.Name)

    if (Test-Path $modPath) {
        Remove-Item $modPath -Recurse
    }

    New-Item -Path $modPath -ItemType Directory -Force
    Copy-Item -Path (Join-Path $buildInfo.Path.Source '*') -Destination $modPath -Recurse -Force
}