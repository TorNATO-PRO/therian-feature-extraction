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

module Therian.Effects.Radare.R2
  ( ANALYZE_FUNCTION
  , AnalyzeFunctionF
  , RADARE_ANALYZE
  , RADARE_EFFECTS
  , READ_FUNCTION_CALLGRAPH
  , RETRIEVE_FUNCTION_DATA
  , RUN_RADARE_ON_FILE
  , RadareAnalyzeF
  , ReadFunctionCallgraphF
  , RetrieveFunctionDataF
  , RunRadareOnFileF
  , _runRadareOnFile
  , analyzeFunction
  -- , handleRunRadareOnFile
  , radareAnalyze
  , readFunctionCallgraph
  , retrieveFunctionData
  , runRadareOnFile
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Data.Argonaut (decodeJson, printJsonDecodeError)
import Data.Argonaut as Argonaut
import Data.Array.NonEmpty (head)
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Exists (Exists, mkExists, runExists)
import Data.Tuple (Tuple(..))
import Effect (Effect)
import Node.Path (FilePath)
import Run (AFF, Run, EFFECT, interpretRec)
import Run as Run
import Run.Except (EXCEPT, _except, runExcept)
import Therian.Data.Function (R2Function)
import Therian.Data.GlobalCallgraph (CallgraphNode(..), GlobalCallgraph(..))
import Therian.Effects.Log.Log (LOG, _log, handleLog)
import Type.Proxy (Proxy(..))
import Type.Row (type (+))

-- This could be a lot better if I had more time

foreign import data R2 :: Type

----------------------------------------------------------

foreign import jsRadareOpenFile :: String -> Effect (Promise R2)

----------------------------------------------------------

-- Radare Analyze File

foreign import jsRadareAnalyze :: R2 -> Effect (Promise Unit)

data RadareAnalyzeF a = RadareAnalyze a

derive instance Functor RadareAnalyzeF

type RADARE_ANALYZE r = (radareAnalyze :: RadareAnalyzeF | r)

_radareAnalyze = Proxy :: Proxy "radareAnalyze"

radareAnalyze :: forall r. Run (RADARE_ANALYZE + r) Unit
radareAnalyze = Run.lift _radareAnalyze (RadareAnalyze unit)

-- Radare Analyze File Interpreter

handleRadareAnalyze :: forall r. R2 -> RadareAnalyzeF ~> Run (AFF + r)
handleRadareAnalyze r2 (RadareAnalyze cb) = cb <$ (Run.liftAff $ toAffE $ jsRadareAnalyze r2)

----------------------------------------------------------

-- Analyze Function effect

foreign import jsRadareAnalyzeFunction :: R2 -> String -> Effect (Promise Unit)

data AnalyzeFunctionF a = AnalyzeFunction String a

derive instance Functor AnalyzeFunctionF

type ANALYZE_FUNCTION r = (analyzeFunction :: AnalyzeFunctionF | r)

_analyzeFunction = Proxy :: Proxy "analyzeFunction"

analyzeFunction :: forall r. String -> Run (ANALYZE_FUNCTION + r) Unit
analyzeFunction ident = Run.lift _analyzeFunction (AnalyzeFunction ident unit)

-- Analyze Function Interpreter

handleAnalyzeFunction :: forall r. R2 -> AnalyzeFunctionF ~> Run (AFF + r)
handleAnalyzeFunction r2 (AnalyzeFunction ident cb) = cb <$ (Run.liftAff $ toAffE $ jsRadareAnalyzeFunction r2 ident)

----------------------------------------------------------

-- Retrieve function data effect

foreign import jsRadareRetrieveFunctionData :: R2 -> Effect (Promise String)

data RetrieveFunctionDataF a = RetrieveFunctionData (Either String R2Function -> a)

derive instance Functor RetrieveFunctionDataF

type RETRIEVE_FUNCTION_DATA r = (retrieveFunctionData :: RetrieveFunctionDataF | r)

_retrieveFunctionData = Proxy :: Proxy "retrieveFunctionData"

retrieveFunctionData :: forall r. Run (RETRIEVE_FUNCTION_DATA + r) (Either String R2Function)
retrieveFunctionData = Run.lift _retrieveFunctionData (RetrieveFunctionData identity)

-- Retrieve function data interpreter

handleRetrieveFunctionData :: forall r. R2 -> RetrieveFunctionDataF ~> Run (AFF + r)
handleRetrieveFunctionData r2 (RetrieveFunctionData cb) = cb <$> do
  functionData <- Run.liftAff $ toAffE $ jsRadareRetrieveFunctionData r2
  case ((lmap printJsonDecodeError <<< decodeJson) =<< Argonaut.jsonParser functionData) of
    Left err -> pure $ Left err
    Right fnData -> pure $ Right $ head fnData

----------------------------------------------------------

-- Radare Write Graph to File

foreign import jsReadFunctionCallGraph :: R2 -> Effect (Promise String)

data ReadFunctionCallgraphF a = ReadFunctionCallgraph (Either String GlobalCallgraph -> a)

derive instance Functor ReadFunctionCallgraphF

type READ_FUNCTION_CALLGRAPH r = (readFunctionCallgraph :: ReadFunctionCallgraphF | r)

_readFunctionCallgraph = Proxy :: Proxy "readFunctionCallgraph"

readFunctionCallgraph :: forall r. Run (READ_FUNCTION_CALLGRAPH + r) (Either String GlobalCallgraph)
readFunctionCallgraph = Run.lift _readFunctionCallgraph (ReadFunctionCallgraph identity)

-- Radare Write Graph To File Interpreter

handleReadFunctionCallgraph :: forall r. R2 -> ReadFunctionCallgraphF ~> Run (AFF + EFFECT + r)
handleReadFunctionCallgraph r2 (ReadFunctionCallgraph cb) = cb <$> do
  callgraphString <- Run.liftAff $ toAffE $ jsReadFunctionCallGraph r2
  case ((lmap printJsonDecodeError <<< decodeJson) =<< Argonaut.jsonParser callgraphString) of
    Left err -> pure $ Left err
    Right nodes ->
      pure $ Right $ GlobalCallgraph
        { edgelist: nodes >>= (\(CallgraphNode node) -> node.imports >>= \imp -> pure (Tuple node.name imp))
        }

----------------------------------------------------------

foreign import jsRadareClose :: R2 -> Effect (Promise Unit)

---------------------------------------------------------

type RADARE_EFFECTS r = RADARE_ANALYZE
  + READ_FUNCTION_CALLGRAPH
  + RETRIEVE_FUNCTION_DATA
  + ANALYZE_FUNCTION
  + LOG
  + r

data RunRadareOnFileF'' a out err = RunRadareOnFile'' FilePath (Run (RADARE_EFFECTS + EXCEPT err + ()) out) (Either err out -> a)

data RunRadareOnFileF' a out = RunRadareOnFile' (Exists (RunRadareOnFileF'' a out))

data RunRadareOnFileF a = RunRadareOnFile (Exists (RunRadareOnFileF' a))

-- that was a bit of a mind bender with existentials, there will be a quiz

instance Functor RunRadareOnFileF where
  map fn (RunRadareOnFile ex) = runExists
    ( \(RunRadareOnFile' ex1) -> runExists
        ( \(RunRadareOnFile'' filepath effs cb) ->
            RunRadareOnFile $ mkExists $ RunRadareOnFile' $ mkExists $ RunRadareOnFile'' filepath effs (fn <$> cb)
        )
        ex1
    )
    ex

type RUN_RADARE_ON_FILE r = (runRadareOnFile :: RunRadareOnFileF | r)

_runRadareOnFile = Proxy :: Proxy "runRadareOnFile"

runRadareOnFile :: forall out err r. FilePath -> Run (RADARE_EFFECTS + EXCEPT err + ()) out -> Run (RUN_RADARE_ON_FILE + r) (Either err out)
runRadareOnFile filepath effects = Run.lift _runRadareOnFile
  (RunRadareOnFile $ mkExists $ RunRadareOnFile' $ mkExists $ (RunRadareOnFile'' filepath effects identity))

handleRunRadareOnFile :: forall r. RunRadareOnFileF ~> Run (AFF + EFFECT + r)
handleRunRadareOnFile (RunRadareOnFile ex) = runExists
  ( \(RunRadareOnFile' ex1) -> runExists
      ( \(RunRadareOnFile'' filepath effects cb) -> cb <$> do
          r2 <- Run.liftAff $ toAffE $ jsRadareOpenFile filepath
          res <- runExcept $ interpretRadareEffs r2 effects
          Run.liftAff $ toAffE $ jsRadareClose r2
          pure res
      )
      ex1
  )
  ex
  where
  interpretRadareEffs r2 = interpretRec
    ( Run.case_
        # Run.on _radareAnalyze (handleRadareAnalyze r2)
        # Run.on _readFunctionCallgraph (handleReadFunctionCallgraph r2)
        # Run.on _log handleLog
        # Run.on _analyzeFunction (handleAnalyzeFunction r2)
        # Run.on _retrieveFunctionData (handleRetrieveFunctionData r2)
        # Run.on _except (Run.lift _except)
    )
