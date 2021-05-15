-- Call it with echo [1,2,3,4,5,6,7,8,9,10] [true,false,true,false,true,false,true,false,true,false] | ./exercise_2_2

-- Helper function for segmented scan
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

-- How do we do this with scatter?
-- We write the stuff that is preceeded by true to an array?

-- ==
-- input @ sr_100_i32s
-- input @ sr_1000_i32s
-- input @ sr_10000_i32s
-- input @ sr_100000_i32s
-- input @ sr_1000000_i32s
-- input @ sr_10000000_i32s

let main (xs: []i32) (ys: []bool) =
  segreduce (+) 0 (zip xs ys)

-- [3i32, 7i32, 11i32, 15i32, 9i32, 10i32]