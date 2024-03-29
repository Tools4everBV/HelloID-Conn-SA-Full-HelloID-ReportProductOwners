# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

#HelloID variables
#Note: when running this script inside HelloID; portalUrl and API credentials are provided automatically (generate and save API credentials first in your admin panel!)
$portalUrl = "https://CUSTOMER.helloid.com"
$apiKey = "API_KEY"
$apiSecret = "API_SECRET"
$delegatedFormAccessGroupNames = @("Users") #Only unique names are supported. Groups must exist!
$delegatedFormCategories = @("HelloID","Reporting","Mailbox Reporting") #Only unique names are supported. Categories will be created if not exists
$script:debugLogging = $false #Default value: $false. If $true, the HelloID resource GUIDs will be shown in the logging
$script:duplicateForm = $false #Default value: $false. If $true, the HelloID resource names will be changed to import a duplicate Form
$script:duplicateFormSuffix = "_tmp" #the suffix will be added to all HelloID resource names to generate a duplicate form with different resource names

#The following HelloID Global variables are used by this form. No existing HelloID global variables will be overriden only new ones are created.
#NOTE: You can also update the HelloID Global variable values afterwards in the HelloID Admin Portal: https://<CUSTOMER>.helloid.com/admin/variablelibrary
$globalHelloIDVariables = [System.Collections.Generic.List[object]]@();

#Global variable #1 >> portalBaseUrl
$tmpName = @'
portalBaseUrl
'@ 
$tmpValue = @'
{{portal.baseUrl}}
'@ 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "False"});

#Global variable #2 >> portalApiKey
$tmpName = @'
portalApiKey
'@ 
$tmpValue = "" 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "True"});

#Global variable #3 >> portalApiSecret
$tmpName = @'
portalApiSecret
'@ 
$tmpValue = "" 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "True"});

#Global variable #4 >> HIDreportFolder
$tmpName = @'
HIDreportFolder
'@ 
$tmpValue = @'
C:\HIDreports
'@ 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "False"});


#make sure write-information logging is visual
$InformationPreference = "continue"

# Check for prefilled API Authorization header
if (-not [string]::IsNullOrEmpty($portalApiBasic)) {
    $script:headers = @{"authorization" = $portalApiBasic}
    Write-Information "Using prefilled API credentials"
} else {
    # Create authorization headers with HelloID API key
    $pair = "$apiKey" + ":" + "$apiSecret"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $key = "Basic $base64"
    $script:headers = @{"authorization" = $Key}
    Write-Information "Using manual API credentials"
}

# Check for prefilled PortalBaseURL
if (-not [string]::IsNullOrEmpty($portalBaseUrl)) {
    $script:PortalBaseUrl = $portalBaseUrl
    Write-Information "Using prefilled PortalURL: $script:PortalBaseUrl"
} else {
    $script:PortalBaseUrl = $portalUrl
    Write-Information "Using manual PortalURL: $script:PortalBaseUrl"
}

# Define specific endpoint URI
$script:PortalBaseUrl = $script:PortalBaseUrl.trim("/") + "/"  

# Make sure to reveive an empty array using PowerShell Core
function ConvertFrom-Json-WithEmptyArray([string]$jsonString) {
    # Running in PowerShell Core?
    if($IsCoreCLR -eq $true){
        $r = [Object[]]($jsonString | ConvertFrom-Json -NoEnumerate)
        return ,$r  # Force return value to be an array using a comma
    } else {
        $r = [Object[]]($jsonString | ConvertFrom-Json)
        return ,$r  # Force return value to be an array using a comma
    }
}

function Invoke-HelloIDGlobalVariable {
    param(
        [parameter(Mandatory)][String]$Name,
        [parameter(Mandatory)][String][AllowEmptyString()]$Value,
        [parameter(Mandatory)][String]$Secret
    )

    $Name = $Name + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        $uri = ($script:PortalBaseUrl + "api/v1/automation/variables/named/$Name")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
    
        if ([string]::IsNullOrEmpty($response.automationVariableGuid)) {
            #Create Variable
            $body = @{
                name     = $Name;
                value    = $Value;
                secret   = $Secret;
                ItemType = 0;
            }    
            $body = ConvertTo-Json -InputObject $body -Depth 100
    
            $uri = ($script:PortalBaseUrl + "api/v1/automation/variable")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $variableGuid = $response.automationVariableGuid

            Write-Information "Variable '$Name' created$(if ($script:debugLogging -eq $true) { ": " + $variableGuid })"
        } else {
            $variableGuid = $response.automationVariableGuid
            Write-Warning "Variable '$Name' already exists$(if ($script:debugLogging -eq $true) { ": " + $variableGuid })"
        }
    } catch {
        Write-Error "Variable '$Name', message: $_"
    }
}

function Invoke-HelloIDAutomationTask {
    param(
        [parameter(Mandatory)][String]$TaskName,
        [parameter(Mandatory)][String]$UseTemplate,
        [parameter(Mandatory)][String]$AutomationContainer,
        [parameter(Mandatory)][String][AllowEmptyString()]$Variables,
        [parameter(Mandatory)][String]$PowershellScript,
        [parameter()][String][AllowEmptyString()]$ObjectGuid,
        [parameter()][String][AllowEmptyString()]$ForceCreateTask,
        [parameter(Mandatory)][Ref]$returnObject
    )
    
    $TaskName = $TaskName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        $uri = ($script:PortalBaseUrl +"api/v1/automationtasks?search=$TaskName&container=$AutomationContainer")
        $responseRaw = (Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false) 
        $response = $responseRaw | Where-Object -filter {$_.name -eq $TaskName}
    
        if([string]::IsNullOrEmpty($response.automationTaskGuid) -or $ForceCreateTask -eq $true) {
            #Create Task

            $body = @{
                name                = $TaskName;
                useTemplate         = $UseTemplate;
                powerShellScript    = $PowershellScript;
                automationContainer = $AutomationContainer;
                objectGuid          = $ObjectGuid;
                variables           = (ConvertFrom-Json-WithEmptyArray($Variables));
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100
    
            $uri = ($script:PortalBaseUrl +"api/v1/automationtasks/powershell")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $taskGuid = $response.automationTaskGuid

            Write-Information "Powershell task '$TaskName' created$(if ($script:debugLogging -eq $true) { ": " + $taskGuid })"
        } else {
            #Get TaskGUID
            $taskGuid = $response.automationTaskGuid
            Write-Warning "Powershell task '$TaskName' already exists$(if ($script:debugLogging -eq $true) { ": " + $taskGuid })"
        }
    } catch {
        Write-Error "Powershell task '$TaskName', message: $_"
    }

    $returnObject.Value = $taskGuid
}

function Invoke-HelloIDDatasource {
    param(
        [parameter(Mandatory)][String]$DatasourceName,
        [parameter(Mandatory)][String]$DatasourceType,
        [parameter(Mandatory)][String][AllowEmptyString()]$DatasourceModel,
        [parameter()][String][AllowEmptyString()]$DatasourceStaticValue,
        [parameter()][String][AllowEmptyString()]$DatasourcePsScript,        
        [parameter()][String][AllowEmptyString()]$DatasourceInput,
        [parameter()][String][AllowEmptyString()]$AutomationTaskGuid,
        [parameter(Mandatory)][Ref]$returnObject
    )

    $DatasourceName = $DatasourceName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    $datasourceTypeName = switch($DatasourceType) { 
        "1" { "Native data source"; break} 
        "2" { "Static data source"; break} 
        "3" { "Task data source"; break} 
        "4" { "Powershell data source"; break}
    }
    
    try {
        $uri = ($script:PortalBaseUrl +"api/v1/datasource/named/$DatasourceName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
      
        if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
            #Create DataSource
            $body = @{
                name               = $DatasourceName;
                type               = $DatasourceType;
                model              = (ConvertFrom-Json-WithEmptyArray($DatasourceModel));
                automationTaskGUID = $AutomationTaskGuid;
                value              = (ConvertFrom-Json-WithEmptyArray($DatasourceStaticValue));
                script             = $DatasourcePsScript;
                input              = (ConvertFrom-Json-WithEmptyArray($DatasourceInput));
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100
      
            $uri = ($script:PortalBaseUrl +"api/v1/datasource")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
              
            $datasourceGuid = $response.dataSourceGUID
            Write-Information "$datasourceTypeName '$DatasourceName' created$(if ($script:debugLogging -eq $true) { ": " + $datasourceGuid })"
        } else {
            #Get DatasourceGUID
            $datasourceGuid = $response.dataSourceGUID
            Write-Warning "$datasourceTypeName '$DatasourceName' already exists$(if ($script:debugLogging -eq $true) { ": " + $datasourceGuid })"
        }
    } catch {
      Write-Error "$datasourceTypeName '$DatasourceName', message: $_"
    }

    $returnObject.Value = $datasourceGuid
}

function Invoke-HelloIDDynamicForm {
    param(
        [parameter(Mandatory)][String]$FormName,
        [parameter(Mandatory)][String]$FormSchema,
        [parameter(Mandatory)][Ref]$returnObject
    )
    
    $FormName = $FormName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/forms/$FormName")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        } catch {
            $response = $null
        }
    
        if(([string]::IsNullOrEmpty($response.dynamicFormGUID)) -or ($response.isUpdated -eq $true)) {
            #Create Dynamic form
            $body = @{
                Name       = $FormName;
                FormSchema = (ConvertFrom-Json-WithEmptyArray($FormSchema));
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100
    
            $uri = ($script:PortalBaseUrl +"api/v1/forms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
    
            $formGuid = $response.dynamicFormGUID
            Write-Information "Dynamic form '$formName' created$(if ($script:debugLogging -eq $true) { ": " + $formGuid })"
        } else {
            $formGuid = $response.dynamicFormGUID
            Write-Warning "Dynamic form '$FormName' already exists$(if ($script:debugLogging -eq $true) { ": " + $formGuid })"
        }
    } catch {
        Write-Error "Dynamic form '$FormName', message: $_"
    }

    $returnObject.Value = $formGuid
}


function Invoke-HelloIDDelegatedForm {
    param(
        [parameter(Mandatory)][String]$DelegatedFormName,
        [parameter(Mandatory)][String]$DynamicFormGuid,
        [parameter()][Array][AllowEmptyString()]$AccessGroups,
        [parameter()][String][AllowEmptyString()]$Categories,
        [parameter(Mandatory)][String]$UseFaIcon,
        [parameter()][String][AllowEmptyString()]$FaIcon,
        [parameter()][String][AllowEmptyString()]$task,
        [parameter(Mandatory)][Ref]$returnObject
    )
    $delegatedFormCreated = $false
    $DelegatedFormName = $DelegatedFormName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms/$DelegatedFormName")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        } catch {
            $response = $null
        }
    
        if([string]::IsNullOrEmpty($response.delegatedFormGUID)) {
            #Create DelegatedForm
            $body = @{
                name            = $DelegatedFormName;
                dynamicFormGUID = $DynamicFormGuid;
                isEnabled       = "True";
                useFaIcon       = $UseFaIcon;
                faIcon          = $FaIcon;
                task            = ConvertFrom-Json -inputObject $task;
            }
            if(-not[String]::IsNullOrEmpty($AccessGroups)) { 
                $body += @{
                    accessGroups    = (ConvertFrom-Json-WithEmptyArray($AccessGroups));
                }
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100
    
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
    
            $delegatedFormGuid = $response.delegatedFormGUID
            Write-Information "Delegated form '$DelegatedFormName' created$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormGuid })"
            $delegatedFormCreated = $true

            $bodyCategories = $Categories
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms/$delegatedFormGuid/categories")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $bodyCategories
            Write-Information "Delegated form '$DelegatedFormName' updated with categories"
        } else {
            #Get delegatedFormGUID
            $delegatedFormGuid = $response.delegatedFormGUID
            Write-Warning "Delegated form '$DelegatedFormName' already exists$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormGuid })"
        }
    } catch {
        Write-Error "Delegated form '$DelegatedFormName', message: $_"
    }

    $returnObject.value.guid = $delegatedFormGuid
    $returnObject.value.created = $delegatedFormCreated
}


<# Begin: HelloID Global Variables #>
foreach ($item in $globalHelloIDVariables) {
	Invoke-HelloIDGlobalVariable -Name $item.name -Value $item.value -Secret $item.secret 
}
<# End: HelloID Global Variables #>


<# Begin: HelloID Data sources #>
<# Begin: DataSource "HID-generate-table-report-products-get-product-owners" #>
$tmpPsScript = @'
try {
    #HelloID variables
    $apiKey = $portalApiKey
    $apiSecret = $portalApiSecret

    # Create authorization headers with HelloID API key
    $pair = "$apiKey" + ":" + "$apiSecret"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $key = "Basic $base64"
    $headers = @{"authorization" = $Key}
    # Define specific endpoint URI
    if($PortalBaseUrl.EndsWith("/") -eq $false){
        $PortalBaseUrl = $PortalBaseUrl + "/"
    }    

    try {
        $groupName = $datasource.selectedProduct.ManagedByGroup
        $productName = $datasource.selectedProduct.Name

        Write-information "Searching for product [$productName] owners [$groupName]"
        
        if(-not [String]::IsNullOrEmpty($groupName)) {
            $uri = ($PortalBaseUrl +"api/v1/groups/$groupName")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false

            if(-not [String]::IsNullOrEmpty($response.groupGuid)){
                $members = $response.users
                $membersCount = @($members).Count

                Write-information "Product owners (user count): $membersCount"

                if($membersCount -gt 0){
                    # Lets get all HelloID Users
                    $skip = 0
                    $take = 100
                    $userCount = 1  #fake initial user count to get into the loop
                    
                    while($userCount -gt 0) {
                        $tmpUsers = $null
                        $uri = ($PortalBaseUrl +"api/v1/users?enabled=true&skip=$skip&take=$take")
                        $tmpUsers = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
                        
                        $skip += $take
                        $userCount = @($tmpUsers).Count
                        $hidUsers += $tmpUsers
                    }
                    
                    $userCount = @($hidUsers).Count
                    $userCount
                    
                    # Create hasTable with all HelloID users
                    $hidUserHashtable = @{}
                    foreach($hidUser in $hidUsers){
                        $null = $hidUserHashtable.Add($hidUser.userGUID, $hidUser)
                    }
                    
                    foreach($userGuid in $members) {
                        $returnObject = @{username = $hidUserHashtable.$userGuid.username; firstName = $hidUserHashtable.$userGuid.firstName; lastname = $hidUserHashtable.$userGuid.lastName; email = $hidUserHashtable.$userGuid.contactEmail}
                        Write-output $returnObject
                    }
                } else {
                    return
                }
            }
        }       
    } catch {
        return
    }

} catch {
    Write-error "Searching for product [$productName] owners [$groupName]. Error: $($_.Exception.Message)"
    return
}
'@ 
$tmpModel = @'
[{"key":"lastname","type":0},{"key":"firstName","type":0},{"key":"email","type":0},{"key":"username","type":0}]
'@ 
$tmpInput = @'
[{"description":"","translateDescription":false,"inputFieldType":1,"key":"selectedProduct","type":0,"options":1}]
'@ 
$dataSourceGuid_1 = [PSCustomObject]@{} 
$dataSourceGuid_1_Name = @'
HID-generate-table-report-products-get-product-owners
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_1_Name -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript $tmpPsScript -DatasourceModel $tmpModel -returnObject ([Ref]$dataSourceGuid_1) 
<# End: DataSource "HID-generate-table-report-products-get-product-owners" #>

<# Begin: DataSource "HID-generate-table-report-products-all-products" #>
$tmpPsScript = @'
try {
    #HelloID variables
    $apiKey = $portalApiKey
    $apiSecret = $portalApiSecret

    # Create authorization headers with HelloID API key
    $pair = "$apiKey" + ":" + "$apiSecret"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $key = "Basic $base64"
    $headers = @{"authorization" = $Key}
    # Define specific endpoint URI
    if($PortalBaseUrl.EndsWith("/") -eq $false){
        $PortalBaseUrl = $PortalBaseUrl + "/"
    }    

    $uri = ($PortalBaseUrl +"api/v1/selfservice/products")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
    $products = $response | Sort-Object -Property Name

    $productCount = @($products).Count
    Write-information "Products found: $productCount"

    if($productCount -gt 0){
        foreach($p in $products) {
            $c =  $p.categories -join ", "
            $returnObject = @{Guid = $p.selfServiceProductGUID; Name = $p.Name; ManagedByGroup = $p.managedByGroupName; categories = $c}
            Write-output $returnObject
        }
    } else {
        Return
    }
} catch {
    Write-error "Searching for products. Error: $($_.Exception.Message)"
    return
}
'@ 
$tmpModel = @'
[{"key":"categories","type":0},{"key":"Guid","type":0},{"key":"Name","type":0},{"key":"ManagedByGroup","type":0}]
'@ 
$tmpInput = @'
[]
'@ 
$dataSourceGuid_0 = [PSCustomObject]@{} 
$dataSourceGuid_0_Name = @'
HID-generate-table-report-products-all-products
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_0_Name -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript $tmpPsScript -DatasourceModel $tmpModel -returnObject ([Ref]$dataSourceGuid_0) 
<# End: DataSource "HID-generate-table-report-products-all-products" #>
<# End: HelloID Data sources #>

<# Begin: Dynamic Form "HID - Report - Self Service product owners" #>
$tmpSchema = @"
[{"templateOptions":{},"type":"markdown","summaryVisibility":"Hide element","body":"Please select the Self Service product in order to see the configured product owners (users). There are different export options available on the server running the HelloID Agent.","requiresTemplateOptions":false,"requiresKey":false,"requiresDataSource":false},{"key":"selectedProduct","templateOptions":{"label":"Select product","required":true,"grid":{"columns":[{"headerName":"Name","field":"Name"},{"headerName":"Categories","field":"categories"},{"headerName":"Managed By Group","field":"ManagedByGroup"}],"height":300,"rowSelection":"single"},"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_0","input":{"propertyInputs":[]}},"useFilter":true,"useDefault":false},"type":"grid","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":true},{"key":"grid","templateOptions":{"label":"Product owners","required":false,"grid":{"columns":[{"headerName":"Username","field":"username"},{"headerName":"Email","field":"email"},{"headerName":"First Name","field":"firstName"},{"headerName":"Lastname","field":"lastname"}],"height":300,"rowSelection":"single"},"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_1","input":{"propertyInputs":[{"propertyName":"selectedProduct","otherFieldValue":{"otherFieldKey":"selectedProduct"}}]}},"useFilter":true,"useDefault":false},"type":"grid","summaryVisibility":"Hide element","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":true},{"key":"exportOptions","templateOptions":{"label":"Export options (local export on HelloID Agent server)","useObjects":true,"options":[{"value":"none","label":"Export nothing"},{"value":"selected","label":"Export selected product"},{"value":"all","label":"Export all products"}],"required":true},"type":"radio","defaultValue":"","summaryVisibility":"Show","textOrLabel":"label","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false}]
"@ 

$dynamicFormGuid = [PSCustomObject]@{} 
$dynamicFormName = @'
HID - Report - Self Service product owners
'@ 
Invoke-HelloIDDynamicForm -FormName $dynamicFormName -FormSchema $tmpSchema  -returnObject ([Ref]$dynamicFormGuid) 
<# END: Dynamic Form #>

<# Begin: Delegated Form Access Groups and Categories #>
$delegatedFormAccessGroupGuids = @()
if(-not[String]::IsNullOrEmpty($delegatedFormAccessGroupNames)){
    foreach($group in $delegatedFormAccessGroupNames) {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/groups/$group")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
            $delegatedFormAccessGroupGuid = $response.groupGuid
            $delegatedFormAccessGroupGuids += $delegatedFormAccessGroupGuid
            
            Write-Information "HelloID (access)group '$group' successfully found$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormAccessGroupGuid })"
        } catch {
            Write-Error "HelloID (access)group '$group', message: $_"
        }
    }
    if($null -ne $delegatedFormAccessGroupGuids){
        $delegatedFormAccessGroupGuids = ($delegatedFormAccessGroupGuids | Select-Object -Unique | ConvertTo-Json -Depth 100 -Compress)
    }
}

$delegatedFormCategoryGuids = @()
foreach($category in $delegatedFormCategories) {
    try {
        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories/$category")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid
        
        Write-Information "HelloID Delegated Form category '$category' successfully found$(if ($script:debugLogging -eq $true) { ": " + $tmpGuid })"
    } catch {
        Write-Warning "HelloID Delegated Form category '$category' not found"
        $body = @{
            name = @{"en" = $category};
        }
        $body = ConvertTo-Json -InputObject $body -Depth 100

        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid

        Write-Information "HelloID Delegated Form category '$category' successfully created$(if ($script:debugLogging -eq $true) { ": " + $tmpGuid })"
    }
}
$delegatedFormCategoryGuids = (ConvertTo-Json -InputObject $delegatedFormCategoryGuids -Depth 100 -Compress)
<# End: Delegated Form Access Groups and Categories #>

<# Begin: Delegated Form #>
$delegatedFormRef = [PSCustomObject]@{guid = $null; created = $null} 
$delegatedFormName = @'
HID - Report - Self Service product owners
'@
$tmpTask = @'
{"name":"HID - Report - Self Service product owners","script":"$VerbosePreference = \"SilentlyContinue\"\r\n$InformationPreference = \"Continue\"\r\n$WarningPreference = \"Continue\"\r\n\r\n# variables configured in form\r\n$exportOptions = $form.exportOptions\r\n$selectedProduct = $form.selectedProduct\r\n\r\n\r\ntry {\r\n    #$selectedProductJson = $selectedProduct | ConvertFrom-Json\r\n    $selectedGuid = $selectedProduct.Guid\r\n    \r\n    if($HIDreportFolder.EndsWith(\"\\\") -eq $false){\r\n        $HIDreportFolder = $HIDreportFolder + \"\\\"\r\n    }\r\n    $timeStamp = $(get-date -f yyyyMMddHHmmss)\r\n    $exportFile = $HIDreportFolder + \"_SelfServiceProductOwnerReport\" + $timeStamp + \".csv\"\r\n\r\n    \r\n    #HelloID variables\r\n    $apiKey = $portalApiKey\r\n    $apiSecret = $portalApiSecret\r\n    \r\n    # Create authorization headers with HelloID API key\r\n    $pair = \"$apiKey\" + \":\" + \"$apiSecret\"\r\n    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)\r\n    $base64 = [System.Convert]::ToBase64String($bytes)\r\n    $key = \"Basic $base64\"\r\n    $headers = @{\"authorization\" = $Key}\r\n    # Define specific endpoint URI\r\n    if($PortalBaseUrl.EndsWith(\"/\") -eq $false){\r\n        $PortalBaseUrl = $PortalBaseUrl + \"/\"\r\n    }\r\n    \r\n    # Lets get all HelloID Users\r\n    $hidUsers = $null\r\n    $skip = 0\r\n    $take = 100\r\n    $userCount = 1  #fake initial user count to get into the loop\r\n    \r\n    while($userCount -gt 0) {        \r\n        $tmpUsers = $null\r\n        $uri = ($PortalBaseUrl +\"api/v1/users?enabled=true\u0026skip=$skip\u0026take=$take\")\r\n        $tmpUsers = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType \"application/json\" -Verbose:$false\r\n        \r\n        $skip += $take\r\n        $userCount = @($tmpUsers).Count\r\n        $hidUsers += $tmpUsers\r\n    }\r\n    $userCount = @($hidUsers).Count\r\n    \r\n    # Create hasTable with all HelloID users\r\n    $hidUserHashtable = @{}\r\n    foreach($hidUser in $hidUsers){\r\n        $null = $hidUserHashtable.Add($hidUser.userGUID, $hidUser)\r\n    }\r\n    \r\n    # Get all required HelloID products\r\n    $uri = ($PortalBaseUrl +\"api/v1/selfservice/products\")\r\n    $allProducts = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType \"application/json\" -Verbose:$false \r\n    $productCount = @($allProducts).Count\r\n    \r\n    switch($exportOptions) {\r\n        \"selected\" {\r\n            $products = $allProducts | Where-object {$_.selfServiceProductGUID -eq $selectedGuid}\r\n            break;\r\n        }        \r\n        \"all\" {\r\n            $products = $allProducts\r\n            break;\r\n        }\r\n        \r\n        \"none\" {\r\n            $products = $null\r\n            break;\r\n        }\r\n    }\r\n    \r\n    if([string]::IsNullOrEmpty($products))\r\n    {\r\n        $productCount = $null\r\n    } else {\r\n        $productCount = @($products).Count        \r\n        Write-Information \"Product count: $productCount\"\r\n    }\r\n    \r\n    $exportData = @()\r\n    if ($productCount -gt 0) {\r\n        foreach($p in $products) {                        \r\n            $groupName = $p.managedByGroupName\r\n            if([string]::IsNullOrEmpty($groupName) -eq $false) {\r\n                $uri = ($PortalBaseUrl +\"api/v1/groups/$groupName\")\r\n                $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType \"application/json\" -Verbose:$false \r\n                $groupMembers = $response.users\r\n    \r\n                # get user details from hashtable based on userGUID\r\n                foreach($u in $groupMembers) {\r\n                    $exportData += [pscustomobject]@{\r\n                        \"productName\" = $p.name;\r\n                        \"productCategries\" = ($p.categories -join \", \");\r\n                        \"groupName\" = $groupName;\r\n                        \"userDomain\" = $hidUserHashtable.$u.source;\r\n                        \"userName\" = $hidUserHashtable.$u.userName;\r\n                        \"firstName\" = $hidUserHashtable.$u.firstName;\r\n                        \"lastName\" = $hidUserHashtable.$u.lastName;\r\n                        \"email\" = $hidUserHashtable.$u.contactEmail;\r\n                    }                    \r\n                }\r\n            }\r\n        }\r\n        $exportCount = @($exportData).Count        \r\n        Write-Information \"Export row count: $exportCount\"\r\n        \r\n        $exportData = $exportData | Sort-Object -Property productName, userName\r\n        $exportData | Export-Csv -Path $exportFile -Delimiter \";\" -NoTypeInformation\r\n        \r\n        Write-Information \"Report [$exportFile] containing $exportCount records created successfully\"\r\n        $Log = @{\r\n            Action            = \"Undefined\" # optional. ENUM (undefined = default) \r\n            System            = \"ActiveDirectory\" # optional (free format text) \r\n            Message           = \"Report [$exportFile] containing $exportCount records created successfully\" # required (free format text) \r\n            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n            TargetDisplayName = $exportFile # optional (free format text) \r\n            TargetIdentifier  = \"\" # optional (free format text) \r\n        }\r\n        #send result back  \r\n        Write-Information -Tags \"Audit\" -MessageData $log        \r\n    \r\n    }\r\n} catch {    \r\n    Write-Error \"Could not export Self Service product owner report. Error: $($_.Exception.Message)\"\r\n    $Log = @{\r\n        Action            = \"Undefined\" # optional. ENUM (undefined = default) \r\n        System            = \"ActiveDirectory\" # optional (free format text) \r\n        Message           = \"Failed to export Self Service product owner report\" # required (free format text) \r\n        IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n        TargetDisplayName = $exportFile # optional (free format text) \r\n        TargetIdentifier  = \"\" # optional (free format text) \r\n    }\r\n    #send result back  \r\n    Write-Information -Tags \"Audit\" -MessageData $log\r\n}","runInCloud":false}
'@ 

Invoke-HelloIDDelegatedForm -DelegatedFormName $delegatedFormName -DynamicFormGuid $dynamicFormGuid -AccessGroups $delegatedFormAccessGroupGuids -Categories $delegatedFormCategoryGuids -UseFaIcon "True" -FaIcon "fa fa-info-circle" -task $tmpTask -returnObject ([Ref]$delegatedFormRef) 
<# End: Delegated Form #>

