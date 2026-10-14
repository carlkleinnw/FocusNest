param(
    [Parameter(Mandatory=$true)][ValidatePattern('^v[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)*)?$')][string]$Tag,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Message,
    [string]$Remote = 'origin',
    [string]$ProjectPath = (Split-Path -Parent $PSScriptRoot)
)
$ErrorActionPreference = 'Stop'
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
function Read-Git([string[]]$Arguments) {
    $Result = & git -C $ProjectPath @Arguments
    if ($LASTEXITCODE -ne 0) { throw ('Git command failed: ' + ($Arguments -join ' ')) }
    return ($Result -join "`n").Trim()
}
$Branch = Read-Git -Arguments @('branch','--show-current')
if (-not $Branch) { throw 'Switch to a normal branch before publishing.' }
if (Read-Git -Arguments @('status','--porcelain')) { throw 'Commit all intended changes before publishing a version.' }
$VersionLine = Select-String -LiteralPath (Join-Path $ProjectPath 'pubspec.yaml') -Pattern '^version:\s+(\d+\.\d+\.\d+)'
if (-not $VersionLine) { throw 'Could not read the application version in pubspec.yaml.' }
$AppVersion = $VersionLine.Matches[0].Groups[1].Value
if ($Tag -notmatch ('^v' + [regex]::Escape($AppVersion) + '(?:-|$)')) {
    throw 'The tag version must match pubspec.yaml; use a prerelease suffix for documentation revisions.'
}
Read-Git -Arguments @('remote','get-url',$Remote) | Out-Null
$HeadCommit = Read-Git -Arguments @('rev-parse','HEAD')
$Existing = Read-Git -Arguments @('tag','--list',$Tag)
if ($Existing) {
    $TagCommit = Read-Git -Arguments @('rev-parse',($Tag+'^{commit}'))
    $TagType = Read-Git -Arguments @('cat-file','-t',('refs/tags/'+$Tag))
    if ($TagCommit -ne $HeadCommit -or $TagType -ne 'tag') {
        throw 'The existing tag must not be moved or replaced. Choose a new version tag.'
    }
} else {
    Read-Git -Arguments @('tag','-a',$Tag,'-m',$Message) | Out-Null
}
& git -C $ProjectPath -c push.followTags=true push --atomic --follow-tags $Remote ('HEAD:refs/heads/'+$Branch) ('refs/tags/'+$Tag)
if ($LASTEXITCODE -ne 0) {
    throw 'Publish failed. The local tag was retained; resolve the failure and retry without replacing tags.'
}
Write-Host ('Published '+$Branch+' at '+$HeadCommit+' with tag '+$Tag+'.')
