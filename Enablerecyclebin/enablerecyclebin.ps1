#Enable Recycle Bin in Active Directory
Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target 'adatum.com' -Confirm: $false


