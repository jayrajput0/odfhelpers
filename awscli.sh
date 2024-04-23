#!/bin/bash

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
