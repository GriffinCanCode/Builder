module Main where

import Data.List (sort)
import System.Environment (getArgs)

-- | Greeting module
greet :: String -> String
greet name = "Hello, " ++ name ++ "!"

-- | Calculate factorial
factorial :: Integer -> Integer
factorial 0 = 1
factorial n = n * factorial (n - 1)

-- | Check if a number is prime
isPrime :: Integer -> Bool
isPrime n
    | n < 2 = False
    | otherwise = null [x | x <- [2..isqrt n], n `mod` x == 0]
  where
    isqrt = floor . sqrt . fromIntegral

-- | Main entry point
main :: IO ()
main = do
    args <- getArgs
    case args of
        [] -> do
            putStrLn $ greet "World"
            putStrLn $ "Factorial of 10: " ++ show (factorial 10)
            putStrLn $ "Is 17 prime? " ++ show (isPrime 17)
            putStrLn $ "Sorted list: " ++ show (sort [5, 2, 8, 1, 9])
        (name:_) -> putStrLn $ greet name

