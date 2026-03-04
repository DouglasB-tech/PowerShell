# Part 1 of MSSA Advanced PS Challenge
# Create an OU named London OU; Londan // Domain DC=Adatum,DC=com // Pat: OU=OUName,DomainDN
$OUName = "London"
$DomainDN = "DC=Adatum,DC=Com"
$OUPath = "OU=$OUName,$DomainDN"
$ExistingOU = Get-ADOrganizationalUnit -Filter "Name -eq '$OUName'" -SearchBase $DomainDN -ErrorAction SilentlyContinue
if ($ExistingOU) {
    Write-Host "The OU '$OUName' already exists"
} else {
    Write-Host "The OU '$OUName' does not exist. Creating it now..."
    New-ADOrganizationalUnit -Name $OUName -Path $DomainDN
    Write-Host "The OU '$OUName' has been created successfully."
}