# Introduction:

First of all, take a look on this: https://www.linux.com/news/understanding-and-securing-linux-namespaces/
And this: https://docs.docker.com/engine/security/userns-remap/
And this: https://www.nginx.com/blog/what-are-namespaces-cgroups-how-do-they-work/
I would also recommend you to scroll down a little bit and check all topics on SECURITY on Docker Docs.

# Defining the problem:

 This Custom image was build to andress a problem with TestContainers (Integration Test - Java). We detected that DockerD was not accessable neither via docker.sock
 nor via TCP/2375 (whithin  outter docker -> inner docker) or mounting a volume (once pods shares it).
 We tryied to disable SE Linux + AppArmor, selecting overlay2 as storage driver but seems that inner docker runs on top of a copy-on-write system (as we can see in AUFS,BTRFS,DeviceMapper)

 Docker Daemon is designed to have exclusive access to /var/lib/docker and to run as root. PODMAN seems a better option than docker, once it doesn't requires root.

 We finally found Sysbox (https://github.com/nestybox/sysbox) and Actions Runners Dockerfile (https://github.com/actions/actions-runner-controller/blob/master/runner/actions-runner-dind-rootless.ubuntu-20.04.dockerfile)

We spend 1 week to make Sysbox + Action-Runners-Controller Architecture to work together and all we got was a bunch of headaches: Runner restarting, Runner not connected, Sysbox restarting, Sysbox Failing Startup...

 We tried this: https://blog.nestybox.com/2020/10/21/gitlab-dind.html

 After reading this: https://news.ycombinator.com/item?id=24085910   and this   https://forum.gitlab.com/t/serious-security-issue-for-deployments-gitlabci-gitlab-ci-yml/24264

 And studing this: https://github.com/BBVA/kvm and all "APIs" to call containers

# The Solution:

 So, we decided to copy-n-paste everything in Sysbox and mix it up with Actions Runners Dockerfile (https://github.com/actions/actions-runner-controller/blob/master/runner/actions-runner-dind-rootless.ubuntu-20.04.dockerfile) and use Linux user namespace + Cgroups (???) approach.
 
 FYI check this link: https://github.com/nestybox/sysbox/blob/master/docs/user-guide/security.md


# Sysfs Virtualization

 We also have a problem when running BuildX (A docker plugin) which requires a "Sysfs Virtualization" made within the container.

 Error log below:

 Error: container_linux.go:370: starting container process caused: process_linux.go:459: container init caused: rootfs_linux.go:59: mounting "sysfs" to rootfs at "/sys" caused: operation not permitted: OCI permission denied

The problem here can be easily solved with Sysbox (see URL above about security).


# Future works:

-- We have a lot of flaws here that can be exploided by someone that knows how to use Linux Kernel (This is better than running rootFULL - OWASP top 10 - escalating priviledge attack)

-- Use PODMAN instead of DOCKER (URGENT)

-- privileged is enabled but not accessable (Linux user namespaces - Maybe not???)

-- https://github.com/msyea/github-actions-runner-rootless

-- Move out of Linux user Namespaces

-- Side-car + Runner + Podman: seems a better idea

