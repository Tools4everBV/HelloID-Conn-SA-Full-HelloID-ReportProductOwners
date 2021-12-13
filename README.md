<!-- Description -->
## Description
This HelloID Service Automation Delegated Form provides a report containing the members of a HelloID Self Service product owner group. The following options are available:
 1. Select one of the available HelloID Self Service Products
 2. The members of the Resource Owner group are shown
 3. Export to a local CSV file on the HelloID Agent server is possible for the selected product or all of the available products

## Versioning
| Version | Description | Date |
| - | - | - |
| 1.0.1   | Added version number and updated all-in-one script | 2021/12/13  |
| 1.0.0   | Initial release | 2020/09/08  |

<!-- TABLE OF CONTENTS -->
## Table of Contents
* [Description](#description)
* [All-in-one PowerShell setup script](#all-in-one-powershell-setup-script)
  * [Getting started](#getting-started)
* [Post-setup configuration](#post-setup-configuration)

## All-in-one PowerShell setup script
The PowerShell script "createform.ps1" contains a complete PowerShell script using the HelloID API to create the complete Form including user defined variables, tasks and data sources.

_Please note that this script asumes none of the required resources do exists within HelloID. The script does not contain versioning or source control_

### Getting started
Please follow the documentation steps on [HelloID Docs](https://docs.helloid.com/hc/en-us/articles/360017556559-Service-automation-GitHub-resources) in order to setup and run the All-in one Powershell Script in your own environment.

## Post-setup configuration
After the all-in-one PowerShell script has run and created all the required resources. The following items need to be configured according to your own environment
 1. Update the following [user defined variables](https://docs.helloid.com/hc/en-us/articles/360014169933-How-to-Create-and-Manage-User-Defined-Variables)
<table>
  <tr><td><strong>Variable name</strong></td><td><strong>Example value</strong></td><td><strong>Description</strong></td></tr>
  <tr><td>HIDinternalApiKey</td><td>Welkom01!</td><td>API Key of the HelloID portal used to read HelloID Self Service products and users</td></tr>
  <tr><td>HIDinternalApiSecret</td><td>Welkom01!</td><td>API Secret of the HelloID portal used to read HelloID Self Service products and users</td></tr>
  <tr><td>HIDreportFolder</td><td>C:\HIDreports\</td><td>Local folder on HelloID Agent server for exporting CSV reports</td></tr>
</table>

## Manual resources
This Delegated Form uses the following resources in order to run

### Powershell data source 'HID-generate-table-report-products-all-products'
This Powershell data source uses the HelloID API the receive all configured HelloID Products. It uses an API key and API secret specified as HelloID user defined variable named _"HIDinternalApiKey"_ and _"HIDinternalApiSecret"_.

### Powershell data source 'HID-generate-table-report-products-get-product-owners'
This Powershell data source uses the HelloID API the receive all HelloID users configured as resource owner of the selected HelloID product.

### Delegated form task 'HID-report-export-self-service-product-owners'
This delegated form task runs the same HelloID API calls as the PowerShell data source and export the data to a local CSV file if selected in the form.

## Getting help
_If you need help, feel free to ask questions on our [forum](https://forum.helloid.com/forum/helloid-connectors/service-automation/644-helloid-sa-helloid-report-product-owners)_

## HelloID Docs
The official HelloID documentation can be found at: https://docs.helloid.com/
