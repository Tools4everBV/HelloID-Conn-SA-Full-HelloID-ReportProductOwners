#HelloID variables
$PortalBaseUrl = "https://CUSTOMER.helloid.com"
$apiKey = "API_KEY"
$apiSecret = "API_SECRET"
$delegatedFormAccessGroupName = "Users"
 
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
 
function Write-ColorOutput($ForegroundColor) {
    # save the current color
    $fc = $host.UI.RawUI.ForegroundColor

    # set the new color
    $host.UI.RawUI.ForegroundColor = $ForegroundColor

    # output
    if ($args) {
        Write-Output $args
    }
    else {
        $input | Write-Output
    }

    # restore the original color
    $host.UI.RawUI.ForegroundColor = $fc
}




$variableName = "HIDinternalApiKey"
$variableGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/automation/variables/named/$variableName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
  
    if([string]::IsNullOrEmpty($response.automationVariableGuid)) {
        #Create Variable
        $body = @{
            name = "$variableName";
            value = '';
            secret = "true";
            ItemType = 0;
        }
  
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/automation/variable")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $variableGuid = $response.automationVariableGuid

        Write-ColorOutput Green "Variable '$variableName' created: $variableGuid"
    } else {
        $variableGuid = $response.automationVariableGuid
        Write-ColorOutput Yellow "Variable '$variableName' already exists: $variableGuid"
    }
} catch {
    Write-ColorOutput Red "Variable '$variableName'"
    $_
}
  
  
  
$variableName = "HIDinternalApiSecret"
$variableGuid = ""

try {
    $uri = ($PortalBaseUrl +"api/v1/automation/variables/named/$variableName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
  
    if([string]::IsNullOrEmpty($response.automationVariableGuid)) {
        #Create Variable
        $body = @{
            name = "$variableName";
            value = '';
            secret = "true";
            ItemType = 0;
        }
  
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/automation/variable")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $variableGuid = $response.automationVariableGuid

        Write-ColorOutput Green "Variable '$variableName' created: $variableGuid"
    } else {
        $variableGuid = $response.automationVariableGuid
        Write-ColorOutput Yellow "Variable '$variableName' already exists: $variableGuid"
    }
} catch {
    Write-ColorOutput Red "Variable '$variableName'"
    $_
}



$variableName = "HIDreportFolder"
$variableGuid = ""

try {
    $uri = ($PortalBaseUrl +"api/v1/automation/variables/named/$variableName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
  
    if([string]::IsNullOrEmpty($response.automationVariableGuid)) {
        #Create Variable
        $body = @{
            name = "$variableName";
            value = 'C:\HIDreports\';
            secret = "true";
            ItemType = 0;
        }
  
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/automation/variable")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $variableGuid = $response.automationVariableGuid

        Write-ColorOutput Green "Variable '$variableName' created: $variableGuid"
    } else {
        $variableGuid = $response.automationVariableGuid
        Write-ColorOutput Yellow "Variable '$variableName' already exists: $variableGuid"
    }
} catch {
    Write-ColorOutput Red "Variable '$variableName'"
    $_
}
 
 
 
 
$taskName = "HID-get-all-products"
$taskGetAllProductsGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/automationtasks?search=$taskName&container=1")
    $response = (Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false) | Where-Object -filter {$_.name -eq $taskName}
  
    if([string]::IsNullOrEmpty($response.automationTaskGuid)) {
        #Create Task
  
        $body = @{
            name = "$taskName";
            useTemplate = "false";
            powerShellScript = @'
            try {
                #HelloID variables
                $apiKey = $HIDinternalApiKey
                $apiSecret = $HIDinternalApiSecret
            
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
                HID-Write-Summary -Message "Products found: $productCount" -Event Information
            
                if($productCount -gt 0){
                    foreach($p in $products) {
                        $c =  $p.categories -join ", "
                        $returnObject = @{Guid = $p.selfServiceProductGUID; Name = $p.Name; ManagedByGroup = $p.managedByGroupName; categories = $c}
                        Hid-Add-TaskResult -ResultValue $returnObject
                    }
                } else {
                    Hid-Add-TaskResult -ResultValue []
                }
            
            } catch {
                HID-Write-Status -Message "Searching for products. Error: $($_.Exception.Message)" -Event Error
                HID-Write-Summary -Message "Searching for products" -Event Failed
                 
                Hid-Add-TaskResult -ResultValue []
            }
'@;
            automationContainer = "1";
            variables = @()
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/automationtasks/powershell")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $taskGetAllProductsGuid = $response.automationTaskGuid

        Write-ColorOutput Green "Powershell task '$taskName' created: $taskGetAllProductsGuid"  
    } else {
        #Get TaskGUID
        $taskGetAllProductsGuid = $response.automationTaskGuid
        Write-ColorOutput Yellow "Powershell task '$taskName' already exists: $taskGetAllProductsGuid"
    }
} catch {
    Write-ColorOutput Red "Powershell task '$taskName'"
    $_
}
  
  
  
$dataSourceName = "HID-get-all-products"
$dataSourceGetAllProductsGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/datasource/named/$dataSourceName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
  
    if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
        #Create DataSource
        $body = @{
            name = "$dataSourceName";
            type = "3";
            model = @(@{key = "categories"; type = 0}, @{key = "Guid"; type = 0}, @{key = "ManagedByGroup"; type = 0}, @{key = "Name"; type = 0});
            automationTaskGUID = "$taskGetAllProductsGuid";
            input = @()
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/datasource")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
          
        $dataSourceGetAllProductsGuid = $response.dataSourceGUID
        Write-ColorOutput Green "Task data source '$dataSourceName' created: $dataSourceGetAllProductsGuid"
    } else {
        #Get DatasourceGUID
        $dataSourceGetAllProductsGuid = $response.dataSourceGUID
        Write-ColorOutput Yellow "Task data source '$dataSourceName' already exists: $dataSourceGetAllProductsGuid"
    }
} catch {
    Write-ColorOutput Red "Task data source '$dataSourceName'"
    $_
}

 
 

$taskName = "HID-get-product-owners"
$taskGetProductOwnersGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/automationtasks?search=$taskName&container=1")
    $response = (Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false) | Where-Object -filter {$_.name -eq $taskName}
  
    if([string]::IsNullOrEmpty($response.automationTaskGuid)) {
        #Create Task
  
        $body = @{
            name = "$taskName";
            useTemplate = "false";
            powerShellScript = @'
            try {
                #HelloID variables
                $apiKey = $HIDinternalApiKey
                $apiSecret = $HIDinternalApiSecret

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
                    $groupName = $formInput.selectedProduct.ManagedByGroup
                    $productName = $formInput.selectedProduct.Name

                    HID-Write-Summary -Message "Searching for product [$productName] owners [$groupName]" -Event Information
                    
                    if([String]::IsNullOrEmpty($groupName) -eq $true) {
                        Hid-Add-TaskResult -ResultValue []
                    } else {
                        $uri = ($PortalBaseUrl +"api/v1/groups/$groupName")
                        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false

                        if([String]::IsNullOrEmpty($response.groupGuid) -eq $true){
                            Hid-Add-TaskResult -ResultValue []
                        } else {
                            $members = $response.users
                            $membersCount = @($members).Count

                            HID-Write-Summary -Message "Product owners (user count): $membersCount" -Event Information

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
                                    Hid-Add-TaskResult -ResultValue $returnObject
                                }
                            } else {
                                Hid-Add-TaskResult -ResultValue []
                            }
                        }
                    }       
                } catch {
                    Hid-Add-TaskResult -ResultValue []
                }

            } catch {
                HID-Write-Status -Message "Searching for product [$productName] owners [$groupName]. Error: $($_.Exception.Message)" -Event Error
                HID-Write-Summary -Message "Searching for product [$productName] owners [$groupName]" -Event Failed
                    
                Hid-Add-TaskResult -ResultValue []
            }
'@;
            automationContainer = "1";
            variables = @()
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/automationtasks/powershell")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $taskGetProductOwnersGuid = $response.automationTaskGuid

        Write-ColorOutput Green "Powershell task '$taskName' created: $taskGetProductOwnersGuid"  
    } else {
        #Get TaskGUID
        $taskGetProductOwnersGuid = $response.automationTaskGuid
        Write-ColorOutput Yellow "Powershell task '$taskName' already exists: $taskGetProductOwnersGuid"
    }
} catch {
    Write-ColorOutput Red "Powershell task '$taskName'"
    $_
}
  
  
  
$dataSourceName = "HID-get-product-owners"
$dataSourceGetProductOwnersGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/datasource/named/$dataSourceName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
  
    if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
        #Create DataSource
        $body = @{
            name = "$dataSourceName";
            type = "3";
            model = @(@{key = "email"; type = 0}, @{key = "firstName"; type = 0}, @{key = "lastname"; type = 0}, @{key = "username"; type = 0});
            automationTaskGUID = "$taskGetProductOwnersGuid";
            input = @(@{description = ""; translateDescription = "False"; inputFieldType = "1"; key = "selectedProduct"; type = "0"; options = "1"})
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/datasource")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
          
        $dataSourceGetProductOwnersGuid = $response.dataSourceGUID
        Write-ColorOutput Green "Task data source '$dataSourceName' created: $dataSourceGetProductOwnersGuid"
    } else {
        #Get DatasourceGUID
        $dataSourceGetProductOwnersGuid = $response.dataSourceGUID
        Write-ColorOutput Yellow "Task data source '$dataSourceName' already exists: $dataSourceGetProductOwnersGuid"
    }
} catch {
    Write-ColorOutput Red "Task data source '$dataSourceName'"
    $_
}




$formName = "HID - Report - Self Service product owners"
$formGuid = ""
  
try
{
    try {
        $uri = ($PortalBaseUrl +"api/v1/forms/$formName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
    } catch {
        $response = $null
    }
  
    if(([string]::IsNullOrEmpty($response.dynamicFormGUID)) -or ($response.isUpdated -eq $true))
    {
        #Create Dynamic form
        $form = @"
        [
            {
              "templateOptions": {},
              "type": "markdown",
              "summaryVisibility": "Hide element",
              "body": "Please select the Self Service product in order to see the configured product owners (users). There are different export options available on the server running the HelloID Agent.",
              "requiresTemplateOptions": false
            },
            {
              "key": "selectedProduct",
              "templateOptions": {
                "label": "Select product",
                "required": true,
                "grid": {
                  "columns": [
                    {
                      "headerName": "Name",
                      "field": "Name"
                    },
                    {
                      "headerName": "Categories",
                      "field": "categories"
                    },
                    {
                      "headerName": "Managed By Group",
                      "field": "ManagedByGroup"
                    }
                  ],
                  "height": 300,
                  "rowSelection": "single"
                },
                "dataSourceConfig": {
                  "dataSourceGuid": "$dataSourceGetAllProductsGuid",
                  "input": {
                    "propertyInputs": []
                  }
                },
                "useFilter": true,
                "useDefault": false
              },
              "type": "grid",
              "summaryVisibility": "Show",
              "requiresTemplateOptions": true
            },
            {
              "key": "grid",
              "templateOptions": {
                "label": "Product oweners",
                "required": false,
                "grid": {
                  "columns": [
                    {
                      "headerName": "Username",
                      "field": "username"
                    },
                    {
                      "headerName": "Email",
                      "field": "email"
                    },
                    {
                      "headerName": "First Name",
                      "field": "firstName"
                    },
                    {
                      "headerName": "Lastname",
                      "field": "lastname"
                    }
                  ],
                  "height": 300,
                  "rowSelection": "single"
                },
                "dataSourceConfig": {
                  "dataSourceGuid": "$dataSourceGetProductOwnersGuid",
                  "input": {
                    "propertyInputs": [
                      {
                        "propertyName": "selectedProduct",
                        "otherFieldValue": {
                          "otherFieldKey": "selectedProduct"
                        }
                      }
                    ]
                  }
                },
                "useFilter": true,
                "useDefault": false
              },
              "type": "grid",
              "summaryVisibility": "Hide element",
              "requiresTemplateOptions": true
            },
            {
              "key": "exportOptions",
              "templateOptions": {
                "label": "Export options (local export on HelloID Agent server)",
                "useObjects": true,
                "options": [
                  {
                    "value": "none",
                    "label": "Export nothing"
                  },
                  {
                    "value": "selected",
                    "label": "Export selected product"
                  },
                  {
                    "value": "all",
                    "label": "Export all products"
                  }
                ],
                "required": true
              },
              "type": "radio",
              "defaultValue": "",
              "summaryVisibility": "Show",
              "textOrLabel": "label",
              "requiresTemplateOptions": true
            }
          ]
"@
  
        $body = @{
            Name = "$formName";
            FormSchema = $form
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/forms")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
  
        $formGuid = $response.dynamicFormGUID
        Write-ColorOutput Green "Dynamic form '$formName' created: $formGuid"
    } else {
        $formGuid = $response.dynamicFormGUID
        Write-ColorOutput Yellow "Dynamic form '$formName' already exists: $formGuid"
    }
} catch {
    Write-ColorOutput Red "Dynamic form '$formName'"
    $_
}
  
  
  
  
$delegatedFormAccessGroupGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/groups/$delegatedFormAccessGroupName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
    $delegatedFormAccessGroupGuid = $response.groupGuid
    
    Write-ColorOutput Green "HelloID (access)group '$delegatedFormAccessGroupName' successfully found: $delegatedFormAccessGroupGuid"
} catch {
    Write-ColorOutput Red "HelloID (access)group '$delegatedFormAccessGroupName'"
    $_
}
  
  
  
$delegatedFormName = "HID - Report - Self Service product owners"
$delegatedFormGuid = ""
$delegatedFormCreated = $false
  
try {
    try {
        $uri = ($PortalBaseUrl +"api/v1/delegatedforms/$delegatedFormName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
    } catch {
        $response = $null
    }
  
    if([string]::IsNullOrEmpty($response.delegatedFormGUID)) {
        #Create DelegatedForm
        $body = @{
            name = "$delegatedFormName";
            dynamicFormGUID = "$formGuid";
            isEnabled = "True";
            accessGroups = @("$delegatedFormAccessGroupGuid");
            useFaIcon = "True";
            faIcon = "fa fa-info-circle";
        }  
  
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/delegatedforms")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
  
        $delegatedFormGuid = $response.delegatedFormGUID
        Write-ColorOutput Green "Delegated form '$delegatedFormName' created: $delegatedFormGuid"
        $delegatedFormCreated = $true
    } else {
        #Get delegatedFormGUID
        $delegatedFormGuid = $response.delegatedFormGUID
        Write-ColorOutput Yellow "Delegated form '$delegatedFormName' already exists: $delegatedFormGuid"
    }
} catch {
    Write-ColorOutput Red "Delegated form '$delegatedFormName'"
    $_
}
  
$taskActionName = "HID-report-export-self-service-product-owners"
$taskActionGuid = ""
  
try {
    if($delegatedFormCreated -eq $true) {    
        $body = @{
            name = "$taskActionName";
            useTemplate = "false";
            powerShellScript = @'
            try {
                $selectedProductJson = $selectedProduct | ConvertFrom-Json
                $selectedGuid = $selectedProductJson.Guid
                
                if($HIDreportFolder.EndsWith("\") -eq $false){
                    $HIDreportFolder = $HIDreportFolder + "\"
                }
                $timeStamp = $(get-date -f yyyyMMddHHmmss)
                $exportFile = $HIDreportFolder + "_SelfServiceProductOwnerReport" + $timeStamp + ".csv"
            
                
                #HelloID variables
                $apiKey = $HIDinternalApiKey
                $apiSecret = $HIDinternalApiSecret
                
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
                
                # Lets get all HelloID Users
                $hidUsers = $null
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
                
                # Create hasTable with all HelloID users
                $hidUserHashtable = @{}
                foreach($hidUser in $hidUsers){
                    $null = $hidUserHashtable.Add($hidUser.userGUID, $hidUser)
                }
                
                # Get all required HelloID products
                $uri = ($PortalBaseUrl +"api/v1/selfservice/products")
                $allProducts = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false 
                $productCount = @($allProducts).Count
                
                switch($exportOptions) {
                    "selected" {
                        $products = $allProducts | Where-object {$_.selfServiceProductGUID -eq $selectedGuid}
                        break;
                    }
                    
                    "all" {
                        $products = $allProducts
                        break;
                    }
                    
                    "none" {
                        $products = $null
                        break;
                    }
                }

                if([string]::IsNullOrEmpty($products))
                {
                    $productCount = $null
                } else {
                    $productCount = @($products).Count
                    HID-Write-Status -Message "product count: $productCount" -Event Information
                }
                
                $exportData = @()
                if ($productCount -gt 0) {
                    foreach($p in $products) {
                        $groupName = $p.managedByGroupName
                
                        if([string]::IsNullOrEmpty($groupName) -eq $false) {
                            $uri = ($PortalBaseUrl +"api/v1/groups/$groupName")
                            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false 
                            $groupMembers = $response.users
                
                            # get user details from hashtable based on userGUID
                            foreach($u in $groupMembers) {
                                $exportData += [pscustomobject]@{
                                    "productName" = $p.name;
                                    "productCategries" = ($p.categories -join ", ");
                                    "groupName" = $groupName;
                                    "userDomain" = $hidUserHashtable.$u.source;
                                    "userName" = $hidUserHashtable.$u.userName;
                                    "firstName" = $hidUserHashtable.$u.firstName;
                                    "lastName" = $hidUserHashtable.$u.lastName;
                                    "email" = $hidUserHashtable.$u.contactEmail;
                                }
                            }
                        }
                    }
                    $exportCount = @($exportData).Count
                    HID-Write-Status -Message "Export row count: $exportCount" -Event Information
                    
                    $exportData = $exportData | Sort-Object -Property productName, userName
                    $exportData | Export-Csv -Path $exportFile -Delimiter ";" -NoTypeInformation
                    
                    HID-Write-Status -Message "Report [$exportFile] containing $exportCount records created successfully" -Event Success
                    HID-Write-Summary -Message "Report [$exportFile] containing $exportCount records created successfully" -Event Success
                
                }
            } catch {
                HID-Write-Status -Message "Could not export Self Service product owner report. Error: $($_.Exception.Message)" -Event Error
                HID-Write-Summary -Message "Failed to export Self Service product owner report" -Event Failed
            }
'@;
            automationContainer = "8";
            objectGuid = "$delegatedFormGuid";
            variables = @(@{name = "exportOptions"; value = "{{form.exportOptions}}"; typeConstraint = "string"; secret = "False"},
                        @{name = "selectedProduct"; value = "{{form.selectedProduct.toJsonString}}"; typeConstraint = "string"; secret = "False"});
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/automationtasks/powershell")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $taskActionGuid = $response.automationTaskGuid

        Write-ColorOutput Green "Delegated form task '$taskActionName' created: $taskActionGuid"
    } else {
        Write-ColorOutput Yellow "Delegated form '$delegatedFormName' already exists. Nothing to do with the Delegated Form task..."
    }
} catch {
    Write-ColorOutput Red "Delegated form task '$taskActionName'"
    $_
}