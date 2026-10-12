# Day 13 - Interview Questions

[← Back to Day 13 notes](../README.md)

**1. What is an inode?**

The metadata record of a file - owner, group, permissions, timestamps, size. It does not hold the file's content. See it with `ls -li` or `stat <file>`.

**2. Symlink vs hard link?**

Symlink: a shortcut with its own inode; breaks if the target is deleted; works on folders. Hard link: same inode as the file; content stays until every link is deleted; files only.

**3. Why use a symlink for app versions (e.g. Prometheus)?**

Everything uses one stable path. To upgrade, just re-point the symlink to the new version's folder - no other config changes.

**4. Why keep app data on a separate EBS volume?**

The root disk is deleted with the instance. A separate volume has its own lifecycle, keeps OS and data apart, and can be resized or moved on its own.

**5. Can I attach an EBS volume from another Availability Zone?**

No. The volume must be in the same AZ as the instance.

**6. Steps to make a new disk usable?**

`lsblk` → partition with `parted` → `mkfs.xfs` → `mkdir` + `mount` → get UUID with `blkid` → add to `/etc/fstab` → test with `mount -a`.

**7. Why mount by UUID in `/etc/fstab` instead of `/dev/nvme1n1p1`?**

Device names can change after a reboot on AWS; the UUID never changes, so the right disk always mounts at the right place.

**8. What does `nofail` do in `/etc/fstab`?**

If that disk is missing or slow at boot, the server still boots instead of getting stuck.

**9. I increased the EBS size in AWS but `df -h` shows no extra space. Why?**

Each layer must be grown: `growpart` (partition) → `lvextend` (logical volume, if LVM) → `xfs_growfs` (filesystem).

**10. What are `/etc`, `/var`, `/opt` and `/proc` for?**

`/etc` = system config, `/var` = changing data and logs (`/var/log`), `/opt` = third-party software, `/proc` = virtual folder with live process and system info.
