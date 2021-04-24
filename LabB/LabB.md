# Laboratory B
Group 4
Predrag Bozhovikj, Erik Sievers

## Part one: parallelising the multiple puzzles

For 100 benchmark runs, running the benchmark takes 77.02 seconds. When we parallelize the solving of the various puzzles, the speedup is fairly small: solving the puzzles in parallel takes 47.50s. The reason can be found when looking at how long each puzzle takes to solve:
```
i7 Dual-Core
{77023483,
 [{wildcat,0.42735},
  {diabolical,53.09819},
  {vegard_hanssen,119.4723},
  {challenge,12.75032},
  {challenge1,512.22093},
  {extreme,12.560649999999999},
  {seventeen,59.704879999999996}]}

i7 Quad-Core
{81769956,
 [{wildcat,0.47587},
  {diabolical,65.51498000000001},
  {vegard_hanssen,139.65792000000002},
  {challenge,11.45117},
  {challenge1,539.63801},
  {extreme,12.84231},
  {seventeen,48.11901}]}
```

As we can see, the challenge1 puzzle is by far the slowest to solve: in fact, it takes longer to solve that puzzle than all other puzzles combined. Analysing using percept confirms this: most processes finish quickly, apart from one.
![](Parallel.png)
Contrast this with the sequential implementation that does all work on one thread.
![](Sequential.png)

We tried three different approaches to parallelising the solver:
1. Parallelising the refinement of rows using `spawn_link`
2. Parallel search using a worker pool.
3. Parallelising the calls to `refine` in `guesses` using a worker pool

  Results:
  * Sequential: 77s
  * Parallel refine_rows: Approx. 36 minutes (running it for 1 execution instead of 100 took 18s), speedup -12'733%
  * Parallel search: 59s, speedup 30%
  <!-- * Parallel search + parallel refine: 144s -->
  * Parallel `guesses`: 80.71s, speedup -5%

The benchmarks were run on a MacBook Pro with a Dual-Core Intel Core i7 processor with HyperThreading and 16GB of RAM.

After trying various implementations, our results seem to indicate that the most promising parallelism we can find is doing the search for a solution in parallel. The other forms of parallelism seem to be too finely granular to be worthwhile and actively worsen the performance. 

Afterwards, we tried running the sequential benchmark as well as the parallel search on a stronger computer (Intel i7-3770 Quad-Core with 16 GB of RAM) with the following results:

```
{41182814,
 [{wildcat,0.47749},
  {diabolical,58.20495},
  {vegard_hanssen,72.32024},
  {challenge,9.590959999999999},
  {challenge1,198.61944},
  {extreme,13.72321},
  {seventeen,58.891529999999996}]}
```

<!-- After implementing worker pools and splitting of the initial decision tree into one process for each, the number of processes jumps drastically without a significant speedup in execution (46.4s), as can be seen in percept. -->
<!-- ![](ConcurrentInitialTreeSplit.png) -->