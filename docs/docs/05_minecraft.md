# Minecraft

With the persistence layer in place, I have all the pieces to set up an application that uses persistent volume claims. I chose a Minecraft Bedrock server for this project. The initial setup was quite simple—all I had to do was prepare a PVC and use the [Minecraft Bedrock server](https://hub.docker.com/r/itzg/minecraft-bedrock-server) Docker image with the proper configuration.

## PVC
Here’s the YAML file for the Persistent Volume Claim configuration:
```yaml
# minecraft-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: bds
  annotations:
    volumeType: local
    volume.kubernetes.io/selected-node: worker0
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 10Gi
```

This configuration is stored in a separate file and is created once. One important thing to note is that the PVC is assigned to a specific cluster node. The StatefulSet that uses this PVC will follow that assignment, ensuring the application is deployed on the same node.

## Secrets 
There are two environment variables that I want to keep out of the Git repository:

1. A players whitelist containing usernames and identifiers of players allowed on the server.
2. Identifiers of players with admin privileges (operators).

I decided to store these values in a YAML **Secret**:
```yaml
# minecraft-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: minecraft-secrets
  labels:
    role: service-secrets
    app: bds
type: Opaque
stringData:
  # https://www.cxkes.me/xbox/xuid -> copy XUID (DEC)
  ALLOW_LIST_USERS: <secret>
  OPS: <secret>
```

This file is encrypted using GPG and kept in the repository with the proper values.

## Application YAML
The main YAML file, which contains the **ConfigMap**, **StatefulSet**, and **Service**, looks like this:
```yaml
# minecraft.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: minecraft
  labels:
    role: service-config
    app: bds
data:
  # Find more options at https://github.com/itzg/docker-minecraft-bedrock-server#server-properties
  # Remove # from in front of line if changing from default values.
  EULA: "TRUE" # Must accept EULA to use this minecraft server
  TZ: "Europe/Warsaw"
  GAMEMODE: "survival" # Options: survival, creative, adventure
  DIFFICULTY: "normal" # Options: peaceful, easy, normal, hard
  DEFAULT_PLAYER_PERMISSION_LEVEL: "member" # Options: visitor, member, operator
  LEVEL_NAME: "MC Anton"
  LEVEL_SEED: "1429753401291899097"
  SERVER_NAME: "MC Anton"
  #SERVER_PORT: "19132"
  #LEVEL_TYPE: "DEFAULT" # Options: FLAT, LEGACY, DEFAULT
  #ALLOW_CHEATS: "false" # Options: true, false
  MAX_PLAYERS: "10"
  #PLAYER_IDLE_TIMEOUT: "30"
  #TEXTUREPACK_REQUIRED: "false" # Options: true, false
  #
  ## Changing these will have a security impact
  ONLINE_MODE: "true" # Options: true, false (removes Xbox Live account requirements)
  #WHITE_LIST: "true" # If enabled, need to provide a whitelist.json by your own means.
  # 
  # allowed users are taken from secrets
  # ALLOW_LIST_USERS: todo:todo
  ## Changing these will have a performance impact
  #VIEW_DISTANCE: "10"
  #TICK_DISTANCE: "4"
  #MAX_THREADS: "8"
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  labels:
    app: bds
  name: bds
spec:
  # never more than 1 since BDS is not horizontally scalable
  replicas: 1
  serviceName: bds
  selector:
    matchLabels:
      app: bds
  template:
    metadata:
      labels:
        app: bds
    spec:
      containers:
        - name: main
          image: itzg/minecraft-bedrock-server:latest
          imagePullPolicy: IfNotPresent
          envFrom:
            - configMapRef:
                name: minecraft
          env:
            - name: ALLOW_LIST_USERS
              valueFrom:
                secretKeyRef:
                  name: minecraft-secrets
                  key: ALLOW_LIST_USERS
            - name: OPS
              valueFrom:
                secretKeyRef:
                  name: minecraft-secrets
                  key: OPS
          volumeMounts:
            - name: bds-volume
              mountPath: /data
          ports:
            - containerPort: 19132
              protocol: UDP
          readinessProbe: &probe
            exec:
              command:
                - mc-monitor
                - status-bedrock
                - --host
                # force health check against IPv4 port
                - 127.0.0.1
            initialDelaySeconds: 30
          livenessProbe: *probe
          tty: true
          stdin: true
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            seccompProfile:
              type: RuntimeDefault
              # runAsNonRoot: true
      volumes:
        - name: bds-volume
          persistentVolumeClaim:
            claimName: bds
---
apiVersion: v1
kind: Service
metadata:
  name: bds
spec:
  selector:
    app: bds
  ports:
    - protocol: UDP
      port: 19132
      nodePort: 30000
  type: NodePort
```

## Backup

Minecraft worlds should be backed up and stored separately in case of world corruption, PVC errors, or accidental deletion. For now, I’m using a simple script (created with ChatGPT) that creates a zip file of the PVC content and copies it to my computer. I’ll improve this process in the future. Here’s the script:
```sh
#!/bin/bash

set -e

STATEFULSET="bds"
PVC_NAME="bds"
NAMESPACE="default"
TMP_POD_NAME="pvc-backup-temp"
LOCAL_BACKUP_FILE="bds-backup-$(date +%Y%m%d%H%M%S).zip"

echo "🔽 Scaling down StatefulSet $STATEFULSET..."
kubectl scale statefulset $STATEFULSET --replicas=0 --namespace $NAMESPACE

echo "⏱ Waiting for pods to terminate..."
sleep 30

echo "📦 Creating temporary pod to mount PVC..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $TMP_POD_NAME
  namespace: $NAMESPACE
spec:
  nodeName: worker0
  containers:
  - name: backup
    image: joshkeegan/zip:3.21.3
    command: [ "sh", "-c", "cd /data && zip -r /tmp/bds.zip . && sleep 3600" ]
    volumeMounts:
    - name: bds-vol
      mountPath: /data
  volumes:
  - name: bds-vol
    persistentVolumeClaim:
      claimName: $PVC_NAME
  restartPolicy: Never
EOF

echo "🕐 Waiting for pod to be Ready..."
kubectl wait --for=condition=Ready pod/$TMP_POD_NAME --timeout=60s --namespace $NAMESPACE

echo "📁 Copying data from PVC to local zip file..."
kubectl exec -n $NAMESPACE $TMP_POD_NAME -- sh -c "cd /data && zip -r /tmp/bds.zip ."
kubectl cp $NAMESPACE/$TMP_POD_NAME:/tmp/bds.zip $LOCAL_BACKUP_FILE

echo "🧹 Cleaning up temporary pod..."
kubectl delete pod $TMP_POD_NAME --namespace $NAMESPACE

echo "⬆️ Scaling StatefulSet $STATEFULSET back to 1..."
kubectl scale statefulset $STATEFULSET --replicas=1 --namespace $NAMESPACE

echo "✅ Backup complete: $LOCAL_BACKUP_FILE"
```

## Setup

To sum up, here’s how to set up the Minecraft server using the above configuration:

1. Apply the YAML PVC configuration—this will create storage for server data.
2. Apply the YAML secrets—this will create secrets containing the *ALLOW_LIST_USERS* and *OPS* variables.
3. Apply the remaining YAML—this will create the ConfigMap, StatefulSet (to manage the Minecraft server pod), and Service (to allow connections to the server).

If you need to make changes, you can delete and reapply the YAML configurations for secrets and the application as often as needed. However, the PVC is created once and cannot be deleted without losing data.

---

Sources:

* [https://hub.docker.com/r/itzg/minecraft-bedrock-server](https://hub.docker.com/r/itzg/minecraft-bedrock-server)
* [https://github.com/itzg/docker-minecraft-bedrock-server/](https://github.com/itzg/docker-minecraft-bedrock-server)
