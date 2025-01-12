---
title: Project Goals
description: What it's all about
draft: true
---

### About This Project

Welcome to the documentation for my Raspberry Pi 5 cluster.

This project aims to automate creation of a resilient, low-cost, energy-efficient cluster with 'self replicating' capabilities.

The cluster is designed to be fully declarative and self-sustaining, capable of replicating itself and dynamically adapting to hardware changes.

---

### **Project Goals**

1. **Reproducibility**:
   Every aspect of the cluster—down to the operating system configuration—is fully defined in code using NixOS and GitOps. This ensures that the entire system can be rebuilt from scratch at any time, removing reliance on manual setup or undocumented tweaks.

2. **Resilience**:
   By leveraging netboot with TFTP and NFS, the cluster nodes boot without local storage. A node can replicate itself, flash an SD card dynamically, and take over critical services if the bootstrap node fails, avoiding a single point of failure.

3. **Automation**:
   From provisioning and deploying software to self-replication and node recovery, the cluster relies on automated workflows. This reduces complexity while showcasing the potential for modern DevOps techniques applied at the edge.

4. **Scalability and Modularity**:
   Each node operates as part of a dynamic cluster running K3S, enabling the seamless scaling of workloads. Additional nodes can be added with minimal configuration, and features like NVMe storage integration provide enhanced flexibility.

---

### **Key Features**

- **Netboot Infrastructure**:
  Nodes boot entirely from the network using TFTP and NFS, removing dependency on local storage during operation.

- **Self-Replication**:
  A custom workflow enables nodes to detect attached storage (e.g., SD cards) and flash prebuilt system images to make themselves persistent. This allows the cluster to sustain itself even if the initial bootstrap VM is shut down.

- **GitOps Integration**:
  System configurations are tracked in a Git repository, ensuring every change is version-controlled and easily rolled back.

- **Dynamic Role Assignment**:
  Using floating IPs and priority-based failover, the cluster ensures critical services (like TFTP and NFS) remain available by transferring roles to the appropriate node dynamically.

- **Ephemeral Data Philosophy**:
  User data does not persist by default, aligning with the project's goal of creating a fully reproducible system where nothing depends on manual intervention.

- **NVMe Storage Integration with Longhorn**:
  Nodes with attached NVMe drives are automatically added to a Longhorn storage pool, enabling dynamic and distributed storage capabilities.

- **Power Efficiency and PoE**:
  The cluster leverages Power over Ethernet (PoE) to reduce wiring clutter and ensure efficient power delivery to each node.

---

### **Benefits**

- **Local Resilience**:
  The cluster operates entirely within a local network, ensuring that services remain accessible even during internet outages.

- **Reduced Hardware Costs**:
  Using affordable Raspberry Pi hardware and network booting eliminates the need for expensive storage or additional infrastructure.

- **Hands-On Learning**:
  This project showcases advanced topics like NixOS, K3S, GitOps, and self-healing clusters, making it a great resource for learning modern DevOps practices.

- **Data Ownership**:
  By running services locally, you retain full control over your data, aligning with the original vision of the decentralized internet.

---

This project represents a blend of innovation, practicality, and curiosity. Whether you're interested in edge computing, cluster automation, or exploring the limits of affordable hardware, this setup demonstrates the incredible potential of combining declarative systems and modern orchestration tools.