-- ==
-- input @ sr_100_i32s
-- input @ sr_1000_i32s
-- input @ sr_10000_i32s
-- input @ sr_100000_i32s
-- input @ sr_1000000_i32s
-- input @ sr_5000000_i32s
-- input @ sr_10000000_i32s

let main (xs: []i32) (ys: []bool) =
  reduce (+) 0 xs