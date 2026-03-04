<#
MSSA Advanced PowerShell Challenge (Clean Version)

#green GOAL: Make the script readable + repeatable (idempotent).
#green If you run it twice, it should NOT break or create duplicates.
#>

[CmdletBinding()]
param()

#------------------------------------------------------------
# 1) Prerequisites
#------------------------------------------------------------
#green KSI: Validate prerequisites before running AD commands.
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    throw "ActiveDirectory module is not available. Install RSAT / AD tools first."
}
Import-Module ActiveDirectory -ErrorAction Stop

#------------------------------------------------------------
# 2) Variables (inputs) - define ONCE
#------------------------------------------------------------
#green KSI: Build distinguished names (DNs) consistently.
$OUName      = "London"
$DomainDN    = "DC=Adatum,DC=com"
$LondonOUdn  = "OU=$OUName,$DomainDN"

$SalesOUdn   = "OU=Sales,$DomainDN"
$GroupName   = "London Users"

#------------------------------------------------------------
# 3) Ensure London OU exists (Idempotent create)
#------------------------------------------------------------
#green KSI: IF/ELSE logic for idempotency.
#green Use -ErrorAction Stop inside TRY/CATCH when you want reliable error handling.

try {
    $existingOU = Get-ADOrganizationalUnit -Identity $LondonOUdn -ErrorAction Stop
    Write-Verbose "OU already exists: $LondonOUdn"
}
catch {
    Write-Verbose "OU not found. Creating OU: $OUName in $DomainDN"
    New-ADOrganizationalUnit -Name $OUName -Path $DomainDN -ErrorAction Stop
    Write-Verbose "Created OU: $LondonOUdn"
}

#------------------------------------------------------------
# 4) Ensure London Users group exists inside London OU
#------------------------------------------------------------
#green KSI: Create resources in the correct container (OU path).
$group = Get-ADGroup -Filter "Name -eq '$GroupName'" -SearchBase $LondonOUdn -ErrorAction SilentlyContinue

if (-not $group) {
    Write-Verbose "Group not found. Creating group '$GroupName' in $LondonOUdn"
    New-ADGroup -Name $GroupName `
        -GroupScope Global `
        -GroupCategory Security `
        -Path $LondonOUdn `
        -ErrorAction Stop

    #green Always re-query after create so you have the object.
    $group = Get-ADGroup -Filter "Name -eq '$GroupName'" -SearchBase $LondonOUdn -ErrorAction Stop
}
else {
    Write-Verbose "Group already exists: $($group.DistinguishedName)"
}

#------------------------------------------------------------
# 5) Find Sales users with City = London
#------------------------------------------------------------
#green KSI: Use -SearchBase to limit scope + -Filter for server-side filtering.
#green Only request properties you need.
$londonSalesUsers = Get-ADUser `
    -SearchBase $SalesOUdn `
    -Filter "City -eq 'London'" `
    -Properties City

Write-Verbose "Found $($londonSalesUsers.Count) Sales users with City = London."

#------------------------------------------------------------
# 6) Move those users into the London OU
#------------------------------------------------------------
#green KSI: foreach loop over AD objects + use DN for Move-ADObject.
foreach ($user in $londonSalesUsers) {
    try {
        Move-ADObject -Identity $user.DistinguishedName -TargetPath $LondonOUdn -ErrorAction Stop
        Write-Verbose "Moved: $($user.SamAccountName) to $LondonOUdn"
    }
    catch {
        Write-Warning "Failed to move $($user.SamAccountName): $($_.Exception.Message)"
    }
}

#------------------------------------------------------------
# 7) Add ALL users in London OU to London Users group
#------------------------------------------------------------
#green KSI: Get the final set of users from the target OU (source of truth).
#green Avoid adding users twice. Add based on who is *currently* in London OU.
$londonOUusers = Get-ADUser -SearchBase $LondonOUdn -SearchScope OneLevel -Filter * -Properties SamAccountName

Write-Verbose "Found $($londonOUusers.Count) users in London OU."

if ($londonOUusers.Count -gt 0) {
    try {
        #green Add-ADGroupMember accepts an array. No need for a foreach.
        Add-ADGroupMember -Identity $group.DistinguishedName -Members $londonOUusers -ErrorAction Stop
        Write-Verbose "Added $($londonOUusers.Count) users to group: $GroupName"
    }
    catch {
        Write-Warning "Group membership update had issues: $($_.Exception.Message)"
        #green NOTE: AD may warn if some users are already members; that’s not fatal.
    }
}
else {
    Write-Verbose "No users found in London OU to add to group."
}

#------------------------------------------------------------
# 8) Validation outputs (quick checks)
#------------------------------------------------------------
#green KSI: Validate each deliverable: OU exists, group exists, correct users moved, membership correct.

Get-ADOrganizationalUnit -Identity $LondonOUdn
Get-ADGroup -Identity $group.DistinguishedName

Get-ADUser -SearchBase $LondonOUdn -SearchScope OneLevel -Filter * -Properties City |
    Select-Object Name, SamAccountName, City

Get-ADGroupMember -Identity $group.DistinguishedName |
    Get-ADUser -Properties City, Department |
    Select-Object Name, SamAccountName, City, Department