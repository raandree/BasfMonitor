ipmo .\BasfMonitor\BasfMonitor.psd1 -Force
$config = import-Configuration -Path .\Config -PassThru
$computers = [string[]]$config.Keys

foreach ($computer in $computers)
{
    Copy-Item -Path .\BasfMonitor -Destination "\\$computer\c$\Program Files\WindowsPowerShell\Modules" -Force -Recurse
}

$result = Start-Monitoring -Verbose
$result | Where-Object Status -eq Error

$xml = $result | ConvertTo-Xml
$xml.Save('c:\data.xml')

$result | ft

#to format the XML, see https://www.w3schools.com/xml/xml_xslt.asp

