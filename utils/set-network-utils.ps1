# Set IP and Gateway
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses "10.244.0.10"
New-NetIPAddress -IPAddress "10.244.0.11" -PrefixLength 32 -DefaultGateway "10.244.1.2" -InterfaceAlias "Ethernet"