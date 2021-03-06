
[string] $Path = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

$modulePathArray = $($env:PSModulePath) -split ';'
# use first module path (usually the user path, no admin privs required'
[string] $modulePath = $modulePathArray[0]
Write-Host "Using to module path $modulePath"
if ( -not $(Test-Path -LiteralPath $modulePath) )
{ 
	Write-Host "Creating module path $($modulePath)"
    New-Item -ItemType Container -Path $modulePath 
}

$modulesList = $(get-childitem -Path "$Path\*.psm1")

foreach ($file in $modulesList) { 
	Write-Host "Found Module: $file"
	$moduleDir = Join-Path $modulePath $(Get-Item $file).Basename 
	if ( -not $(Test-Path -LiteralPath $moduleDir) )
	{ 
		Write-Host "Creating directory for module $($moduleDir)"
     	New-Item -ItemType Container -Path $moduleDir  
	}
	Copy-Item -Verbose -Force -LiteralPath $file -Destination $moduleDir
	}

