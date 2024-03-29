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

module Therian.Data.GlobalCallgraph where

import Prelude

import Data.Argonaut (class DecodeJson, class EncodeJson, decodeJson, (.:), (.:?))
import Data.Maybe (fromMaybe)
import Data.Tuple (Tuple)

----------------------------------------------------

type FnIdentifier = String

newtype CallgraphNode = CallgraphNode
  { name :: FnIdentifier
  , size :: Int
  , imports :: Array FnIdentifier
  }

derive newtype instance Eq CallgraphNode

derive newtype instance Ord CallgraphNode

derive newtype instance Show CallgraphNode

derive newtype instance EncodeJson CallgraphNode

instance DecodeJson CallgraphNode where
  decodeJson json = do
    obj <- decodeJson json
    name <- obj .: "name"
    size <- obj .: "size"
    imports <- obj .:? "imports"
    pure $ CallgraphNode
      { name
      , size
      , imports: fromMaybe [] imports
      }

----------------------------------------------------

newtype GlobalCallgraph = GlobalCallgraph
  { edgelist :: Array (Tuple FnIdentifier FnIdentifier)
  }

derive newtype instance Eq GlobalCallgraph

derive newtype instance Ord GlobalCallgraph

derive newtype instance Show GlobalCallgraph

----------------------------------------------------