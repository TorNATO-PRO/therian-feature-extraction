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

module Therian.Process.Label
  ( labelToVec
  , toLabel
  )
  where

import Prelude

import Data.Array (filter, length)
import Data.String (Pattern(..))
import Data.String as String
import Therian.Data.Function (R2Function)
import Therian.Data.Label (Label)

toLabel :: R2Function -> Label
toLabel fn =
  { totalInstructions: fn.ninstr
  , localVariables: fn.nlocals
  , arguments: fn.nargs
  , movInstructions: movInstructions
  , popInstructions: popInstructions
  , callInstructions: callInstructions
  }
  where
    opcodes = fn.blocks >>= \block -> block.ops >>= \op -> [op.opcode]
    movInstructions = count isMovInstruction opcodes
    popInstructions = count isPopInstruction opcodes
    callInstructions = count isCallInstruction opcodes

count :: forall a. (a -> Boolean) -> Array a -> Int
count fn = length <<< filter fn

isMovInstruction :: String -> Boolean
isMovInstruction = String.contains (Pattern "mov")

isPopInstruction :: String -> Boolean
isPopInstruction = String.contains (Pattern "pop")

isCallInstruction :: String -> Boolean
isCallInstruction = String.contains (Pattern "call")

labelToVec :: Label -> Array Int
labelToVec label =
  [ label.totalInstructions
  , label.localVariables
  , label.arguments
  , label.movInstructions
  , label.popInstructions
  , label.callInstructions
  ]
