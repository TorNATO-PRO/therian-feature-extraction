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

module Therian.Effects.Log.Log where

import Prelude

import Effect.Class.Console as Console
import Run (Run, EFFECT)
import Run as Run
import Type.Proxy (Proxy(..))
import Type.Row (type (+))

----------------------------------------------------------

-- Log Effect

data LogF a = Log String a

derive instance Functor LogF

type LOG r = (log :: LogF | r)

_log = Proxy :: Proxy "log"

log :: forall r. String -> Run (LOG + r) Unit
log str = Run.lift _log (Log str unit)

-- Log Interpreter

handleLog :: forall r. LogF ~> Run (EFFECT + r)
handleLog (Log str cb) = Console.log str $> cb

-----------------------------------------------------------