<#
.DESCRIPTION
This is a script that makes a request to the cloudflare API and outputs the result to a CSV file.

.PARAMETER BearerToken
A string representing the bearer token to use for executing the request

.PARAMETER outFilePath
A string representing the target destination for the output file

#TODO: Add Some exception handling around web requests failing
#TODO: Add some exception handling around 
#TODO: try to write to working directory if unable write to documents folder
#TODO: Figure out a more elegant way to convert PSCustomObjects to CSV for PS 5.1 ref https://github.com/PowerShell/PowerShell/pull/11029


.NOTES
    AUTHOR: Adrian Strat
    LASTEDIT: October 11, 2022
    
    requests:
    -Upload All Code to Github
    -Must Target PS 5.1 w/ no additional modules

.EXAMPLE
    #Simple example
    ./UCLA_challenge.ps1 -BearerToken '123456'

    #To write to a custom path
    ./UCLA_challenge.ps1 -BearerToken '123456' -outFilePath 'C:\my\custom\path\out.csv'

#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
Param(
    [Parameter(mandatory = $true)][string]$BearerToken,
    [Parameter()][string]$outFilePath = ".\Step3results.csv"
)

##Step1: Convert the following curl command to a PowerShell native solution.
<#
curl -X GET "https://api.cloudflare.com/client/v4/radar/ranking/top?limit=100&name=main_series&location=US&date=$(date +'%Y-%m-%d)&format=json" \
                             -H "Authorization: Bearer excluded" \
                             -H "Content-Type: application/json"
#>
$currentDate = Get-Date -Format "yyyy-MM-dd"
$headers = @{
    'Authorization' = "Bearer ${BearerToken}"
    'Content-Type'  = 'application/json'
}
$response = Invoke-WebRequest -Uri "https://api.cloudflare.com/client/v4/radar/ranking/top?limit=100&name=main_series&location=US&date=${currentDate}&format=json" -Headers $headers -Method GET
Write-Host $response.Content

#Step2: Parse the output and display the domain name, ip address, system of authority, and the ip address of the authority.
#is "System of Authority" same as "Start of Authority"?
#what would you like when no IP addresses are returned (domains only with SOA) or obviously false records are returned (127.0.0.1)?

#Step3: The report file should be in a CSV format and produced by the powershell code.
#how to deal with multiple values per column "1,2,3"?
$responseObject = ConvertFrom-JSON ($response.Content)
$domainList = $responseObject.result.main_series.domain
$hashlist = @()
$csvColumnHeaders = '"Domain","Host_IPs","SOA_Name","SOA_IPs"'


#IF CSV exists go ahead to clear it out, if it doesn't exist create it
if (!(Test-Path $outFilePath)) {
    New-Item -path $outFilePath -type "file" -value ""
}
else {
    Clear-Content -path $outFilePath -Force
    Write-Host "File already exists, clearing it"
}

#Append column headers to CSV
Out-File -FilePath $outFilePath -InputObject $csvColumnHeaders -Append

Foreach ($domain IN $domainList) {
    
    #domain name, ip address, system of authority, ip of SoA
    $SOAResult = Resolve-DnsName -Name $domain -Type SOA -DnsOnly
    $ARecordResult = Resolve-DnsName -Name $domain -DnsOnly
    $hostIPs = $ARecordResult.IPAddress -join ","
    $SOAName = $SOAResult.PrimaryServer
    $IPv4SOAIP = $SOAResult.IP4Address
    $IPv6SOAIP = $SOAResult.IP6Address
    IF ($IPv4SOAIP) {
        $SOAIPs = $IPv4SOAIP
        IF ($IPv6SOAIP) { $SOAIPs = "$IPv4SOAIP,$IPv6SOAIP" }
    }
    ELSE { $SOAIPs = $IPv6SOAIP }
    
    
    [PSCustomObject]$domainHash = @{
        Domain   = $domain
        Host_IPs = $hostIPs
        SOA_Name = $SOAName
        SOA_IPs  = $SOAIPs
    }

    $domainHash | Format-Table

    $csvString = '"' + ${domain} + '","' + ${hostIPs} + '","' + ${SOAName} + '","' + ${SOAIPs} + '"'
    Out-File -FilePath $outFilePath -InputObject $csvString -Append

    #Figured this could be useful later if there's an elegant way to convert a list of hashtables to CSV in PS 5.1
    $hashlist += $domainHash
}


