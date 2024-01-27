-- Copyright 2024 Nathan Waltz

-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the “Software”)
-- to deal in the Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
-- OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
-- DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
-- ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- DEALINGS IN THE SOFTWARE.

module Main where

import Prelude

import Data.Foldable (fold)
import Effect (Effect)
import Effect.Aff (Aff, launchAff_)
import Node.Path (FilePath)
import Options.Applicative (execParser, fullDesc, header, help, helper, info, long, progDesc, short, strOption)
import Options.Applicative as OptParse
import Options.Applicative.Internal.Utils ((<**>))
import Run (Run, interpretRec, runBaseAff')
import Run as Run
import Therian.Effects.Log.Log (LOG, _log, handleLog)
import Therian.Effects.Radare.R2 (RUN_RADARE_ON_FILE, _runRadareOnFile, handleRunRadareOnFile, radareAnalyze, radareWriteGraphToFile, runRadareOnFile)
import Type.Row (type (+))

--------------------------------------------------------

data CliArguments = CliArguments
  { inputFile :: FilePath
  , outputFile :: FilePath
  }

argumentParser :: OptParse.Parser CliArguments
argumentParser = ado
  inputFile <- strOption $ fold
    [ long "inputFile"
    , short 'i'
    , help "Input file to target"
    ]

  outputFile <- strOption $ fold
    [ long "outputFile"
    , short 'o'
    , help "Output file to target"
    ]
  in
    CliArguments
      { inputFile
      , outputFile
      }

--------------------------------------------------------

type ProgramEffects = LOG
  + RUN_RADARE_ON_FILE
  + ()

effectInterpreter :: Run ProgramEffects Unit -> Aff Unit
effectInterpreter = runBaseAff' <<< void <<< interpretRec
  ( Run.case_
      # Run.on _log handleLog
      # Run.on _runRadareOnFile handleRunRadareOnFile
  )

program :: CliArguments -> Run ProgramEffects Unit
program (CliArguments { inputFile, outputFile }) = do
  runRadareOnFile inputFile do
    radareAnalyze
    radareWriteGraphToFile (outputFile <> ".tmp")

main :: Effect Unit
main = do
  args <- execParser opts
  launchAff_ do
    effectInterpreter $ program args
  where
  opts = info (argumentParser <**> helper)
    ( fullDesc
        <> progDesc "Extract graphical features from a program"
        <> header "Therian Feature Extractor"
    )

