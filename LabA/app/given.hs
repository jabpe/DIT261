import Data.List
import System.Random
import Criterion.Main
import Control.Parallel
import Control.Parallel.Strategies

-- code borrowed from the Stanford Course 240h (Functional Systems in Haskell)
-- I suspect it comes from Bryan O'Sullivan, author of Criterion

data T a = T !a !Int


mean :: (RealFrac a) => [a] -> a
mean = fini . foldl' go (T 0 0)
  where
    fini (T a _) = a
    go (T m n) x = T m' n'
      where m' = m + (x - m) / fromIntegral n'
            n' = n + 1


resamples :: Int -> [a] -> [[a]]
resamples k xs =
    take (length xs - k) $
    zipWith (++) (inits xs) (map (drop k) (tails xs))


jackknife :: ([a] -> b) -> [a] -> [b]
jackknife f = map f . resamples 500

crud = zipWith (\x a -> sin (x / 300)**2 + a) [0..]

pJackknife :: (([a] -> b) -> [[a]] -> [b]) -> ([a] -> b) -> [a] -> [b]
pJackknife m f = m f . resamples 500

-- ASSIGNMENT 1
-- a) par, pseq
pmap :: (a -> b) -> [a] -> [b]
pmap _ [] = []
pmap f (x:xs) = let fx = f x
                    mapxs = pmap f xs
                in
                    fx `par` mapxs `pseq` fx : mapxs

-- b) rpar, rseq
rpmap :: (a -> b) -> [a] -> [b]
rpmap _ [] = []
rpmap f (x:xs) = runEval $ do
                 fx <- rpar $ f x
                 mapxs <- rseq $ rpmap f xs
                 return $ fx:mapxs

-- c) strategy
chunkMap :: NFData  b => (a -> b) -> [a] -> [b]
chunkMap f x = map f x `using` parListChunk 15 rdeepseq

-- d) Par monad
-- parMap :: NFData b => (a -> b) -> [a] -> Par [b]
-- parMap f as = do
--   ibs <- mapM (spawn . return . f) as
--   mapM get ibs

-- ASSIGNMENT 2
-- psort reinvented
psort :: NFData a => Ord a => [a] -> [a]
psort [] = []
psort (x:xs) = psort [y | y <-xs, y<x] ++ [x] ++ psort [y | y <-xs, y>=x] `using` parBuffer 100 rdeepseq

main = do
  let (xs,ys) = splitAt 1500  (take 6000
                               (randoms (mkStdGen 211570155)) :: [Float] )
  -- handy (later) to give same input different parallel functions

  let rs = crud xs ++ ys
  putStrLn $ "sample mean:    " ++ show (mean rs)

  -- let j = pJackknife chunkMap mean rs :: [Float]
  -- putStrLn $ "jack mean min:  " ++ show (minimum j)
  -- putStrLn $ "jack mean max:  " ++ show (maximum j)
  defaultMain
        [
        --  bench "jackknife" (nf (pJackknife chunkMap mean) rs)
        --  bench "psort 25" (nf (psort 25) rs)
        -- bench "psort 50" (nf (psort 50) rs)
        bench "psort" (nf psort rs)
         ]
