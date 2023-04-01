#The Rest method call to get the metadata instance the query has been enabled via IMDS , So it can access within the VM to retreive data

$metadata = Invoke-RestMethod -Method GET -Headers @{"Metadata"="true"} -Uri "http://169.254.169.254/metadata/instance?api-version=2022-02-01"
$metadata | ConvertTo-Json