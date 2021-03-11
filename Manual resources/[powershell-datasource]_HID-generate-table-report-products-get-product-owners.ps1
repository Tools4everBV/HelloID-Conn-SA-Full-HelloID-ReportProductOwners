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
