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

import Data.Array (concatMap, foldr, mapMaybe, sortWith)
import Data.Bifunctor (rmap)
import Data.Foldable (fold)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Set as Set
import Data.Traversable (for, sequence)
import Data.Tuple (Tuple(..), fst, snd)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Aff (Aff, launchAff_)
import Node.Path (FilePath)
import Options.Applicative (execParser, fullDesc, header, help, helper, info, long, progDesc, short, strOption)
import Options.Applicative as OptParse
import Options.Applicative.Internal.Utils ((<**>))
import Run (Run, interpretRec, runBaseAff')
import Run as Run
import Run.Except (EXCEPT, catch, rethrow)
import Therian.Data.GlobalCallgraph (GlobalCallgraph(..))
import Therian.Data.GlobalDataflow (DataflowGraph(..))
import Therian.Data.Output (Output)
import Therian.Effects.IO.File (WRITE_OUTPUT, _writeOutput, handleWriteOutput, writeOutput)
import Therian.Effects.Log.Log (LOG, _log, handleLog)
import Therian.Effects.Log.Log as Log
import Therian.Effects.Radare.R2 (RUN_RADARE_ON_FILE, _runRadareOnFile, analyzeFunction, handleRunRadareOnFile, radareAnalyze, readDataflowGraph, readFunctionCallgraph, retrieveFunctionData, runRadareOnFile)
import Therian.Process.Label (labelToVec, toLabel)
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

type ProgramEffects r2err r2out = LOG
  + RUN_RADARE_ON_FILE r2err r2out
  + WRITE_OUTPUT
  + EXCEPT String
  + ()

effectInterpreter :: forall r2err r2out. Run (ProgramEffects r2err r2out) Unit -> Aff Unit
effectInterpreter = runBaseAff' <<< void
  <<< interpretRec
    ( Run.case_
        # Run.on _log handleLog
        # Run.on _runRadareOnFile handleRunRadareOnFile
        # Run.on _writeOutput handleWriteOutput
    )
  <<< catch Log.log

toNominal :: forall a. Ord a => Eq a => Array a -> Map a Int
toNominal = snd <<< foldr accum (0 /\ Map.empty)
  where
  accum key (idx /\ dict) = case Map.lookup key dict of
    Just _ -> (idx /\ dict)
    Nothing -> ((idx + 1) /\ (Map.insert key idx dict))

program :: CliArguments -> Run (ProgramEffects String Output) Unit
program (CliArguments { inputFile, outputFile }) = do
  output <- rethrow =<< runRadareOnFile inputFile do
    radareAnalyze
    (GlobalCallgraph { edgelist }) <- readFunctionCallgraph >>= rethrow
    let
      (nodes :: Array String) =
        Set.toUnfoldable
          $ Set.fromFoldable
          $ concatMap (\(Tuple left right) -> [ left, right ]) edgelist
    fns <- for nodes \node -> do
      analyzeFunction node
      rmap (Tuple node) <$> retrieveFunctionData
    functions <- rethrow $ sequence fns
    (DataflowGraph flowgraph) <- rethrow =<< readDataflowGraph
    let labels = Map.fromFoldable <<< map (\(name /\ fn) -> name /\ (toLabel fn)) $ functions
    let normalizedNodesMap = toNominal nodes
    let nodeLabels = map snd $ sortWith fst $ mapMaybe (\(name /\ fn) -> flip Tuple fn <$> Map.lookup name normalizedNodesMap) $ Map.toUnfoldable labels
    let edgeList = map (\(Tuple left right) -> mapMaybe (\name -> Map.lookup name normalizedNodesMap) [ left, right ]) edgelist
    pure
      { callgraph:
          { edgelist: edgeList
          , nodeLabels: map labelToVec nodeLabels
          }
      , flowgraph:
          { edgelist: flowgraph.edges
          , nodeLabels: flowgraph.nodes
          }
      }

  writeOutput outputFile output

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


