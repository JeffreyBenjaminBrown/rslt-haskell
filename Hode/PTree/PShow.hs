{-# LANGUAGE ScopedTypeVariables #-}

module Hode.PTree.PShow where

import           Control.Lens
import           Data.Foldable (toList)
import qualified Data.Map as M
import qualified Data.List.PointedList as P

import qualified Brick.Types          as B
import           Brick.Widgets.Core

import Hode.Brick
import Hode.PTree.Initial


-- | To show `String`s, set `b2w = Brick.Widgets.Core.strWrap`.
-- To show `ColorString`s, use `b2s = Hode.Brick.colorStringWrap`
porestToWidget :: forall a b n.
     (b -> B.Widget n)
  -> (a -> b)      -- ^ shows the columns corresponding to each node
  -> (a -> b)      -- ^ shows the nodes that will be arranged like a tree
  -> (a -> Bool) -- ^ whether to hide a node's children
  -> (PTree a -> B.Widget n -> B.Widget n)
     -- ^ to show the focused node differently
     -- (it could be used for other stuff too)
  -> Porest a -- ^ The Porest to show
  -> B.Widget n
porestToWidget b2w showColumns showIndented isFolded style p0 =
  fShow p where

  p :: Porest (Int, a) = fmap writeLevels p0

  fShow :: Porest (Int,a) -> B.Widget n
  fShow = vBox . map recursiveWidget . toList

  recursiveWidget :: PTree (Int,a) -> B.Widget n
  recursiveWidget pt =
    oneTreeRowWidget pt <=> rest where
    rest = case pt ^. pMTrees of
             Nothing -> emptyWidget
             Just pts ->
               case isFolded $ snd $ _pTreeLabel pt of
               True -> emptyWidget
               False -> fShow pts

  oneTreeRowWidget :: PTree (Int,a) -> B.Widget n
  oneTreeRowWidget t0 =
    let t :: PTree a  = fmap snd t0
        a :: a        = _pTreeLabel t
        indent :: Int = fst $ _pTreeLabel t0
    in style t $ hBox
       [ b2w $ showColumns a
       , padLeft (B.Pad $ 2 * indent) $
         b2w $ showIndented $ _pTreeLabel t ]

showPorest :: forall a d. Monoid d
  => (String -> d) -- ^ for inserting whitespace, for indentation
  -> (a -> d)      -- ^ Display a node's column information.
                   -- This info will be left-justified.
  -> (a -> d)      -- ^ Display a node's payload.
                   -- This info will be indented to form a tree.
  -> (a -> Bool)   -- ^ whether to hide a node's children
  -> Porest a      -- ^ what to display
  -> [( Bool,      -- ^ whether it has focus
        d )]       -- ^ how it looks
showPorest toString showColumns showPayload isFolded p0 =
  fShow p where

  p :: Porest (Int, a)
  p = fmap writeLevels p0

  fShow :: Porest (Int,a) -> [(Bool,d)]
  fShow = concatMap recursive . toList

  recursive :: PTree (Int,a) -> [(Bool,d)]
  recursive pt =
    once pt :
    case pt ^. pMTrees of
      Nothing -> []
      Just pts ->
        if isFolded $ snd $ _pTreeLabel pt
          then []
          else fShow pts

  once :: PTree (Int,a) -> (Bool, d)
  once t0 =
    let t :: PTree a  = fmap snd t0
        a :: a        = _pTreeLabel t
        indent :: Int = fst $ _pTreeLabel t0
    in ( _pTreeHasFocus t,
         showColumns a <>
         toString (replicate (2*indent) ' ') <>
         showPayload (_pTreeLabel t) )

-- | PITFALL: Assumes the lists in the input are of equal length.
maxColumnLengths :: forall t b. Foldable t
                 => Porest [t b] -> [Int]
maxColumnLengths p0 = let
  p1 :: Porest [Int] =
    fmap (fmap $ map length) p0
  zeros :: [Int] =
    map (const 0)
    $ foldr1 const -- takes the first element (efficiently, I think)
    $ ( p0 ^. P.focus :: PTree [t b] )
  update :: [Int] -> [Int] -> [Int]
  update acc [] = acc
  update (a:acc) (b:new) = max a b : update acc new
  maxima :: Foldable f => f [Int] -> [Int]
  maxima = foldr update zeros
  in maxima $ fmap maxima p1

tupleColumns :: (a -> [b]) -> Porest a -> Porest (a, [b])
tupleColumns makeColumns =
  fmap $ fmap $ \x -> (x, makeColumns x)