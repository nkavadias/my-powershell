<# 
.SYNOPSIS 
Powershell Wrapper for SC.exe to grant either Full control or stop/start control of the 
service to a user/group.
WARNING!! this replaces all existing permissions to AD users/Groups on a service!
If you lose permission to the service, you will have to uninstall/reinstall it


.DESCRIPTION 
Parameters, all are mandatory
.PARAMETER ServiceDisplayName
A single service name or wildcards are acceptable 
eg. 'SQL Server%'  Make sure parameter is greater than 3 characters and does not return more than 12 services
.PARAMETER AccountName 
A domain user or group which will have permission applied.  Current domain name is assumed.
May also be specified using old naming standard of DOMAIN\account
.PARAMETER Permission
Permissions settable on the service for the AccountName.  Must be either:
Modify;
StartAndStopOnly

.EXAMPLE
legacy SQL Server hosts:
Set-WindowsServicePermission -ServiceDisplayName 'SQL Server%' -AccountName AD-Account-or-Group -Permission Modify
.EXAMPLE
TPAM Integrated and new:
Set-WindowsServicePermission -ServiceDisplayName 'SQL Server%' -AccountName AD-Account-or-Group -Permission StartAndStopOnly


.NOTES 
    Author     : Nick Kavadias
.LINK 
   
#> 
function Set-WindowsServicePermission {
param(
  [Parameter(Mandatory=$true)]  [string] [ValidateLength(4,100)] $ServiceDisplayName
 ,[Parameter(Mandatory=$true)]  [string] [ValidateNotNullOrEmpty()] $AccountName
 ,[Parameter(Mandatory=$true)]  [string] [ValidateSet('Modify','StartAndStopOnly')] $Permission
)


## account name checking
$account = $AccountName.ToUpper().Trim()
if ($account -NOTLIKE "*\*")
{ 
     $domain="$($env:USERDOMAIN)"
	 $account=$AccountName.ToUpper().Trim()
}
else
{
     $domain	= $($account.Split("\"))[0]
	 $account	= $($account.Split("\"))[1]
}



## enumerate services which match service display name

$ChangeCount = 0
try   {
		$serviceList = Get-WmiObject win32_service -filter "DisplayName like '$ServiceDisplayName'" #-EnableAllPrivileges
	  }
catch {
       Write-Error "$_" 
	   return 1
      }
	  
## make sure selection isn't too wide	  
if($serviceList.Count -ge $MaxServicelistResult)
{
	Write-Error -Category InvalidData " Greater than $($MaxServicelistResult) services were returned. Use a narrower filter, or make multiple calls" 
	return 1
}

$accountSID = Get-AccountSID -AccountName $account -Domain $domain
if (-not($accountSID -like "S-1-5*"))
{
 Write-Error -Category InvalidData "$account not returning a proper SID"
 return 1
}

##  everything looks good. call sc.exe
foreach ( $service in $serviceList )
		{ 
		write-host "Updating... $($service.name)"
		run-sc -serviceName $($service.name) -accountSID $accountSID
		}

return 0
}

#*********************************
# cmdlet PARAMS
#*********************************
#
[string] $ErrorActionPreference 				= "Continue"
[string] $VerbosePreference 					= "Continue"
[string] $Parent 								= Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
[string] $Leaf									= Split-Path -Path $MyInvocation.MyCommand.Definition -Leaf 
[string] $ScExeLocation							= "$($env:systemroot)\system32\sc.exe"
# sets hard upper limit for services returned with $ServiceDisplayName
[int]    $MaxServicelistResult                  =12



#*********************************
##################################
# functions
##################################
#*********************************

function Get-AccountSID($Domain, $AccountName) {
try {
		$objUser = New-Object System.Security.Principal.NTAccount($Domain, $AccountName)
		return $($($objUser.Translate([System.Security.Principal.SecurityIdentifier])).Value)
	}
catch 
	{
		 Write-Error -Category InvalidResult "## Error: $_.Exception.Message"
		 return 1
	}
}

function Run-Sc([string] $serviceName , [string]$accountSID) {
# dont remove system defaults! will cause access problems
[string] $systemPerms 			= 'D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)%NEWSIDPERMS%S:(AU;FA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)'
[string] $modifyPerms 			= "(A;;DCRPWP;;;$accountSID)"
[string] $startAndStopOnlyPerms	= "(A;;RPWP;;;$accountSID)"
[string[]] $ParamsArray =@()
$paramsArray += "sdset"
$paramsArray += "$serviceName"
if ($permission -eq 'Modify') { $actionPerms = $modifyPerms }
else 						  {$actionPerms  =$startAndStopOnlyPerms}

$paramsArray += $systemPerms.Replace('%NEWSIDPERMS%',$actionPerms)


 try {
		$exe_result = start-process -FilePath $ScExeLocation -ArgumentList $ParamsArray -Wait -PassThru -ErrorAction Stop
		if ($exe_result.ExitCode -ne 0)
			{
    		Write-Error -Category InvalidResult "## Error: sc exited with a failure $($exe_result.ExitCode)." 
    		return 1
			}
			else { Write-Host "Completed."}
     }
	 catch 
	 {
		 Write-Error -Category InvalidResult "## Error: $_.Exception.Message"
		 return 1
	 }

}

export-modulemember -function Set-WindowsServicePermission
