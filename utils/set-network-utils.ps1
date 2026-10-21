# Set IP and Gateway
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses "10.244.0.10"
New-NetIPAddress -IPAddress "10.244.0.20" -PrefixLength 32 -InterfaceAlias "Ethernet"
New-NetRoute -NextHop "10.244.1.2" -DestinationPrefix "0.0.0.0/0" -InterfaceAlias "Ethernet"