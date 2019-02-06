{-# LANGUAGE ScopedTypeVariables #-}

module Data.Graph.GSeekSeq where

import           Data.Maybe
import           Data.Map (Map)
import qualified Data.Map       as M
import           Data.Set (Set)
import qualified Data.Set       as S

import SeekSeq.Query.MkLeaf
import Data.Graph
import SeekSeq.Types
import Util


-- | == for building `Query`s

findChildren, findParents :: (Ord e, Show e)
                          => Either e Var -> Find e (Graph e)
findChildren = findFrom "findChildren"
  $ \g e -> Right $ children g e
findParents  = findFrom "findParents"
  $ \g e -> Right $ parents g e