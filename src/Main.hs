#!/usr/bin/env runhaskell
{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE QuasiQuotes, OverloadedStrings #-}
module Main where
import System.Process
import System.Exit
import Text.Printf (printf)
import System.Environment (getArgs)
import qualified Data.Text.Internal.Lazy
import qualified Data.Text.Lazy
import Data.Time

import Text.Shakespeare.Text
import qualified Data.Text.Lazy.IO as TLIO
import Data.Text

timeCommand :: FilePath -> [String] -> IO (Double, (ExitCode, String, String))
timeCommand f a = do
  start <- getCurrentTime
  x <- readProcessWithExitCode f a []
  end <- getCurrentTime
  let t = diffUTCTime end start
  return (realToFrac t, x)

dt :: Double -> Text
dt = Data.Text.pack . printf "%f"

data CommandResult = CommandResult {
  runTime :: Double,
  exitStatus :: ExitCode,
  stdOut :: String,
  stdErr :: String,
  commandName :: String
} deriving (Show)

toCommandResult :: (Double, (ExitCode, String, String)) -> String -> CommandResult
toCommandResult (t, (ex, o, err)) c = CommandResult {
  runTime=t, exitStatus = ex, stdOut = o, stdErr = err, commandName=c}

makeError :: CommandResult -> Data.Text.Internal.Lazy.Text
makeError cr@CommandResult {exitStatus = ExitFailure e} = [lt|<?xml version="1.0" encoding="UTF-8" ?>
<prtg>
    <error>1</error>
    <text>
      Command Name: #{commandName cr}
      Exit Status: #{e}
      StdOut: #{stdOut cr}
      StdErr: #{stdErr cr}
    </text>
</prtg>
|]
makeError _ = [lt|Unknown Error|] -- Should never occur

isError :: CommandResult -> Bool
isError CommandResult {exitStatus = ExitFailure _} = True
isError _ = False

makeResult :: CommandResult -> Data.Text.Internal.Lazy.Text
makeResult cr = [lt|<result>
    <channel>#{commandName cr}</channel>
    <unit>TimeSeconds</unit>
    <showChart>1</showChart>
    <showTable>1</showTable>
    <float>1</float>
    <value>#{dt $ runTime cr}</value>
</result>
|]

makeResults :: [CommandResult] -> Data.Text.Internal.Lazy.Text
makeResults cr = [lt|<?xml version="1.0" encoding="UTF-8" ?>
<prtg>#{r}</prtg>
|]
  where r = Prelude.foldl Data.Text.Lazy.append "" (Prelude.map makeResult cr)

cleanup :: String -> IO (ExitCode, String, String)
cleanup drive = readProcessWithExitCode "cmd" ["/c net use /delete /y " ++ drive] []

-- command line arguments, hostanme, drive letter to use while mapping, file to read without drive letter
go :: [String] -> IO ()
go [host, share, drive, fileName] = do --(host:(share:(drive:(fileName:[]))))
  _ <- cleanup drive
  x1 <- timeCommand "cmd" ["/c net use " ++ drive ++ " \\\\" ++ host ++ "\\" ++ share]
  --print x1
  let r1 = toCommandResult x1 "Map Share"
  if isError r1 then
    TLIO.putStr $ makeError r1
  else do
    x2 <- timeCommand "cmd" ["/c dir " ++ drive]
    --print x2
    let r2 = toCommandResult x2 "List Dir"
    if isError r2 then
      TLIO.putStr $ makeError r2
    else do
      x3 <- timeCommand "cmd" ["/c type " ++ drive ++ "\\" ++ fileName]
      --print x3
      let r3 = toCommandResult x3 "Read File"
      if isError r3 then
        TLIO.putStr $ makeError r3
      else
        TLIO.putStr $ makeResults [r1,r2,r3]
    _ <- cleanup drive
    return ()
go _ = putStrLn "Please provide a host name, drive letter, and file name."

main :: IO ()
main = do
  args <- getArgs
  go args
