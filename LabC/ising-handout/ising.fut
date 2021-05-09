-- We represent a spin as a single byte.  In principle, we need only
-- two values (-1 or 1), but Futhark represents booleans a a full byte
-- entirely, so using an i8 instead takes no more space, and makes the
-- arithmetic simpler.
type spin = i8

import "lib/github.com/diku-dk/cpprandom/random"

-- Pick an RNG engine and define random distributions for specific types.
module rng_engine = minstd_rand
module rand_f32 = uniform_real_distribution f32 rng_engine
module rand_i8 = uniform_int_distribution i8 rng_engine

-- We can create an few RNG state with 'rng_engine.rng_from_seed [x]',
-- where 'x' is some seed.  We can split one RNG state into many with
-- 'rng_engine.split_rng'.
--
-- For an RNG state 'r', we can generate random integers that are
-- either 0 or 1 by calling 'rand_i8.rand (0i8, 1i8) r'.
--
-- For an RNG state 'r', we can generate random floats in the range
-- (0,1) by calling 'rand_f32.rand (0f32, 1f32) r'.
--
-- Remember to consult
-- https://futhark-lang.org/pkgs/github.com/diku-dk/cpprandom/latest/

let rand = rand_f32.rand (0f32, 1f32)

-- Create a new grid of a given size.  Also produce an identically
-- sized array of RNG states.
let random_grid (seed: i32) (h: i64) (w: i64)
              : ([h][w]rng_engine.rng, [h][w]spin) =
  let s = w*h
  let rs1 = rng_engine.split_rng s (rng_engine.rng_from_seed [seed])
  let ss1 = map (\r -> 
    let (_, i ) = rand_i8.rand (0i8, 1i8) r
    in i * 2 + 1) rs1
  let rs2 = unflatten h w rs1
  let ss2 = unflatten h w ss1
  in (rs2, ss2)

-- Create an array of randoms, then
-- Compute $\Delta_e$ for each spin in the grid, using wraparound at
-- the edges.
let deltas [h][w] (spins: [h][w]spin): [h][w]i8 =
  let s = h*w
  let m1 = flatten_to s (rotate (-1) spins)
  let m2 = flatten_to s (rotate 1 spins)
  let m3 = flatten_to s (map (rotate (-1)) spins)
  let m4 = flatten_to s (map (rotate 1) spins)
  let m5 = map5 (\s l r u d -> 2*s*(l + r + u + d)) (flatten_to s spins) m1 m2 m3 m4
  in unflatten h w m5

-- The sum of all deltas of a grid.  The result is a measure of how
-- ordered the grid is.
let delta_sum [h][w] (spins: [w][h]spin): i32 =
  let ms = flatten (deltas spins)
  in reduce (+) 0 (map (\e -> i32.i8 e) ms)

-- Take one step in the Ising 2D simulation.
let step [h][w] (abs_temp: f32) (samplerate: f32)
                (rngs: [h][w]rng_engine.rng) (spins: [h][w]spin)
              : ([h][w]rng_engine.rng, [h][w]spin) =
  -- Can't figure out how to get e from the standard library. This should work for now.
  let e = 2.718281828459045
  let s = h*w
  let ds = map f32.i8 (flatten_to s (deltas spins))
  let (rngs, as) = unzip (map (\r -> rand_f32.rand (0f32, 1f32) r) (flatten_to s rngs))
  let (rngs, bs) = unzip (map (\r -> rand_f32.rand (0f32, 1f32) r) rngs)
  let c1s = map (\a -> a < samplerate) as
  let c2s = map (\d -> d < -d) ds
  let c3s = map2 (\b d -> b < (e**(-d/abs_temp))) bs ds
  let cs = map3 (\c1 c2 c3 -> c1 && (c2 || c3)) c1s c2s c3s
  let ds2 = map2 (\c d1 -> if c then -d1 else d1) cs (flatten_to s spins)
  in (unflatten h w rngs, unflatten h w ds2)

-- | Just for benchmarking.
let main (abs_temp: f32) (samplerate: f32)
         (h: i64) (w: i64) (n: i32): [h][w]spin =
  (loop (rngs, spins) = random_grid 1337 h w for _i < n do
     step abs_temp samplerate rngs spins).1

-- ==
-- entry: main
-- input { 0.5f32 0.1f32 10i64 10i64 2 } auto output

-- The following definitions are for the visualisation and need not be modified.

type~ state = {cells: [][](rng_engine.rng, spin)}

entry tui_init seed h w : state =
  let (rngs, spins) = random_grid seed h w
  in {cells=map (uncurry zip) (zip rngs spins)}

entry tui_render (s: state) = map (map (.1)) s.cells

entry tui_step (abs_temp: f32) (samplerate: f32) (s: state) : state =
  let rngs = (map (map (.0)) s.cells)
  let spins = map (map (.1)) s.cells
  let (rngs', spins') = step abs_temp samplerate rngs spins
  in {cells=map (uncurry zip) (zip rngs' spins')}
