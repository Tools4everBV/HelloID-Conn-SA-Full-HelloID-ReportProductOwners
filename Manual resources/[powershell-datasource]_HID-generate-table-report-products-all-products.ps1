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
