import Data.List
import Data.Maybe
import System.Random
import Criterion.Main
import Control.Parallel
import Control.Parallel.Strategies
import Control.Monad.Par
import Sudoku
import Control.Exception
import System.Environment
import Control.Parallel.Strategies hiding (parMap)
import GHC.Conc hiding (par, pseq)

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


-- PREDRAG BOZHOVIKJ & ERIK SIEVERS
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
chunkMap f x = map f x `using` parListChunk 100 rdeepseq

-- d) Par monad
chunkList :: Int -> [a] -> [[a]]
chunkList _ [] = []
chunkList n xs = as : chunkList n bs where (as,bs) = splitAt n xs

numOfCores :: Int
numOfCores = 4

_parMap :: NFData b => (a -> b) -> [a] -> [b]
_parMap f as =
  runPar $ do                       -- v  number of IVars per core
           ivars <- loop (numOfCores * 64) f as
           done <- mapM get ivars
           return $ concat done
  where
    loop :: NFData b => Int -> (a -> b) -> [a] -> Par [IVar [b]]
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

-- Assignment 2, divide and conquer
-- Rethinking this. I want a signature
-- dnc :: (a -> b) -> a -> (a -> (a,a)) -> (b -> b -> c)
-- dnc :: f divider combiner data

dnc :: (a -> b) -> a -> a -> (b -> b -> c) -> c
dnc f d1 d2 g = runEval $ do
    d1' <- rpar (f d1)
    d2' <- rpar (f d2) 
    return (g d1' d2')

msort :: Ord a => [a] -> [a]
msort xs
    | length xs < 2 = xs
    | otherwise     = let
        (x1, x2) = splitAt ((length xs + 1) `div` 2) xs
        in dnc msort x1 x2 ms

ms :: Ord a => [a] -> [a] -> [a]
ms [] xs        = xs
ms xs []        = xs
ms (x:xs) (y:ys) = if x < y
    then x:(ms xs (y:ys))
    else y:(ms (x:xs) ys)

msearch :: Eq a => a -> [a] -> Bool
msearch _ [] = False
msearch a (x:[]) = a == x
msearch a xs = let
        (x1, x2) = splitAt ((length xs + 1) `div` 2) xs
        in dnc (msearch a) x1 x2 (||)

-- Assignment 3, Sudoku

parBufferChunk :: Int -> Int -> Strategy a -> Strategy [a]
parBufferChunk bSize cSize strat xs
  | cSize <= 1  = parBuffer bSize strat xs
  | otherwise   = concat `fmap`
    (parBuffer bSize) (parListChunk cSize strat) (chunk cSize xs)


chunk :: Int -> [a] -> [[a]]
chunk _ [] = []
chunk n xs = as : chunk n bs where (as,bs) = splitAt n xs

main = do
  let (xs,ys) = splitAt 1500  (take 6000
                               (randoms (mkStdGen 211570155)) :: [Float] )
  -- handy (later) to give same input different parallel functions

  let rs = crud xs ++ ys
  putStrLn $ "sample mean:    " ++ show (mean rs)

  let j = pJackknife _parMap mean rs :: [Float]
  putStrLn $ "jack mean min:  " ++ show (minimum j)
  putStrLn $ "jack mean max:  " ++ show (maximum j)

  -- Assignment 2 
  let zs = take 600000 (randoms (mkStdGen 211570155)) :: [Integer]

  -- Assignment 3
  [f] <- getArgs
  file <- readFile f

  let puzzles = lines file
  let solutions = (map solve puzzles) `using` (parBuffer 100 rdeepseq)

  evaluate (length puzzles)
  print (length (filter isJust solutions))

  defaultMain
        [
          bench "map      (sequential)" (nf (pJackknife map mean) rs)
          bench "pmap     (par, pseq)" (nf (pJackknife pmap mean) rs),
          bench "rpmap    (rpar, rseq)" (nf (pJackknife rpmap mean) rs),
          bench "chunkMap (strategies)" (nf (pJackknife chunkMap mean) rs),
          bench "_parMap  (Par monad)" (nf (pJackknife _parMap mean) rs),
          bench "built-in sort" (nf sort xs),
          bench "divide and conquer sort" (nf msort xs),
          bench "built-in search" (nf (elem 0) xs),
          bench "divide and conquer search" (nf (msearch 0) xs)
        ]
