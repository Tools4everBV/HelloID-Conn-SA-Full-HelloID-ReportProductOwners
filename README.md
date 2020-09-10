<!-- Description -->
## Description
This HelloID Service Automation Delegated Form provides a report containing the members of HelloID Self Service product owner group. The following options are available:
 1. Select one of the HelloID Self Service Products
 2. The members of the Resource Owner group are shown
 3. Export to a local CSV file is possible for the selected product or all of the available products
 
<!-- TABLE OF CONTENTS -->
## Table of Contents
* [Description](#description)
* [All-in-one PowerShell setup script](#all-in-one-powershell-setup-script)
  * [Getting started](#getting-started)
* [Post-setup configuration](#post-setup-configuration)


## All-in-one PowerShell setup script
The PowerShell script "createform.ps1" contains a complete PowerShell script using the HelloID API to create the complete Form including user defined variables, tasks and data sources.

### Getting started
 1. Download the script "createform.ps1"
 2. Open the script in your favorite PowerShell console / edditor
 3. Open your HelloID portal
 4. Get or create your own [API Key and Secret](https://docs.helloid.com/hc/en-us/articles/360002008873-API-Keys-Overview)
 5. Update the following connection details in the all-in-one PowerShell script
 <table>
  <tr><td><strong>Line</strong></td><td><strong>Variable</strong></td><td><strong>Example</strong></td><td><strong>Description</strong></td></tr>
  <tr><td>2</td><td>$PortalBaseUrl</td><td>https://customer01.helloid.com</td><td>Your own HelloID portal URL</td></tr>
  <tr><td>3</td><td>$apiKey</td><td></td><td>Your own HelloID API Key</td></tr>
  <tr><td>4</td><td>$apiSecret</td><td></td><td>Your own HelloID API Secret</td></tr>
  <tr><td>5</td><td>$delegatedFormAccessGroupName</td><td>Users</td><td>Local HelloID group name giving access to this new Delegated Form</td></tr>
</table>
 6. Run the all-in-one PowerShell script
 
 _Please note that this script asumes none of the required resources do exists within HelloID. The script does not contain versioning or source control_

## Post-setup configuration
After the all-in-one PowerShell script has run and created all the required resources. The following items need to be configured according to your own environment
 1. Update the following [user defined variables](https://docs.helloid.com/hc/en-us/articles/360014169933-How-to-Create-and-Manage-User-Defined-Variables)
<table>
  <tr><td><strong>Variable name</strong></td><td><strong>Example value</strong></td><td><strong>Description</strong></td></tr>
  <tr><td>HIDinternalApiKey</td><td>Welkom01!</td><td>API Key of the HelloID portal used to read HelloID Self Service products and users</td></tr>
  <tr><td>HIDinternalApiSecret</td><td>Welkom01!</td><td>API Secret of the HelloID portal used to read HelloID Self Service products and users</td></tr>
  <tr><td>HIDreportFolder</td><td>C:\HIDreports\</td><td>Local folder on HelloID Agent server for exporting CSV reports</td></tr>
</table>
