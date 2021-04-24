# Laboratory B
Group 4
Predrag Bozhovikj, Erik Sievers

## Part one: parallelising the multiple puzzles

For 100 benchmark runs, running the benchmark takes 77.02 seconds. When we parallelize the solving of the various puzzles, the speedup is fairly small: solving the puzzles in parallel takes 47.50s. The reason can be found when looking at how long each puzzle takes to solve:
```
{77023483,
 [{wildcat,0.42735},
  {diabolical,53.09819},
  {vegard_hanssen,119.4723},
  {challenge,12.75032},
  {challenge1,512.22093},
  {extreme,12.560649999999999},
  {seventeen,59.704879999999996}]}
```
  As we can see, the challenge1 puzzle is by far the slowest to solve: in fact, it takes longer to solve that puzzle than all other puzzles combined. Analysing using percept confirms this: most processes finish quickly, apart from one.
  ![](Parallel.png)
  Contrast this with the sequential implementation that does all work on one thread.
  ![](Sequential.png)

  Results:
  * Sequential: 77s
  * Parallel search: 59s, speedup 30%
  <!-- * Parallel search + parallel refine: 144s -->
  * Parallel refine: 80.71s, speedup -5%
  * Parallel refine_rows: Approx. 36 minutes, speedup -12'733%

After trying various implementations, our results seem to indicate that the most promising parallelism we can find is doing the search for a solution in parallel. The other forms of parallelism seem to be too finely granular to be worthwhile and actively worsen the performance.

The benchmarks were run on a MacBook Pro with two cores

  After implementing worker pools and splitting of the initial decision tree into one process for each, the number of processes jumps drastically without a significant speedup in execution (46.4s), as can be seen in percept.
  ![](ConcurrentInitialTreeSplit.png) 