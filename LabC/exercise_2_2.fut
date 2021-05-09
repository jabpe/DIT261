-- Call it with echo [1,2,3,4,5,6,7,8,9,10] [true,false,true,false,true,false,true,false,true,false] | ./exercise_2_2

-- Helper function for segmented scan
let st 't (op: t -> t -> t) (ne: t) =
    (\(t1, _b1) (t2, b2) -> 
        if      b2 then ((op ne t2), b2)
        else            ((op t1 t2), b2)
    )

let segscan [n] 't (op: t -> t -> t) (ne: t) (arr: [n] (t, bool)): [n]t =
    map (\(n, _b) -> n) (scan (st op ne) (ne, false) arr)

    -- While the bool is false, keep accumulating
    -- When it's not, return neutral element combined with the element

let main (xs: []i32) (ys: []bool) =
  segscan (+) 0 (zip xs ys)