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

module Therian.Data.Function where


-- Sample function
-- {
    -- "name": "0x0002b790",
    -- "offset": 64976,
    -- "ninstr": 13,
    -- "nargs": 1,
    -- "nlocals": 0,
    -- "size": 38,
    -- "stack": 8,
    -- "type": "fcn",
    -- "blocks": []
-- }

type R2Function =
  { name :: String
  , ninstr :: Int
  , nargs :: Int
  , nlocals :: Int
  , size :: Int
  , stack :: Int -- not sure what this is
  , blocks :: Array Block
  }

type Block =
  { offset :: Int
  , size :: Int
  , ops :: Array Op
  }


-- Hard to type opcodes if we allow arbitrary
-- instruction sets. Additional information can be extracted
-- as well. For some reason both opcode and family are nullable too...

-- Sample Op

--  {
--    "offset": 64986,
--    "esil": "rsp,rdx,=",
--   "refptr": 0,
--    "fcn_addr": 64976,
--    "fcn_last": 65011,
--    "size": 3,
--    "opcode": "mov rdx, rsp",
--    "disasm": "mov rdx, rsp",
--    "bytes": "4889e2",
--    "family": "cpu",
--    "type": "mov",
--    "reloc": false,
--    "type_num": 9,
--    "type2_num": 0
-- }


type Op =
  { opcode :: String
  , family :: String
  }
