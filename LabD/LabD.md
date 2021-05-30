# Lab D
Erik Sievers, Predrag Bozhovikj

---

The benchmarks were run on a single MacBook Pro with a 2.5GHz Dual-Core Intel Core i7 processor and 16gb of ram. Four processes were used.

|     Approach          |                    Execution time seconds   |
| ------------------: | :-----------------------------------------: |
| Parallel (local)      |               396809258                   |
| Parallel (distributed) |              513005139                   |
| Parallel (worker pool) |              420058936                   |

Since we're running on a single machine, it's not all that surprising that the extra overhead from working on multiple nodes causes a slowdown. What's interesting to us is how close to local performance the worker pool is, with only a 6% difference in execution time. If we were to scale this across multiple machines on the same network and ensure enough processess for all machines, we would likely get significantly better performance because of the parallel nature of map reduce.