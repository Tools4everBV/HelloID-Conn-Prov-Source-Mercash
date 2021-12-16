########################################################################
# HelloID-Conn-Prov-Source-Mercash-Persons
#
# Version: 1.0.0
########################################################################
$VerbosePreference = 'Continue'

#region helpers
function ConvertFrom-XmlMerCash {
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[Object]]
        $ArrayList,

        [System.Management.Automation.ScriptBlock]
        $Mapping
    )
    $resultList = [system.collections.generic.List[Object]]::new()
    try {
        foreach ($objectInArray in $ArrayList) {
            $object = [pscustomobject]@{}
            foreach ($field in $objectInArray.fields.field) {
                if ($null -ne $mapping) {
                    $propertyName = $Mapping.Invoke($field.no)
                } else {
                    $propertyName = $field.no
                }
                if ([string]::IsNullOrEmpty($propertyName)) {
                    #   Write-verbose "No Mapped property found for $($field.no)" -Verbose
                    Continue
                }
                $object | Add-Member -NotePropertyMembers @{$propertyName = $field.currentvalue }
            }
            $resultList.Add($object)
        }
        Write-Output $resultList
    } catch {
        $pscmdlet.ThrowTerminatingError($_)
    }
}

function ConvertTo-ListMerCash {
    Param(
        [Parameter(Mandatory)]
        [string]
        $XmlDataMerCash,

        [Parameter(Mandatory)]
        [System.Management.Automation.ScriptBlock]
        $Mapping
    )
    try {
        [xml]$xml = $XmlDataMerCash
        $xmlRecords = $xml.webexport.records.record
        $list = ConvertFrom-XmlMerCash -ArrayList $xmlRecords -Mapping $Mapping
        Write-Output $list
    } catch {
        $PsCmdlet.ThrowTerminatingError($_)
    }
}

#endregion

$funcEmployeeMapping = { param ($PropertyName ) switch ($PropertyName) {
        1 { 'Nr' }
        2 { 'Roepnaam' }
        4 { 'Achternaam' }
        5 { 'Voorletters' }
        11020722 { 'Voorvoegsels' }
        11020715 { 'Voorkeur_naamgebruik' }
        11020767 { 'Mobiel_bedrijf' }
        50 { 'E-mail_bedrijf' }
        14 { 'Mobiel' }
        15 { 'E-mail' }
        26 { 'Manager' }
    } }

$funcPartnerMapping = { param ($PropertyName) switch ($PropertyName) {
        1 { 'Werknemer' }
        2 { 'id' }
        11020721 { 'Eigen_naam' }
        11020722 { 'Voorvoegsels' }
    }
}

$funcEmploymentMapping = { param ($PropertyName) switch ($PropertyName) {
        1 { 'Werknemer' }
        2 { 'DienstverbandNr' }
        11 { 'Omschrijving' }
        12 { 'Datum_in_dienst' }
        13 { 'Datum_uit_dienst' }
        32 { 'Dienstverbandsoort' }
        33 { 'In_dienst_bij' }
    }
}

$funcComponentMapping = { param ($PropertyName) switch ($PropertyName) {
        3 { 'Werknemer' }
        7 { 'Component' }
        8 { 'Ingangsdatum' }
        21 { 'Waarde' }
    }
}

$config = $configuration | ConvertFrom-Json
try {
    Write-Verbose 'Initalize New WebServiceproxy with WSDL'
    $SecurePassword = ConvertTo-SecureString -String $config.password  -AsPlainText -Force
    $Credential = [System.Management.Automation.PSCredential]::new($config.username, $SecurePassword)
    $webservice = New-WebServiceProxy $config.BaseUrl -Credential $Credential -ErrorAction Stop
    if (-not [string]::IsNullOrEmpty($config.ProxyAddress)) {
        $webservice.Proxy = [System.Net.WebProxy]::new($config.ProxyAddress)
    }

    Write-Verbose 'Retrieve Employee Data'
    $employeeData = ([ref]([PSObject]::new()))
    $webservice.FuncGetPageData($config.parMenu, 'EXT_WERK', $null, $employeeData)
    $personList = ConvertTo-ListMerCash -XmlDataMerCash $employeeData.value -Mapping $funcEmployeeMapping


    Write-Verbose 'Retrieve Partner Data'
    $partnerData = ([ref]([PSObject]::new()))
    $webservice.FuncGetPageData($config.parMenu, 'EXT_PART', $null, $partnerData)
    $partnerList = ConvertTo-ListMerCash -XmlDataMerCash $partnerData.value  -Mapping $funcPartnerMapping
    $partnersGrouped = $partnerList | Group-Object -Property 'Werknemer' -AsHashTable -AsString


    Write-Verbose 'Retrieve Employement Data'
    $employementData = ([ref]([PSObject]::new()))
    $webservice.FuncGetPageData($config.parMenu, 'EXT_DVB', $null, $employementData)
    $contractList = ConvertTo-ListMerCash -XmlDataMerCash $employementData.value -Mapping $funcEmploymentMapping
    $contractList = $contractList | Select-Object *, @{name = 'DisplayName'; expression = { $_."DienstverbandNr" } }, @{name = 'ExternalId'; expression = { $_."DienstverbandNr" } }
    $contracstGrouped = $contractList | Group-Object -Property "Werknemer" -AsHashTable -AsString


    Write-Verbose 'Combine Data with personList + Retrieve Component Data foreach person'
    foreach ($person in $personList) {

        # Combine Contracts with Person
        $person | Add-Member @{'ExternalId' = $person.Nr }
        $person | Add-Member @{'DisplayName' = $person.ExternalId }
        $person | Add-Member @{'Contracts' = $contracstGrouped[$person.ExternalId] } -Force


        # Combine Partner Table with Person
        # 2/Id contains a Magic number like 1000 , 2000, 3000. I assumed the highest number is the latest record.
        $partnerName = $partnersGrouped["$($person.ExternalId)"] | Sort-Object 'id' -Descending | Select-Object -First 1
        $person | Add-Member  @{'Partner' = [pscustomobject]$partnerName } -Force


        if ($null -eq $person.Contracts) {
            # Skip person without a contract
            continue
        }
        #Add manager property to each contract
        if ([string]::IsNullOrEmpty($person.Manager)) {
            $person.Contracts | Add-Member @{ Manager = $person.Manager }
        }


        # Retrieve Component Data foreach person   # There is no List call (yet)"
        $componentData = ([ref]([PSObject]::new()))
        $webservice.FuncGetPageData($config.parMenu, 'EXT_COMP', ($person.ExternalId), $componentData)
        [xml]$componentDataXML = $componentData.value
        $componentListXml = $componentDataXML.webexport.records.record
        $componentList = ConvertFrom-XmlMerCash -ArrayList $componentListXml -Mapping $funcComponentMapping # Mapping component list

        # Filter latsted components based on Ingangsdatum
        $uniqueComponentList = $componentList  | Group-Object -Property Component | ForEach-Object { $_.Group | Sort-Object -Property Ingangsdatum -Descending | Select-Object -First 1 }
        #Update Contract Object with Component Properties
        foreach ($component in $uniqueComponentList) {
            $person.Contracts | Add-Member @{$component.Component = $($component.Waarde) }
        }
    } # End foreach Loop
} catch {
    Write-Verbose "$($_)   $($_.ScriptStackTrace)" -Verbose
} finally {
    Write-Output ($personList | ConvertTo-Json -Depth 10)
}