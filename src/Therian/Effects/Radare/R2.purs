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
  ( RADARE_ANALYZE
  , RADARE_EFFECTS
  , RADARE_WRITE_GRAPH_TO_FILE
  , RUN_RADARE_ON_FILE
  , RadareAnalyzeF(..)
  , RadareWriteGraphToFileF(..)
  , RunRadareOnFileF(..)
  , _runRadareOnFile
  , handleRunRadareOnFile
  , radareAnalyze
  , radareWriteGraphToFile
  , runRadareOnFile
  )
  where

import Prelude

import Control.Promise (Promise, toAffE)
import Effect (Effect)
import Node.Path (FilePath)
import Run (AFF, Run, interpretRec)
import Run as Run
import Type.Proxy (Proxy(..))
import Type.Row (type (+))

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

-- Radare Write Graph to File

foreign import jsRadareWriteGraphToFile :: R2 -> FilePath -> Effect (Promise Unit)

data RadareWriteGraphToFileF a = RadareWriteGraphToFile FilePath a

derive instance Functor RadareWriteGraphToFileF

type RADARE_WRITE_GRAPH_TO_FILE r = (radareWriteGraphToFile :: RadareWriteGraphToFileF | r)

_radareWriteGraphToFile = Proxy :: Proxy "radareWriteGraphToFile"

radareWriteGraphToFile :: forall r. FilePath -> Run (RADARE_WRITE_GRAPH_TO_FILE + r) Unit
radareWriteGraphToFile filepath = Run.lift _radareWriteGraphToFile (RadareWriteGraphToFile filepath unit)

-- Radare Write Graph To File Interpreter

handleRadareWriteGraphToFile :: forall r. R2 -> RadareWriteGraphToFileF ~> Run (AFF + r)
handleRadareWriteGraphToFile r2 (RadareWriteGraphToFile filepath cb) = cb <$ (Run.liftAff $ toAffE $ jsRadareWriteGraphToFile r2 filepath)

----------------------------------------------------------

foreign import jsRadareClose :: R2 -> Effect (Promise Unit)

---------------------------------------------------------

type RADARE_EFFECTS
  = RADARE_ANALYZE
  + RADARE_WRITE_GRAPH_TO_FILE
  + ()

data RunRadareOnFileF a = RunRadareOnFile FilePath (Run RADARE_EFFECTS Unit) a

derive instance Functor RunRadareOnFileF

type RUN_RADARE_ON_FILE r = (runRadareOnFile :: RunRadareOnFileF | r)

_runRadareOnFile = Proxy :: Proxy "runRadareOnFile"

runRadareOnFile :: forall r. FilePath -> Run RADARE_EFFECTS Unit -> Run (RUN_RADARE_ON_FILE + r) Unit
runRadareOnFile filepath effects = Run.lift _runRadareOnFile (RunRadareOnFile filepath effects unit)


handleRunRadareOnFile :: forall r. RunRadareOnFileF ~> Run (AFF + r)
handleRunRadareOnFile (RunRadareOnFile filepath effects cb) = cb <$ do
  r2 <- Run.liftAff $ toAffE $ jsRadareOpenFile filepath
  interpretRadareEffs r2 effects
  Run.liftAff $ toAffE $ jsRadareClose r2
  where
  interpretRadareEffs r2 = interpretRec
    ( Run.case_
        # Run.on _radareAnalyze (handleRadareAnalyze r2)
        # Run.on _radareWriteGraphToFile (handleRadareWriteGraphToFile r2)
    )
