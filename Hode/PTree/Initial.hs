{-# OPTIONS_GHC -fno-warn-orphans #-}

{-# LANGUAGE DeriveFunctor, DeriveFoldable, DeriveTraversable
, ScopedTypeVariables
, TemplateHaskell
, TypeFamilies
, ViewPatterns #-}

module Hode.PTree.Initial where

import           Control.Arrow ((>>>))
import           Control.Lens
import           Data.Foldable (toList)
import           Data.List.PointedList (PointedList)
import qualified Data.List.PointedList as P
import           Data.Maybe
import           Data.Functor.Foldable.TH


data Direction = DirPrev | DirNext | DirUp | DirDown
  deriving (Show,Eq, Ord)


-- | == `PointedList`

instance Ord a => Ord (PointedList a) where
  compare pl ql = compare (toList pl) (toList ql)

prevIfPossible, nextIfPossible :: PointedList a -> PointedList a
prevIfPossible l = maybe l id $ P.previous l
nextIfPossible l = maybe l id $ P.next     l

getPList :: Getter (PointedList a) [a]
getPList = to toList

setPList :: Setter' (PointedList a) [a]
setPList = sets go where
  go :: ([a] -> [a]) -> PointedList a -> PointedList a
  go f pl = case f $ toList pl of
              [] -> pl
              x -> maybe (error msg) id $ P.fromList x
    where msg = "setList: Impossible: x is non-null, so P.fromList works"


-- | == `PTree`, a tree made of `PointedList`s

data PTree a = PTree {
    _pTreeLabel :: a
  , _pTreeHasFocus :: Bool -- ^ PITFALL: permits invalid state.
  -- There should be only one focused node in the tree.
  , _pMTrees :: Maybe (Porest a) }
  deriving (Eq, Show, Ord, Functor, Foldable, Traversable)
type Porest a = PointedList (PTree a)
  -- ^ PITFALL: Folding over a Porest is a little confusing.
  -- See Hode.Test.TPTree.

-- | = Lenses

makeLenses      ''PTree
makeBaseFunctor ''PTree
makeLenses      ''PTreeF

-- TODO : These lenses are inefficient, because they convert a `PointedList`
-- to a normal list in order to find the focused element. If a subtree
-- has focus, its parent should be focused on it. And note that
-- there is already a nice `Functor` instance for `PointedList`.

getFocusedChild :: Getter (PTree a) (Maybe (PTree a))
getFocusedChild = to go where
  go :: PTree a -> Maybe (PTree a)
  go (_pTreeHasFocus -> True) = Nothing
  go t = case _pMTrees t of
    Nothing -> Nothing
    Just ts -> listToMaybe $ filter _pTreeHasFocus $ toList ts

getParentOfFocusedSubtree :: Getter (PTree a) (Maybe (PTree a))
getParentOfFocusedSubtree = to go where
  go :: PTree a -> Maybe (PTree a)
  go t = if t ^. pTreeHasFocus            then Nothing
    else if isJust $ t ^. getFocusedChild then Just t
    else case t ^. pMTrees of
           Nothing -> Nothing
           Just ts -> go $ ts ^. P.focus

setParentOfFocusedSubtree :: Setter' (PTree a) (PTree a)
setParentOfFocusedSubtree = sets go where
  go :: (PTree a -> PTree a) -> PTree a -> PTree a
  go f t = if t ^. pTreeHasFocus          then t
    else if isJust $ t ^. getFocusedChild then f t else
    case t ^. pMTrees of
      Nothing -> t
      Just _ -> t & pMTrees . _Just . P.focus %~ go f

-- | If the `PTree` has (it sohuldn't) more than one subtree for which
-- `pTreeHasFocus` is true, this returns the first such.
getFocusedSubtree :: Getter (PTree a) (Maybe (PTree a))
getFocusedSubtree = to go where
  go :: PTree a -> Maybe (PTree a)
  go t@(_pTreeHasFocus -> True) = Just t
  go t = case _pMTrees t of
    Nothing -> Nothing
    Just ts -> go $ ts ^. P.focus

-- | Change something about the focused subtree.
setFocusedSubtree :: Setter' (PTree a) (PTree a)
setFocusedSubtree = sets go where
  go :: forall a. (PTree a -> PTree a) -> PTree a -> PTree a
  go f t@(_pTreeHasFocus -> True) = f t
  go f t = case _pMTrees t of
    Nothing -> t
    Just _ -> t & pMTrees . _Just . P.focus %~ go f


-- | = Creators

pTrees :: Traversal' (PTree a) (Porest a)
pTrees = pMTrees . _Just

pTreeLeaf :: a -> PTree a
pTreeLeaf a = PTree { _pTreeLabel = a
                    , _pTreeHasFocus = False
                    , _pMTrees = Nothing }

porestLeaf :: a -> Porest a
porestLeaf = P.singleton . pTreeLeaf


-- | = Modifiers

-- | The root has level 0, its children level 1, etc.
writeLevels :: PTree a -> PTree (Int,a)
writeLevels = f 0 where
  f :: Int -> PTree a -> PTree (Int, a)
  f i pt = pt
    { _pTreeLabel = (i, _pTreeLabel pt)
    , _pMTrees = fmap (fmap $ f $ i+1) $ _pMTrees pt }
      -- The outer fmap gets into the Maybe,
      -- and the inner gets into the PointedList.

cons_topNext :: a -> Porest a -> Porest a
cons_topNext a =
  P.focus . pTreeHasFocus .~ False >>>
  P.insertRight (pTreeLeaf a)      >>>
  P.focus . pTreeHasFocus .~ True

-- | Inserts `newFocus` under `oldFocus`, and focuses on the newcomer.
consUnder_andFocus :: forall a. PTree a -> PTree a -> PTree a
consUnder_andFocus newFocus oldFocus =
  let (ts'' :: [PTree a]) =
        let m = newFocus & pTreeHasFocus .~ True
        in case _pMTrees oldFocus of
             Nothing -> m : []
             Just ts ->
               let ts' = ts & P.focus . pTreeHasFocus .~ False
               in m : toList ts'
  in oldFocus & pTreeHasFocus .~ False
              & pMTrees .~ P.fromList ts''

moveFocusInPTree :: Direction -> PTree a -> PTree a
moveFocusInPTree DirUp t =
  case t ^? getParentOfFocusedSubtree . _Just of
    Nothing -> t & pTreeHasFocus .~ True
    Just st -> let
      st' = st & pMTrees . _Just . P.focus . pTreeHasFocus .~ False
               &                             pTreeHasFocus .~ True
      in t & setParentOfFocusedSubtree .~ st'

moveFocusInPTree DirDown t =
  case t ^? getFocusedSubtree . _Just . pMTrees . _Just
  of Nothing -> t
     Just ts -> let ts' = ts & P.focus . pTreeHasFocus .~ True
                in t & setFocusedSubtree . pMTrees .~ Just ts'
                     & setFocusedSubtree . pTreeHasFocus .~ False

moveFocusInPTree DirPrev t =
  case t ^? getParentOfFocusedSubtree . _Just . pMTrees . _Just
  of Nothing -> t -- happens at the top of the tree
     Just ts -> let ts' = ts & P.focus . pTreeHasFocus .~ False
                             & prevIfPossible
                             & P.focus . pTreeHasFocus .~ True
       in t & setParentOfFocusedSubtree . pMTrees .~ Just ts'

moveFocusInPTree DirNext t =
  case t ^? getParentOfFocusedSubtree . _Just . pMTrees . _Just
  of Nothing -> t -- happens at the top of the tree
     Just ts -> let ts' = ts & P.focus . pTreeHasFocus .~ False
                             & nextIfPossible
                             & P.focus . pTreeHasFocus .~ True
       in t & setParentOfFocusedSubtree . pMTrees .~ Just ts'

moveFocusInPorest :: Direction -> Porest a -> Porest a
moveFocusInPorest d as =
  case as ^. P.focus . pTreeHasFocus
  of False -> as & P.focus %~ moveFocusInPTree d
     True -> case d of
       DirUp   -> as & P.focus %~ moveFocusInPTree d
       DirDown -> as & P.focus %~ moveFocusInPTree d
       DirNext -> as & P.focus . pTreeHasFocus .~ False
                     & nextIfPossible
                     & P.focus . pTreeHasFocus .~ True
       DirPrev -> as & P.focus . pTreeHasFocus .~ False
                     & prevIfPossible
                     & P.focus . pTreeHasFocus .~ True