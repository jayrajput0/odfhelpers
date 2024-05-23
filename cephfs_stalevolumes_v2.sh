#!/bin/bash

#This script calculates the utilization of each CephFS persistentvolume(respective subvolumes) and total USAGE. [option 1]
#It also helps to calculate utilization of ALL subvolumes present at cephFS layer, which helps to figure out the space consumed by stale subvolumes,if any and total USAGE.[option 2]
#This script asummes the the subvolumegroup_name as "csi", which is default subvolumegroup in ODF env.

# Check if jq is installed
if ! command -v jq &>/dev/null; then
  echo "Error: jq command is not installed. Please install jq to proceed."
  exit 1
fi

# Prompt user to choose an option

echo -n "WARNING: This script works well with internal mode ODF deployments. External ceph clusters are usually connected to multiple ODF cluster therefore it may generate inaccurate results."
echo -n "1. Calculate utilization of each CephFS PV"
echo -n "2. Calculate utilization of ALL CephFS subvolumes"
echo -n "3. Generate a list of stale subvolumes"
read -p "Choose an option (1,2 or 3): " option


if [[ $option == 1 ]]; then
  
  # Prompt user to insert cephfsvolume, and storageclassname
  read -p "CephFS StorageClass Name [default: ocs-storagecluster-cephfs]: " storageclass
  storageclass="${storageclass:-ocs-storagecluster-cephfs}"  # Set default value if user input is empty

  read -p "cephFS Volumename [default: ocs-storagecluster-cephfilesystem]: " cephfsvolume
  cephfsvolume="${cephfsvolume:-ocs-storagecluster-cephfilesystem}"  # Set default value if user input is empty

  # Get the rook-ceph-operator pod name
  rook_ceph_op_pod=$(oc get pods -n openshift-storage -o name -l app=rook-ceph-operator)

  # Store the cephFS persistentvolume details in a variable
  persistentvol=$(oc get pv -o custom-columns=PVNAME:metadata.name,STORAGE_Class:spec.storageClassName,SUBVOLUME_NAME:spec.csi.volumeAttributes.subvolumeName | grep "$storageclass")

  # Initialize the total_used_bytes variable
  total_used_bytes=0

  # Iterate over the lines using while loop
  while IFS= read -r line; do
    pvname=$(echo "$line" | awk '{print $1}')  # Extract column one (PVNAME)
    subvolume=$(echo "$line" | awk '{print $3}')  # Extract column three (SUBVOLUME_NAME)
  
    echo -n "PVNAME: $pvname    "  # Print the PVNAME
    echo -n "subvolumeName: $subvolume    "  # Print the input value
  
  # Calculate used_bytes by each sublvolumes having the parent persistentvolume.
    used_bytes=$(oc exec -n openshift-storage "$rook_ceph_op_pod" -- bash -c "export CEPH_ARGS='-c /var/lib/rook/openshift-storage/openshift-storage.config'; ceph fs subvolume info $cephfsvolume $subvolume --group-name csi | jq -r .bytes_used")
    subvolume_type=$(oc exec -n openshift-storage "$rook_ceph_op_pod" -- bash -c "export CEPH_ARGS='-c /var/lib/rook/openshift-storage/openshift-storage.config'; ceph fs subvolume info $cephfsvolume $subvolume --group-name csi | jq -r .type")
    echo -n "Used bytes: $used_bytes bytes    "
    usage=$(bc <<< "scale=2; $used_bytes / (1024^3)")  # Perform floating-point division
    echo -n "(${usage}GiB)"
    echo "   subvolume type: $subvolume_type" 
    # Accumulate the used_bytes to total_used_bytes
    total_used_bytes=$((total_used_bytes + used_bytes))
  done <<< "$persistentvol"

  # Convert total_used_bytes to GiB
  total_usage=$(bc <<< "scale=2; $total_used_bytes / (1024^3)")

  echo "Total used bytes: $total_used_bytes bytes (${total_usage}GiB)"
  echo
  
  # To calculate each subvolumes utilization at ceph cluster, irrespective of ht efact if it has any parent persistentvolume or not. 
elif [[ $option == 2 ]]; then

  # Prompt user to insert cephfsvolume
  read -p "cephFS Volumename [default: ocs-storagecluster-cephfilesystem]: " cephfsvolume
  cephfsvolume="${cephfsvolume:-ocs-storagecluster-cephfilesystem}"  # Set default value if user input is empty

  # Get the rook-ceph-operator pod name
  rook_ceph_op_pod=$(oc get pods -n openshift-storage -o name -l app=rook-ceph-operator)

  # Store the subvolume name in a variable
  cephfssubvollist=$(oc exec -n openshift-storage "$rook_ceph_op_pod" -- bash -c "export CEPH_ARGS='-c /var/lib/rook/openshift-storage/openshift-storage.config';ceph fs subvolume ls "$cephfsvolume" csi | jq -r '.[] |.name'")
  
  # Initialize a variable total_subvolume_usage.  
  total_subvolume_usage=0
  while IFS= read -r subvolumename; do
    echo -n "subvolumeName: $subvolumename    "
  
  # Capture utilization for each subvolumes.  
    subvolume_usage=$(oc exec -n openshift-storage "$rook_ceph_op_pod" -- bash -c "export CEPH_ARGS='-c /var/lib/rook/openshift-storage/openshift-storage.config';ceph fs subvolume info "$cephfsvolume" "$subvolumename" csi | jq -r .bytes_used")
    subvolume_type=$(oc exec -n openshift-storage "$rook_ceph_op_pod" -- bash -c "export CEPH_ARGS='-c /var/lib/rook/openshift-storage/openshift-storage.config';ceph fs subvolume info "$cephfsvolume" "$subvolumename" csi | jq -r .type")
    echo -n "Used bytes: $subvolume_usage bytes    "
    
  # Calculate the utilization Gib.  
    subvolume_usage_gib=$(bc <<< "scale=2; $subvolume_usage / (1024^3)")
    echo -n "(${subvolume_usage_gib}GiB)"
    echo "   subvolume_type: $subvolume_type"
  # Accumulate the subvolume_usage to total_subvolume_usage
    total_subvolume_usage=$((total_subvolume_usage + subvolume_usage))
  done <<< "$cephfssubvollist"

  # Convert total_subvolume_usage to GiB
  total_subvolume_usage_gib=$(bc <<< "scale=2; $total_subvolume_usage / (1024^3)")

  echo "Total subvolumes usage: $total_subvolume_usage bytes (${total_subvolume_usage_gib}GiB)"

elif [[ $option == 3 ]]; then

 # Prompt user to insert cephfsvolume, and storageclassname
  read -p "CephFS StorageClass Name [default: ocs-storagecluster-cephfs]: " storageclass
  storageclass="${storageclass:-ocs-storagecluster-cephfs}"  # Set default value if user input is empty

  read -p "cephFS Volumename [default: ocs-storagecluster-cephfilesystem]: " cephfsvolume
  cephfsvolume="${cephfsvolume:-ocs-storagecluster-cephfilesystem}"  # Set default value if user input is empty

  # Get the rook-ceph-operator pod name
  rook_ceph_op_pod=$(oc get pods -n openshift-storage -o name -l app=rook-ceph-operator)

  # Store the cephFS persistentvolume details in a variable
  oc get pv -o custom-columns=PVNAME:metadata.name,STORAGE_Class:spec.storageClassName,SUBVOLUME_NAME:spec.csi.volumeAttributes.subvolumeName | grep "$storageclass"| awk '{print $3}' >| pv_subvol_list
  


  # Store the subvolume name in a variable
  oc exec -n openshift-storage "$rook_ceph_op_pod" -- bash -c "export CEPH_ARGS='-c /var/lib/rook/openshift-storage/openshift-storage.config';ceph fs subvolume ls "$cephfsvolume" csi | jq -r '.[] |.name'" >| all_sublvol_list

  # compare the pvlist and all_sublvol_list to find out stale volumes
  grep -F -x -v -f pv_subvol_list all_sublvol_list >| stale_subvol_list 
  echo  "BELOW FILES WERE CREATED:"
  echo  "pv_subvol_list:    List of respective subvolumes name for each cephFS persistent volume."
  echo  "all_sublvol_list:  List of all subvolumes present at ceph cluster"
  echo  "stale_subvol_list: List of stale subvolumes(the subvolumes which are not present in pv_subvol_list but present in all_sublvol_list.)"
else
  echo "Invalid option. Please choose either 1,2 or 3."
fi
