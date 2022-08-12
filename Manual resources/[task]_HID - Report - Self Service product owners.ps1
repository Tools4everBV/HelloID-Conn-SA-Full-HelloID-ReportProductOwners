$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# variables configured in form
$exportOptions = $form.exportOptions
$selectedProduct = $form.selectedProduct


try {
    #$selectedProductJson = $selectedProduct | ConvertFrom-Json
    $selectedGuid = $selectedProduct.Guid
    
    if($HIDreportFolder.EndsWith("\") -eq $false){
        $HIDreportFolder = $HIDreportFolder + "\"
    }
    $timeStamp = $(get-date -f yyyyMMddHHmmss)
    $exportFile = $HIDreportFolder + "_SelfServiceProductOwnerReport" + $timeStamp + ".csv"

    
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
        Write-Information "Product count: $productCount"
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
        Write-Information "Export row count: $exportCount"
        
        $exportData = $exportData | Sort-Object -Property productName, userName
        $exportData | Export-Csv -Path $exportFile -Delimiter ";" -NoTypeInformation
        
        Write-Information "Report [$exportFile] containing $exportCount records created successfully"
        $Log = @{
            Action            = "Undefined" # optional. ENUM (undefined = default) 
            System            = "ActiveDirectory" # optional (free format text) 
            Message           = "Report [$exportFile] containing $exportCount records created successfully" # required (free format text) 
            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $exportFile # optional (free format text) 
            TargetIdentifier  = "" # optional (free format text) 
        }
        #send result back  
        Write-Information -Tags "Audit" -MessageData $log        
    
    }
} catch {    
    Write-Error "Could not export Self Service product owner report. Error: $($_.Exception.Message)"
    $Log = @{
        Action            = "Undefined" # optional. ENUM (undefined = default) 
        System            = "ActiveDirectory" # optional (free format text) 
        Message           = "Failed to export Self Service product owner report" # required (free format text) 
        IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
        TargetDisplayName = $exportFile # optional (free format text) 
        TargetIdentifier  = "" # optional (free format text) 
    }
    #send result back  
    Write-Information -Tags "Audit" -MessageData $log
}
