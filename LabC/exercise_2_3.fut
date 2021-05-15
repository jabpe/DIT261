import "lib/github.com/diku-dk/sorts/radix_sort"
-- rbi dest f ne is as
-- express it as descriptive code…
-- p1 = map(i => dest[i], is)
-- p2 = map(f, zip p1 as)
-- scatter dest, is, p2
let st 't (op: t -> t -> t) (ne: t) =
    (\(t1, _b1) (t2, b2) -> 
        if      b2 then ((op ne t2), b2)
        else            ((op t1 t2), b2)
    )

let length [n] 'a (xs: [n]a) = n

let iota1 n = map (\e -> e - 1) (iota n)

let gather 'a (is: []i64) (xs: []a) =
  map (\i -> xs[i]) is

let segreduce [n] 't (op: t -> t -> t) (ne: t) (arr: [n] (t, bool)): []t =
    let (vs, bs) = unzip (scan (st op ne) (ne, false) arr)
    let bs = (rotate (1) (bs with [0] = true))
    let (is, _) = unzip (filter (\(_, b) -> b) (zip vs bs))
    in is

let reduce_by_index [m] [n] 'a (dest: *[m]a) (f: a -> a -> a) (ne: a) (is: [n]i64) (as: [n]a): *[m]a =
    let iv = zip is as
    let (is, as) = unzip (radix_sort_by_key (\(i, _) -> i) i64.num_bits i64.get_bit iv)
    let flags = map2 (\i1 i2 -> i1 != i2) (rotate (-1) is) is
    let v1 = segreduce f ne (zip as flags)
    let (_, is) = unzip (filter (\(b, _) -> b) (zip flags is))
    let s = length is
    let (is, vs) = unzip (zip (is :> [s]i64) (v1 :> [s]a))
    let vf = map2 (\i v -> f dest[i] v) is vs
    in scatter dest is vf

let main (is: []i64) (as: []i64) =
    reduce_by_index (replicate 10 0) (+) 0 is as

-- echo [1,2,3,1,2,3,1,2,3,1] [1,2,3,4,5,6,7,8,9,0] | ./exercise_2_3