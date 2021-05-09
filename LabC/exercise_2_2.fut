let segscan [n] 't (op: t -> t -> t) (ne: t) (arr: [n] (t, bool)): [n]t = scan (st op ne) ne arr


let st (op: t -> t -> t) (ne: t) =
    ((t1: t, b1: bool), (t2: t, b2: bool) -> 
        if      b2 then ((op ne t2), b2)
        else            ((op t1 t2), b2)
    -- While the bool is false, keep accumulating
    -- When it's not, return neutrla element combined with the element
