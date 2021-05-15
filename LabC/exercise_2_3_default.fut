-- ==
-- input @ i_100_i64s
-- input @ i_1000_i64s
-- input @ i_10000_i64s
-- input @ i_100000_i64s
-- input @ i_1000000_i64s

let main (is: []i64) (as: []i64) =
    reduce_by_index (replicate 10000 0) (+) 0 is as

-- echo [1,2,3,1,2,3,1,2,3,1] [1,2,3,4,5,6,7,8,9,0] | ./exercise_2_3