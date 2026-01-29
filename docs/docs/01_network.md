# Network Setup

## Overview

This documentation outlines the network configuration for a cluster setup using a dual-router architecture. The network topology consists of:

- Main router connected to WAN via fiber optic connection
- Dedicated cluster router connected to the main router
- Network switch connected to the cluster router
- All cluster machines connected to the network switch

## Initial WAN Configuration

Configure the connection between the main router and the cluster router:

1. **Configure cluster router WAN**: Set up the WAN interface on the cluster router to connect to the main router
2. **Assign static IP**: On the main router, assign a static IP address to the cluster router
3. **Create NAT rule**: On the main router, add a NAT rule to forward incoming traffic on port 80 to the cluster router

!!!note 
    Additional NAT rules will be configured later as needed. I started with HTTP (port 80) for initial setup.

## Cluster Router Configuration

### Management Port Configuration

**Critical First Step**: Change the router management ports to non-standard ports (e.g., 10000, 10001).

!!!warning
    This step must be completed before configuring port forwarding rules (NAT configuration). Failure to do so will block access to the router configuration interface once port 80 forwarding is enabled.

### Network Segmentation

1. **Create cluster subnet**: In the LAN configuration, create a dedicated subnet for cluster machines
2. **Configure VLAN**: Create a new VLAN and set the router port to match the port where the cluster switch is connected
3. **Link subnet to VLAN**: Edit the cluster subnet settings and assign the VLAN ID from the newly created VLAN
4. **Set up cluster machines**: Proceed to cluster machine configuration (covered in the next chapter)

## Static IP Address Configuration

Once the basic router configuration and cluster machines are operational:

1. **Assign static IPs**: Add static IP addresses for all cluster machines (you may need to clear existing entries from the ARP table configuration)
2. **Verify assignment**: Restart all cluster machines and confirm that the correct IP addresses were assigned

## Firewall Rules (Access Control List)

Configure the following firewall rules in order:

1. **Block cluster LAN access**: Prevent cluster subnet from accessing devices directly connected to the cluster router (not through the switch)*
2. **Block main router access**: Prevent all cluster machines from accessing the **main** router's gateway and configuration interface
3. **Block cluster router management**: Prevent cluster machines from accessing the cluster router's configuration interface on the custom management ports
4. **Allow HTTP traffic**: Enable HTTP communication for web scraping applications and general internet access
5. **Allow HTTPS traffic**: Enable SSL/TLS communication for secure web scraping and general internet access
6. **Allow DNS queries**: Enable DNS resolution for internet connectivity
7. **Allow SNTP access**: Enable access to Cloudflare NTP servers (required for Talos OS)
8. **Allow SSH access**: Enable SSH for Flux GitHub integration (**Security Warning**: SSH access poses security risks and may be subject to reverse shell attacks. Consider implementing additional security measures)
9. **Block remaining WAN traffic**: Block all other outgoing internet traffic to minimize security exposure

## Network Testing

Test the configuration by connecting a computer to the cluster switch and performing the following checks:

### Basic Access Control Verification
1. **Router management access**: Attempt to access the cluster router management interface via HTTP/HTTPS on custom ports. **Expected result**: Connection timeout
2. **Main router access**: Attempt to access the main router management interface. **Expected result**: Connection timeout
3. **Router-connected device access**: Attempt to ping devices connected directly to the cluster router. **Expected result**: Connection timeout
4. **Cluster device access**: Attempt to ping other devices connected to the cluster switch. **Expected result**: Successful ping response
5. **Web browsing**: Test HTTP and HTTPS website access. **Expected result**: Successful connection
6. **Blocked services**: Test access to blocked services (e.g., FTP). **Expected result**: Connection failure

!!!note
    **Testing Tip**: Use `nmap` for comprehensive port scanning and traffic filtering verification.

## Final Configuration Steps

### Port Forwarding Setup

Add a NAT rule on the cluster router to forward port 80 traffic to port 80 of the cluster control plane machine.

Once configured, port 80 will be opened and your cluster will be accessible from the internet.

### Additional Public Port Access

To expose additional ports to the public internet:

1. **Main router**: Add NAT rule forwarding traffic from the internet to the cluster router
2. **Cluster router**: Add NAT rule forwarding traffic from the main router to the cluster control plane machine

!!!note
    **Scalability Note**: This approach is suitable for homelab environments but lacks scalability due to the absence of load balancing. If the cluster control plane fails, services will become unavailable.
