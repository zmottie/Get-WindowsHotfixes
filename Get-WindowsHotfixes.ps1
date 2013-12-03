Function Get-WindowsHotfixes {

<#
.SYNOPSIS
PowerShell function intended for checking Windows Server hosts for hotfixes and updates published for Hyper-V and Failover Cluster rule in Windows Server 2012.
.DESCRIPTION
PowerShell script intended for checking Windows Server hosts for hotfixes and updates published for Hyper-V and Failover Cluster rule in Windows Server 2012, `
list of hotfixes are taken from files UpdatesListCluster.xml and UpdatesListHyperV.xml 
.PARAM Hostname
One or more computer names to operate against. Accepts pipeline input ByValue and ByPropertyName.
.PARAM ClusterName

.PARAM Download

.PARAM DownloadPath
Folder on the disk where download hotfixes must be stored

.PARAM UseIEProxy

.PARAM UncompressDownloaded

.EXAMPLE
Get-WindowsHotfixes -Hostname COMPUTERNAME

.NOTES
Remake of Christian Edwards script to make it more flexible
http://blogs.technet.com/b/cedward/archive/2013/05/31/validating-hyper-v-2012-and-failover-clustering-hotfixes-with-powershell-part-2.aspx

For the version history please check RELEASE.txt file

#>



[CmdletBinding()]

param
(

    [parameter(ValueFromPipeline=$true,  
                   Position=0)]
    [string]$Hostname,

    [parameter(ValueFromPipeline=$true, 
                   Position=1)]
    $ClusterName,
	
	[parameter]
    [switch]$Download,

	[parameter]
    [string]$DownloadPath,
	
	[parameter]
	[swith]$UseIEProxy
	
	[parameter]
	[swithc]$UncompressDownloaded

)

#Current user proxy settings are used
if ($UseIEProxy) {

	$ProxySettings = [System.Net.WebRequest]::GetSystemWebProxy()
	
	$ProxySettings.Credentials = [System.Net.CredentialCache]::DefaultCredentials
	
}

#Getting current execution path
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$listofHotfixes = @()

#Loading list of updates from XML files

[xml]$SourceFileHyperV = Get-Content $dir\UpdatesListHyperV.xml
[xml]$SourceFileCluster = Get-Content $dir\UpdatesListCluster.xml

$HyperVHotfixes = $SourceFileHyperV.Updates.Update
$ClusterHotfixes = $SourceFileCluster.Updates.Update

#Getting installed Hotfixes from all nodes of the Cluster
if ($ClusterName){
    $Nodes = Get-Cluster $ClusterName | Get-ClusterNode | Select -ExpandProperty Name
}else
{
    $Nodes = $Hostname
}
foreach($Node in $Nodes)
{
$Hotfixes = Get-WmiObject -Class Win32_QuickFixEngineering | select description,hotfixid,installedon 

foreach($RecomendedHotfix in $HyperVHotfixes)
{
        $witness = 0
        foreach($hotfix in $Hotfixes)
        {
                If($RecomendedHotfix.id -eq $hotfix.HotfixID)
                {
                    $obj = [PSCustomObject]@{
                        HyperVNode = $Node
                        HotfixType = "Hyper-V"
                        RecomendedHotfix = $RecomendedHotfix.Id
                        Status = "Installed"
                        Description = $RecomendedHotfix.Description
                        DownloadURL =  $RecomendedHotfix.DownloadURL
                    } 
                   
                   $listOfHotfixes += $obj
                    $witness = 1
                 }
        }  
        if($witness -eq 0)
        {
            
            $obj = [PSCustomObject]@{
                    HyperVNode = $Node
                    HotfixType = "Hyper-V"
                    RecomendedHotfix = $RecomendedHotfix.Id
                    Status = "Not Installed"
                    Description = $RecomendedHotfix.Description
                    DownloadURL =  $RecomendedHotfix.DownloadURL
            } 
                   
            $listofHotfixes += $obj
 
        }

}

foreach($RecomendedClusterHotfix in $ClusterHotfixes)
{
        $witness = 0
        foreach($hotfix in $Hotfixes)
        {
                If($RecomendedClusterHotfix.id -eq $hotfix.HotfixID)
                {
                    $obj = [PSCustomObject]@{
                        HyperVNode = $Node
                        HotfixType = "Cluster"
                        RecomendedHotfix = $RecomendedClusterHotfix.Id
                        Status = "Installed"
                        Description = $RecomendedClusterHotfix.Description
                        DownloadURL =  $RecomendedClusterHotfix.DownloadURL
                    } 
                   
                   $listOfHotfixes += $obj
   
                   $witness = 1
                 }
        }  
        if($witness -eq 0)
        {
            $obj = [PSCustomObject]@{
                HyperVNode = $Node
                HotfixType = "Cluster"
                RecomendedHotfix = $RecomendedClusterHotfix.Id
                Status = "Not Installed"
                Description = $RecomendedClusterHotfix.Description
                DownloadURL =  $RecomendedClusterHotfix.DownloadURL
            } 
                   
            $listOfHotfixes += $obj
          
        }
}
}
if ($Download){
    foreach($RecomendedHotfix in $HyperVHotfixes){
        if ($RecomendedHotfix.DownloadURL -ne ""){
            Start-BitsTransfer -Source $RecomendedHotfix.DownloadURL -Destination $DownloadPath 
        }
    }
    foreach($RecomendedClusterHotfix in $ClusterHotfixes){
        if ($RecomendedClusterHotfix.DownloadURL -ne ""){
            Start-BitsTransfer -Source $RecomendedClusterHotfix.DownloadURL -Destination $DownloadPath 
        }
    }
}

$listofHotfixes

}