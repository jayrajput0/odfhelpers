#!/bin/bash

# Check if a ConfigMap with the same name already exists
if oc get configmap aws-credentials -n openshift-storage &> /dev/null; then
  read -p "ConfigMap 'aws-credentials' already exists. Do you want to override it? (y/n): " OVERRIDE_CONFIGMAP
  if [ "$OVERRIDE_CONFIGMAP" != "y" ]; then
    echo "Aborting."
    exit 1
  else
    # Backup the existing ConfigMap
    TIMESTAMP=$(date '+%Y%m%d%H%M%S')
    oc get configmap aws-credentials -n openshift-storage -o yaml > "aws-credentials-$TIMESTAMP.yaml"
    echo "Existing ConfigMap backed up as aws-credentials-$TIMESTAMP.yaml"
    oc delete configmap aws-credentials -n openshift-storage
  fi
fi

# Prompt the user to insert the AWS access key ID
read -p "Enter AWS Access Key ID: " AWS_ACCESS_KEY_ID

# Prompt the user to insert the AWS secret access key
read -p "Enter AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY

# Create a ConfigMap YAML file
cat <<EOF > aws-credentials.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-credentials
data:
  AWS_ACCESS_KEY_ID: "$AWS_ACCESS_KEY_ID"
  AWS_SECRET_ACCESS_KEY: "$AWS_SECRET_ACCESS_KEY"
EOF

# Apply the ConfigMap to the OpenShift cluster
echo "Creating ConfigMap..."
oc apply -f aws-credentials.yaml

# Create a Pod YAML file with awscli image.
# There are three possible locations:
# registry.access.redhat.com/amazon/aws-cli:latest
# registry.redhat.io/amazon/aws-cli:latest
# docker.io/amazon/aws-cli:latest
# Modify the yaml as per requirement.

cat <<EOF > awscli-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: awscli
  labels:
    app: awscli
  namespace: openshift-storage
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: awscli
      image: 'docker.io/amazon/aws-cli:latest'
      command: ["sleep", "infinity"]
      envFrom:
        - configMapRef:
            name: aws-credentials
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
EOF

# Apply the Pod to the OpenShift cluster
echo "Creating Pod..."
oc apply -f awscli-pod.yaml

echo "Deployment completed."
