---
title: '[Temp] Cost'
description: TODO
---

## Node cost
| Configuration               | Master | Slave | Cluster Storage  | Cost                   |
|-----------------------------|--------|-------|------------------|------------------------|
| Pi + SD + NVMe + PoE        |  ✅   |  ❌   |  ✅              | £80+£5+£15+£22 = £122 |
| Pi + SD + NVMe              |  ✅   |  ❌   |  ✅              | £80+£5+£15 = £100     |
| Pi + SD + PoE               |  ✅   |  ❌   |  ❌              | £80+£5+£22 = £107     |
| Pi + SD                     |  ✅   |  ❌   |  ❌              | £80+£5 = £85          |
| Pi + NVMe + PoE             |  ❌   |  ✅   |  ✅              | £80+£15+£22 = £117    |
| Pi + NVMe                   |  ❌   |  ✅   |  ✅              | £80+£15 = £95         |
| Pi + PoE                    |  ❌   |  ✅   |  ❌              | £80+£22 = £102        |
| Pi                          |  ❌   |  ✅   |  ❌              | £80                   |