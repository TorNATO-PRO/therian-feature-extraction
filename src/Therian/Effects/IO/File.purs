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

module Therian.Effects.IO.File where

import Prelude

import Data.Argonaut (encodeJson, stringifyWithIndent)
import Node.Encoding (Encoding(..))
import Node.FS.Aff (writeTextFile)
import Node.Path (FilePath)
import Run (Run, AFF)
import Run as Run
import Therian.Data.Output (Output)
import Type.Proxy (Proxy(..))
import Type.Row (type (+))

-----------------------------------------------------------

-- Write output effect

data WriteOutputF a = WriteOutput FilePath Output a

derive instance Functor WriteOutputF

type WRITE_OUTPUT r = (writeOutput :: WriteOutputF | r)

_writeOutput = Proxy :: Proxy "writeOutput"

writeOutput :: forall r. FilePath -> Output -> Run (WRITE_OUTPUT + r) Unit
writeOutput filepath output = Run.lift _writeOutput (WriteOutput filepath output unit)

handleWriteOutput :: forall r. WriteOutputF ~> Run (AFF + r)
handleWriteOutput (WriteOutput filepath output cb) = cb <$ (Run.liftAff $ writeTextFile UTF8 filepath (stringifyWithIndent 2 $ encodeJson output))

-----------------------------------------------------------