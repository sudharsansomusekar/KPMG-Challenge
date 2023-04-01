<#
.Requirments : We have a nested object. We would like a function where you pass in the object and a key and
get back the value.

#>
function GetNestedValueByKey {
    param (
        [Parameter(Mandatory=$true)]
        $Object,
        
        [Parameter(Mandatory=$true)]
        $Key
    )
    
    $keys = $Key -split '\.'
    $currentObject = $Object
    
    foreach ($keyData in $keys) {
        if ($currentObject.ContainsKey($keyData)) {
            $currentObject = $currentObject[$keyData]
        } else {
            return $null
        }
    }
    
    return $currentObject
}
# Create a sample nested object
$myObject = @{
    "Name" = "Sudhas"
    "Age" = 30
    "Address" = @{
        "Street" = "1St Main"
        "City" = "Ecity"
        "State" = "KA"
    }
}

# Call the function to get the value of a nested key
$value = GetNestedValueByKey -Object $myObject -Key "Address.State"
Write-Output "The value is $value"

