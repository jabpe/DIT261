import Data.List
import System.Random
import Criterion.Main
import Control.Parallel
import Control.Parallel.Strategies
import Control.Monad.Par

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


-- PREDRAG BOZHOVIKJ
-- April 2021
-- LabA

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
chunkMap :: NFData b => (a -> b) -> [a] -> [b]
chunkMap f x = map f x `using` parListChunk 15 rdeepseq

-- d) Par monad
chunkList :: Int -> [a] -> [[a]]
chunkList _ [] = []
chunkList n xs = as : chunkList n bs where (as,bs) = splitAt n xs

numOfCores :: Int
numOfCores = 4

_parMap :: NFData b => (a -> b) -> [a] -> [b]
_parMap f as =
  runPar $ do
           ivars <- loop (numOfCores * 64) f as
           done <- mapM get ivars
           return $ concat done
  where
    loop :: NFData b => Int -> (a -> b) -> [a] -> Par [IVar [b]]
    -- loop _ _ [] = return []
    loop 1 f as = do
                  t <- spawn . return $ map f as
                  return [t]
    loop t f as = do
                  let halfT = t `div` 2
                  let halfList = (length as + 1) `div` 2
                  let [left, right] = chunkList halfList as
                  l <- loop halfT f left
                  r <- loop halfT f right
                  return $ l ++ r

-- ASSIGNMENT 2
-- qsort reinvented with strategies as psort
psort :: NFData a => Ord a => [a] -> [a]
psort [] = []
psort (x:xs) = psort [y | y <-xs, y<x] ++ [x] ++ psort [y | y <-xs, y>=x] `using` parBuffer 100 rdeepseq

-- second divide and conquer a


main = do
  let (xs,ys) = splitAt 1500  (take 6000
                               (randoms (mkStdGen 211570155)) :: [Float] )
  -- handy (later) to give same input different parallel functions

  let rs = crud xs ++ ys
  putStrLn $ "sample mean:    " ++ show (mean rs)

  let j = pJackknife _parMap mean rs :: [Float]
  putStrLn $ "jack mean min:  " ++ show (minimum j)
  putStrLn $ "jack mean max:  " ++ show (maximum j)
  defaultMain
        [
         bench "jackknife" (nf (pJackknife _parMap mean) rs)
        --  bench "psort 25" (nf (psort 25) rs)
        -- bench "psort 50" (nf (psort 50) rs)
        -- bench "psort" (nf psort rs)
        ]
