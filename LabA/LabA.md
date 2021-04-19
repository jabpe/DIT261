# Laboratory A
Group 4
Predrag Bozhovikj, Erik Sievers

## Assignment 1

Benchmarks on modified function `pJackknife m f` with injected mapping function `m` modified to be parallelised.

### `pmap`: `par, pseq`

```
  SPARKS: 93500 (93500 converted, 0 overflowed, 0 dud, 0 GC'd, 0 fizzled)

  INIT    time    0.001s  (  0.005s elapsed)
  MUT     time    1.021s  (  1.986s elapsed)
  GC      time   30.969s  (  6.683s elapsed)
  EXIT    time    0.000s  (  0.010s elapsed)
  Total   time   31.991s  (  8.684s elapsed)

  Alloc rate    26,241,755,070 bytes per MUT second

  Productivity   3.2% of total user, 22.9% of total elapsed
```

### `rpmap`: `rpar, rseq`

Ran with params `+RTS -A250m -lf -N4 -s` to minimise GC activity resulting in high memory use.

```
            1061 MiB total memory in use (0 MB lost due to fragmentation)
  SPARKS: 165000 (165000 converted, 0 overflowed, 0 dud, 0 GC'd, 0 fizzled)

  INIT    time    0.004s  (  0.241s elapsed)
  MUT     time   20.927s  (  5.395s elapsed)
  GC      time    0.731s  (  0.219s elapsed)
  EXIT    time   -0.000s  (  0.009s elapsed)
  Total   time   21.661s  (  5.863s elapsed)

  Alloc rate    2,256,602,354 bytes per MUT second

  Productivity  96.6% of total user, 92.0% of total elapsed
```

### `chunkMap`: Strategy

Ran with params `+RTS -A300m -lf -N4 -s` to minimise GC activity resulting in high memory use. Chunk size: 15. Found possible optimum after several retries. 

```
            1250 MiB total memory in use (0 MB lost due to fragmentation)

  SPARKS: 11010 (10930 converted, 0 overflowed, 0 dud, 0 GC'd, 80 fizzled)

  INIT    time    0.004s  (  0.296s elapsed)
  MUT     time   20.828s  (  5.362s elapsed)
  GC      time    0.311s  (  0.096s elapsed)
  EXIT    time    0.000s  (  0.008s elapsed)
  Total   time   21.144s  (  5.762s elapsed)

  Alloc rate    2,268,611,939 bytes per MUT second

  Productivity  98.5% of total user, 93.1% of total elapsed
```

### Par monad

## Assignment 2

<!-- Todo: add benchmarks -->

## Assignment 3

### 3.1 parBuffer

parBuffer takes an integer and a strategy as a parameter and then puts that number of sparks in a buffer. Once a spark is done, another can be added.

### 3.2 Compare parListChunk with parBuffer

<!-- Insert screenshots of threadscope spark pool and explain -->

### 3.3 Combine chunking with parBuffer

<!-- Try it out, look at threadscope and explain what's going on -->