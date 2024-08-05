Get-ComputerInfo | select CsDNSHostName, CsNumberOfLogicalProcessors, @{n="OsTotalVisibleMemorySize" ; \
e={[math]::Round($_.OsTotalVisibleMemorySize/1024KB)}} | Format-List ; \
echo 'list volume' | diskpart | Select-String Volume,"--" ; \
Get-WmiObject Win32_PnPSignedDriver | where {$_.devicename -like "*nvidia*"} | Select DeviceClass,DeviceName,DriverVersion