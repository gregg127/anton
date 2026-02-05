### Geyser and Floodgate setup 
```
sed -i 's/auth-type: online/auth-type: floodgate/' /data/plugins/Geyser-Spigot/config.yml && \
sed -i 's/command-suggestions: true/command-suggestions: false/' /data/plugins/Geyser-Spigot/config.yml && \
sed -i 's/show-cooldown: title/show-cooldown: actionbar/' /data/plugins/Geyser-Spigot/config.yml && \
sed -i 's/enforce-secure-profile=true/enforce-secure-profile=false/' /data/server.properties && \
sed -i 's/primary-motd: Geyser/primary-motd: Anton MC Geyser/' /data/plugins/Geyser-Spigot/config.yml && \
sed -i 's/secondary-motd: Another Geyser server\./secondary-motd: Welcome to the jungle.../' /data/plugins/Geyser-Spigot/config.yml && \
sed -i 's/server-name: Geyser/server-name: Anton Geyser/' /data/plugins/Geyser-Spigot/config.yml && \
sed -i 's/log-player-ip-addresses: true/log-player-ip-addresses: false/' /data/plugins/Geyser-Spigot/config.yml && \
cp /data/plugins/floodgate/key.pem /data/plugins/Geyser-Spigot/key.pem 
```
### Bluemap setup
```
sed -i 's/accept-download: false/accept-download: true/' /data/plugins/BlueMap/core.conf && \
sed -i 's/port:.*/port:8080/' /data/plugins/BlueMap/webserver.conf && \
sed -i 's/metrics: true/metrics: false/' /data/plugins/BlueMap/core.conf && \
sed -i 's/render-thread-count: 1/render-thread-count: 2/' /data/plugins/BlueMap/core.conf
```