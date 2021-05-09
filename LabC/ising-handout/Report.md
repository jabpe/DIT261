### 2D Ising Model

We ran the ising model benchmarks with four different sizes and three different number of iterations:
|                               Size | Iterations | Time OpenCL | Time Sequential |
| ---------------------------------: | :--------: | :---------: | :-------------: |
|                             10x10  |    2       |  1499μs     |    72μs         |
|                             30x30  |    2       |  1456μs     |    353μs         |
|                             90x90  |    2       |  1393μs     |    2303μs         |
|                           270x270  |    2       |  2600μs     |    21281μs         |
|                             10x10  |    20      |  4780μs     |    385μs         |
|                             30x30  |    20      |  3888μs     |    2627μs         |
|                             90x90  |    20      |  3026μs     |    18394μs         |
|                           270x270  |    20      |  8002μs     |    142951μs         |
|                             10x10  |    200     |  26983μs     |    2554μs         |
|                             30x30  |    200     |  21323μs     |    22602μs         |
|                             90x90  |    200     |  22088μs     |    155655μs         |
|                           270x270  |    200     |  48805μs     |    1510192μs         |

The computer used was a Macbook with an integrated GPU.

![](ising-small.pdf)
The first chart is for two iterations. As we can see, even with an integrated GPU the scaling for large problem sizes is impressive. There is a large overhead for using the GPU however.

![](ising-large.pdf)
The second chart is for 20 iterations. The pattern is similar to the one we saw with two iterations. 

![](ising-xl.pdf)
The third chart is for 200 iterations. The pattern is yet again similar to the one we saw with two iterations.

![](ising-combined.pdf)
The final chard is showing the runtime across all number of iterations for all sizes. Interestingly, across all number of iterations the 10x10 model took longer to compute compared to both the 30x30 and 90x90 model when using OpenCL. OpenCL scales significantly better with regards to problem size for all number of iterations, but it also scales _slightly_ better with regards to the number of iterations compared to the sequential implementation