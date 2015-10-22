{-# LANGUAGE QuasiQuotes, TemplateHaskell, TypeFamilies #-}
{-# LANGUAGE OverloadedStrings, GADTs, FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

import System.Console.ANSI
import System.Environment
import Data.Text (Text, pack)
import Data.Time.Clock
import Data.Time.Calendar
import Data.List.Split (splitOn)
import Control.Concurrent (threadDelay)
import Text.Printf
import System.Process

-- Configuration file
import qualified Data.ByteString.Char8 as BS
import Data.Yaml
import Control.Applicative
import Data.Maybe (isNothing, fromJust)

-- Database manipulation
import Database.Persist
import Database.Persist.Sqlite
import Database.Persist.TH ( mkPersist, mkMigrate, persistLowerCase
                           , share, sqlSettings)

-------------------------------------------
-- Configuration declaration and parsing --
-------------------------------------------

data Configuration = Configuration String String String String Integer

instance FromJSON Configuration where
    parseJSON (Object v) = Configuration
                           <$> v .: "database-file"
                           <*> v .: "notification-title"
                           <*> v .: "notification-text"
                           <*> v .: "notification-sound"
                           <*> v .: "duration"
    parseJSON _ = error "Unable to parse file"

readConfig :: FilePath -> IO Configuration
readConfig file = do
    mconfig <- decode <$> BS.readFile file
    if isNothing mconfig then do putStrLn "Unable to parse, using default"
                                 return $ Configuration "~/.pomodoro/database"
                                                        "Pomodoro"
                                                        "Time's Up!"
                                                        "~/.pomodoro/bell.mp3"
                                                        1500
                         else return $ fromJust mconfig

share [mkPersist sqlSettings, mkMigrate "migrateTables"] [persistLowerCase|
Pomodoro
    time        UTCTime
    category    [Text]
    description Text
|]

formatMinutes :: Integer -> String
formatMinutes n = let (m,s) = divMod n 60
                  in printf "%i:%02i" m s

wait tt s n = if n == tt then putStrLn "Acabou!"
                         else do
               t <- getCurrentTime
               clearLine
               cursorUpLine 1
               let diff = round (diffUTCTime t s)
               putStrLn (formatMinutes (tt - diff))
               threadDelay (10^6)
               wait tt s diff

main = do
    [configFile,categories,description] <- getArgs
    configuration <- readConfig configFile
    let Configuration databaseFile title text sound totalTime = configuration
    currentTime <- getCurrentTime
    let cats = map pack (splitOn "," categories)
        desc = pack description
    putStrLn ""
    wait totalTime currentTime 0
    callCommand $ "play -q " ++ sound  ++ "&"
    callCommand $ "notify-send '" ++ title ++ "' '" ++ text ++ "'"
    runSqlite (pack databaseFile) $ do
        runMigration migrateTables
        insert $ Pomodoro currentTime cats desc
