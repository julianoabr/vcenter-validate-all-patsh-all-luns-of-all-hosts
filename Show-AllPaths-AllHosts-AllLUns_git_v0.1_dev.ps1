#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.Synopsis
   Validate All Paths of All Luns of All Host of a Given vCenter
.DESCRIPTION
   Validate All Paths of All Luns of All Host of a Given vCenter
.EXAMPLE
   Just Run the Script
.EXAMPLE
   Another example of how to use this cmdlet
.SOURCE
   Based on KB https://kb.vmware.com/s/article/1003973
   Based on Article: https://docs.netapp.com/us-en/ontap-fli/san-migration/task_multipath_verification_for_esxi_hosts.html
.CREATOR
   Juliano Alves de Brito Ribeiro (find me at julianoalvesbr@live.com or https://github.com/julianoabr or https://youtube.com/@powershellchannel)
.VERSION
   0.3
.ENVIRONMENT
   Production
.TO THINK

PSALMS 19. v 1 - 4
1. The heavens declare the glory of God;
the skies proclaim the work of his hands.
2. Day after day they pour forth speech;
night after night they reveal knowledge.
3. They have no speech, they use no words;
no sound is heard from them.
4. Yet their voice goes out into all the earth,
their words to the ends of the world.

#>


Set-executionpolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Verbose -Force -ErrorAction SilentlyContinue # Execute Policy  

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

#VALIDATE IF OPTION IS NUMERIC
function isNumeric ($x) {
    $x2 = 0
    $isNum = [System.Int32]::TryParse($x, [ref]$x2)
    return $isNum
} #end function is Numeric

#FUNCTION CONNECT TO VCENTER
function ConnectTo-vCenterServer
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateSet('Manual','Automatic')]
        $methodToConnect = 'Manual',

        # Param2 help description
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [ValidatValidateSet('vc1','vc2','vc3','vc4','vc5','vc6','vc7')]
        [System.String]$vCenterToConnect, 
        
        [Parameter(Mandatory=$false,
                   Position=2)]
        [System.String[]]$vCSrvList, 
                
        [Parameter(Mandatory=$false,
                   Position=3)]
        [ValidateSet('domain.local','vsphere.local','system.domain','mydomain.automite')]
        [System.String]$suffix, 

        [Parameter(Mandatory=$false,
                   Position=4)]
        [ValidateSet('80','443')]
        [System.String]$port = '443'
    )

        

    if ($methodToConnect -eq 'Automatic'){
                
        $Script:workingServer = $vCenterToConnect + '.' + $suffix
        
        Disconnect-VIServer -Server * -Confirm:$false -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

        $vcInfo = Connect-VIServer -Server $Script:WorkingServer -Port $Port -WarningAction Continue -ErrorAction Stop
           
    
    }#end of If Method to Connect
    else{
        
        Disconnect-VIServer -Server * -Confirm:$false -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

        $workingLocationNum = ""
        
        $tmpWorkingLocationNum = ""
        
        $Script:WorkingServer = ""
        
        $i = 0

        #MENU SELECT VCENTER
        foreach ($vcServer in $vCSRVList){
	   
                $vcServerValue = $vcServer
	    
                Write-Output "            [$i].- $vcServerValue ";	
	            
                $i++	
                
                }#end foreach	
                Write-Output "            [$i].- Exit this script ";

                while(!(isNumeric($tmpWorkingLocationNum)) ){
	                $tmpWorkingLocationNum = Read-Host -Prompt "Type the number of vCenter that you want to Log In"
                }#end of while

                    $workingLocationNum = ($tmpWorkingLocationNum / 1)

                if(($WorkingLocationNum -ge 0) -and ($WorkingLocationNum -le ($i-1))  ){
	                $Script:WorkingServer = $vCSrvList[$WorkingLocationNum]
                }
                else{
            
                    Write-Host "Exit selected, or Invalid choice number. End of Script " -ForegroundColor Red -BackgroundColor White
            
                    Exit;
                }#end of else

        #Connect to Vcenter
        $vcInfo = Connect-VIServer -Server $Script:WorkingServer -Port $port -WarningAction Continue -ErrorAction Continue
  
    
    }#end of Else Method to Connect

}#End of Function Connect to Vcenter


#DEFINE VCENTER LIST
$vcServerList = @();

#ADD OR REMOVE vCenters - Insert FQDN of your vCenter(s)        
$vcServerList = ('vc1','vc2','vc3','vc4','vc5','vc6','vc7') | Sort-Object

Do
{
 
        $tmpMethodToConnect = Read-Host -Prompt "Type (Manual) if you want to choose VC to Connect. Type (Automatic) if you want to Type the Name of VC to Connect"

        if ($tmpMethodToConnect -notmatch "^(?:manual\b|automatic\b)"){
    
            Write-Host "You typed an invalid word. Type only (manual) or (automatic)" -ForegroundColor White -BackgroundColor Red
    
        }
        else{
    
            Write-Host "You typed a valid word. I will continue =D" -ForegroundColor White -BackgroundColor DarkBlue
    
        }
    
    }While ($tmpMethodToConnect -notmatch "^(?:manual\b|automatic\b)")


if ($tmpMethodToConnect -match "^\bautomatic\b$"){

    $tmpSuffix = Read-Host "Write the suffix of VC that you want to connect (host.intranet or uolcloud.intranet)"

    $tmpVC = Read-Host "Write the hostname of VC that you want to connect"

    ConnectTo-vCenterServer -vCenterToConnect $tmpVC -suffix $tmpSuffix -methodToConnect Automatic


}
else{

    ConnectTo-vCenterServer -methodToConnect $tmpMethodToConnect -vCSrvList $vcServerList

}#end of else

###################################################################################################################################################################
#MAIN SCRIPT

#Define Variables

$outputPath = "$env:SystemDrive\Output\Vsphere\ESXiHost\Paths"

$actualDate = (Get-date -Format "ddMMyyyy-HHmm").ToString()

$ESXiHostList = @()

$dsNameList = @()

#HOSTS - Get only hosts poweredon and connected
$ESXiHostList = (Get-VMHost | Where-Object -FilterScript {($PSItem.ConnectionState -eq 'Connected' -or $PSItem.ConnectionState -eq 'Maintenance') -and ($PSItem.PowerState -eq 'PoweredOn')} | Select-Object -ExpandProperty Name | Sort-Object)

$totalESXiHosts = $ESXiHostList.Count

$esxiCounter = 1

#Datastores
$dsNameList = (Get-Datastore | Where-Object -FilterScript {($Psitem.Accessible -eq $true) -and ($Psitem.State -eq 'AVailable') -and ($PSItem.ExtensionData.Info.Vmfs.Local -eq $false)} | Select-Object -ExpandProperty Name | Sort-Object)

$totalDAtastores = $dsNameList.Count

foreach ($ESXiHost in $ESXiHostList){
    
    # Parent progress
    Write-Progress -Activity "Getting ESXi Datastore Info" -Status "Processing Host $esxiCounter of $totalESXiHosts" -PercentComplete (($esxiCounter / $totalESXiHosts) * 100) -id 1
        
    $dsCounter = 1

    foreach ($dsName in $dsNameList)
    {
                        
        # Child progress (nested within the parent)
        Write-Progress -Id 2 -ParentId 1 -Activity "Colecting Information of DS $dsCounter" -Status "DS $dscounter of $totalDatastores" -PercentComplete (($dsCounter / $totalDatastores) * 100)

        $dsObj = Get-Datastore -Name $dsName

        #for test purpose only
        #$dsObj = Get-Datastore -Name 'DS-TESTE-NAME'

        $dsNAADevice = $dsObj.ExtensionData.Info.Vmfs.Extent.DiskName

        #$esxcli = Get-EsxCli -VMHost $ESXiHost

        $esxcli = get-esxcli -V2 -VMHost $ESXiHost

        $esxcli.storage.core.path.list.Invoke() | Where-Object {$_.Device -match $dsNAADevice} | Select-Object -Property @{n='ESXi_Name';e={$ESXiHost}},Device,@{n='DS_Name';e={$dsName}},Adapter,AdapterIdentifier,RunTimeName,State |
Export-Csv -Path "$outputPath\AllPaths-AllHosts-$Script:WorkingServer-$actualDate.csv" -NoTypeInformation -Append
        
        $dsCounter++

    }#end of foreach DS

    $esxiCounter++

}#end forEach Esxi Host
