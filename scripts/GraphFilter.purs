module Main where

import Prelude

import Control.Parallel (parTraverse)
import Data.Argonaut (class EncodeJson, encodeJson, stringifyWithIndent)
import Data.Array (drop, filter, fold, index)
import Data.Array.NonEmpty (NonEmptyArray, fromNonEmpty)
import Data.Bifunctor (lmap)
import Data.NonEmpty (NonEmpty(..))
import Data.String.Regex (Regex, split)
import Data.String.Regex.Flags (noFlags)
import Data.String.Regex.Unsafe (unsafeRegex)
import Data.Traversable (traverse)
import Data.Tuple (Tuple(..), fst)
import Effect (Effect)
import Effect.Aff (Aff, launchAff_)
import Effect.Class.Console as Console
import Node.Encoding (Encoding(..))
import Node.FS.Aff (readTextFile, readdir, stat, writeTextFile)
import Node.FS.Stats (Stats, isDirectory, isFile)
import Node.Path (FilePath)
import Options.Applicative (execParser, fullDesc, header, help, helper, info, int, long, option, progDesc, short, strOption)
import Options.Applicative as OptParse
import Options.Applicative.Internal.Utils ((<**>))
import Parsing (Parser, parseErrorMessage, runParser)
import Parsing.Combinators ((<?>))
import Parsing.String (rest, string)
import Parsing.String.Basic (intDecimal, skipSpaces)
import Run (AFF, EFFECT, Run, interpretRec, runBaseAff')
import Run as Run
import Run.Except (EXCEPT, catch, note, rethrow)
import Type.Proxy (Proxy(..))
import Type.Row (type (+))

----------------------------------------------------------

newtype Graph = Graph
  { edgeList :: Array (NonEmptyArray Int)
  , nodes :: Int
  , edges :: Int
  , hash :: String
  }

instance EncodeJson Graph where
  encodeJson (Graph graph) = encodeJson graph

derive newtype instance Show Graph

----------------------------------------------------------

data Arguments = Arguments
  { inputDirectory :: FilePath
  , numNodes :: Int
  , outputDirectory :: FilePath
  }

argumentParser :: OptParse.Parser Arguments
argumentParser = ado
  inputDirectory <- strOption $ fold
    [ long "inputDirectory"
    , short 'i'
    , help "Target for the input directory parsing"
    ]

  numNodes <- option int $ fold
    [ long "numNodes"
    , short 'n'
    , help "The maximum number of nodes to keep"
    ]

  outputDirectory <- strOption $ fold
    [ long "outputDirectory"
    , short 'o'
    , help "Target for the filtered graphs"
    ]

  in Arguments
    { inputDirectory
    , numNodes
    , outputDirectory
    }

----------------------------------------------------------

-- Effects

type ProgramEffects
  = LOG
  + FILE_STAT
  + WRITE_GRAPH
  + READ_FILE
  + READ_DIR
  + EXCEPT String
  + ()

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

-- Write Graph Effect

data WriteGraphF a = WriteGraph FilePath Graph a

derive instance Functor WriteGraphF

type WRITE_GRAPH r = (writeGraph :: WriteGraphF | r)

_writeGraph = Proxy :: Proxy "writeGraph"

writeGraph :: forall r. FilePath -> Graph -> Run (WRITE_GRAPH + r) Unit
writeGraph filePath graph = Run.lift _writeGraph (WriteGraph filePath graph unit)

-- Write Graph Interpreter

handleWriteGraph :: forall r. WriteGraphF ~> Run (AFF + r)
handleWriteGraph (WriteGraph filePath graph cb) = cb <$ (Run.liftAff $ writeTextFile UTF8 filePath (stringifyWithIndent 2 $ encodeJson graph))

-----------------------------------------------------------

-- Read File Effect

data ReadFileF a = ReadFile FilePath (String -> a)

derive instance Functor ReadFileF

type READ_FILE r = (readFile :: ReadFileF | r)

_readFile = Proxy :: Proxy "readFile"

readFile :: forall r. FilePath -> Run (READ_FILE + r) String
readFile filePath = Run.lift _readFile (ReadFile filePath identity)

-- Read File Interpreter

handleReadFile :: forall r. ReadFileF ~> Run (AFF + r)
handleReadFile (ReadFile filePath cb) = do
  contents <- Run.liftAff $ readTextFile UTF8 filePath
  pure $ cb contents

-----------------------------------------------------------

-- File Stat Effect

data FileStatF a = FileStat FilePath (Stats -> a)

derive instance Functor FileStatF

type FILE_STAT r = (fileStat :: FileStatF | r)

_fileStat = Proxy :: Proxy "fileStat"

fileStat :: forall r. FilePath -> Run (FILE_STAT + r) Stats
fileStat filePath = Run.lift _fileStat (FileStat filePath identity)

-- File Stat interpreter

handleFileStat :: forall r. FileStatF ~> Run (AFF + r)
handleFileStat (FileStat filePath cb) = cb <$> (Run.liftAff $ stat filePath)

-----------------------------------------------------------

-- Read Dir Effect

data ReadDirF a = ReadDir FilePath (Array FilePath -> a)

derive instance Functor ReadDirF

type READ_DIR r = (readDir :: ReadDirF | r)

_readDir = Proxy :: Proxy "readDir"

readDir :: forall r. FilePath -> Run (READ_DIR + r) (Array FilePath)
readDir filePath = Run.lift _readDir (ReadDir filePath identity)

-- Read Dir interpreter

handleReadDir :: forall r. ReadDirF ~> Run (AFF + r)
handleReadDir (ReadDir filePath cb) = cb <$> (Run.liftAff $ readdir filePath)

-----------------------------------------------------------

edge :: Parser String (NonEmptyArray Int)
edge = do
  left <- intDecimal <?> "Failed to parse the left node"
  skipSpaces
  right <- intDecimal <?> "Failed to parse the right node"
  pure $ fromNonEmpty (NonEmpty left [right])

shahash :: Parser String String
shahash = do
  _ <- string "# SHA-256:" <?> "Failed to find # SHA-256: at start of string"
  skipSpaces
  rest

nodesAndEdges :: Parser String (Tuple Int Int)
nodesAndEdges = do
  _ <- string "# Nodes:" <?> "Failed to find # Nodes: at start of string"
  skipSpaces
  nodes <- intDecimal
  _ <- string "," <?> "Failed to find comma separator"
  skipSpaces
  _ <- string "Edges:" <?> "Failed to find Edges: within string"
  skipSpaces
  edges <- intDecimal
  pure (Tuple nodes edges)

newlineRegex :: Regex
newlineRegex = unsafeRegex "\r\n|\n" noFlags

readGraph :: forall r. String -> Run (EXCEPT String + r) Graph
readGraph fileContents = let
  lines = split newlineRegex fileContents
  in do
  hashString <- note "Failed to read hash string" $ index lines 2
  nodesAndEdgesString <- note "Failed to read nodes and edges string" $ index lines 3
  let rest = filter ((/=) "") $ drop 5 lines
  hash <- rethrow $ lmap parseErrorMessage $ runParser hashString shahash
  (Tuple nodes edges) <- rethrow $ lmap parseErrorMessage $ runParser nodesAndEdgesString nodesAndEdges
  edgeList <- rethrow $ lmap parseErrorMessage $ traverse (flip runParser edge) rest
  pure $ Graph
    { edgeList
    , nodes
    , edges
    , hash
    }

effectInterpreter :: Run ProgramEffects Unit -> Aff Unit
effectInterpreter = runBaseAff' <<< void <<< interpretRec
  ( Run.case_
      # Run.on _log handleLog
      # Run.on _readFile handleReadFile
      # Run.on _writeGraph handleWriteGraph
      # Run.on _readDir handleReadDir
      # Run.on _fileStat handleFileStat
  ) <<< catch log

program :: Arguments -> Aff Unit
program (Arguments { inputDirectory, outputDirectory, numNodes })= do
  traverseFiles inputDirectory $ \file -> do
    fileContents <- readFile file
    graph@(Graph { nodes, hash }) <- readGraph fileContents
    if nodes <= numNodes then
      writeGraph (fold [outputDirectory, "/", hash, ".json"]) graph
    else
      pure unit
  where
  traverseFiles :: FilePath -> (FilePath -> Run ProgramEffects Unit) -> Aff Unit
  traverseFiles filePath cb = do
    fileStats <- stat filePath
    if isFile fileStats then
      effectInterpreter $ cb filePath
    else if isDirectory fileStats then do
      dirFiles <- readdir filePath
      filesStats <- traverse readFileStats $ map (\file -> fold [filePath, "/", file]) dirFiles
      void $ parTraverse (\file -> traverseFiles file cb) $ map fst $ filter (\(Tuple _ stats) -> isFileOrDirectory stats) filesStats
    else
      pure unit
    where
    readFileStats path = Tuple path <$> (stat path)

    isFileOrDirectory :: Stats -> Boolean
    isFileOrDirectory stats = isFile stats || isDirectory stats

-----------------------------------------------------------

main :: Effect Unit
main = do
  args <- execParser opts
  launchAff_ $ program args
  where
    opts = info (argumentParser <**> helper)
      ( fullDesc
      <> progDesc "Filter out the graphs by number of nodes"
      <> header "Graph Filterer"
      )
