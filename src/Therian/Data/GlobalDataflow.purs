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

module Therian.Data.GlobalDataflow
  ( DataflowGraph(..)
  , Node
  , R2DataflowGraph
  , toDataflowGraph
  )
  where

import Prelude

import Data.Argonaut (class DecodeJson, class EncodeJson)
import Data.Array (concatMap, nubBy, sortWith)

--------------------------------------------------------

type Node =
  { id :: Int
  , title :: String
  , "out_nodes" :: Array Int
  }

type R2DataflowGraph =
  { nodes :: Array Node
  }

--------------------------------------------------------

newtype DataflowGraph = DataflowGraph
  { nodes :: Array Int
  , edges :: Array (Array Int)
  }

derive newtype instance Eq DataflowGraph

derive newtype instance Ord DataflowGraph

derive newtype instance Show DataflowGraph

derive newtype instance EncodeJson DataflowGraph

derive newtype instance DecodeJson DataflowGraph

--------------------------------------------------------

toDataflowGraph :: R2DataflowGraph -> DataflowGraph
toDataflowGraph { nodes } =
  let
    -- remove duplicates (if any)
    filteredNodes = (nubWith _.id <<< sortWith _.id) nodes

    -- create edge list
    edgeList = concatMap (\{ id, out_nodes } -> map (\outNode -> [ id, outNode ]) out_nodes) filteredNodes
  in
    DataflowGraph
      { nodes: map _.id filteredNodes
      , edges: edgeList
      }

nubWith :: forall a b. Ord b => (a -> b) -> Array a -> Array a
nubWith fn = nubBy (\a b -> compare (fn a) (fn b))