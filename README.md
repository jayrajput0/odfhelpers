This Project is created to have ODF helper scripts to handle ODF tasks.

cephfs_stalevolumes script:
 - 
 This script helps to calculate utilization of each subvolumes being used as persistent volume in ODF environment.
 It also helps to generate a list of stale subvolumes. It creates a list of all subvolumes being consumed in persistent volumes and compare it with all available subvolumes from ceph layer. The subvolumes which are not being consumed in any persistent volume are considered to be stale.
 This script works well with ODF internal deployment but not with external deployment, specially for generating stale subvolume lists.

