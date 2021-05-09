-- import "lib/github.com/diku -dk/sorts/radix_sort"
-- rbi dest f ne is as
-- express it as descriptive code…
-- p1 = map(i => dest[i], is)
-- p2 = map(f, zip p1 as)
-- scatter dest, is, p2


let reduce_by_index [m] [n] 'a (dest: *[m]a) (f: a -> a -> a) (ne: a) (is: [n]i64) (as: [n]a): *[m]a =
    let p1 = map (\i -> dest[i]) is
    let p2 = map2 f p1 as
    in scatter dest is p2

let main (is: []i64) (as: []i64) =
    reduce_by_index (iota 10) (+) 0 is as