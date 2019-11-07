{-# LANGUAGE ScopedTypeVariables #-}

module Hode.UI.IUtil.String (
    resultsText  -- ^ St -> [String]
  , mkViewExpr   -- ^ Rslt -> Addr -> Either String ViewExpr
  , show_ViewExprNode  -- ^ ViewExprNode -> String
  , show_ViewExprNode' -- ^ ViewExprNode -> AttrString
  ) where

import           Data.Foldable (toList)
import           Lens.Micro

import Hode.Brick
import Hode.Rslt.RLookup
import Hode.Rslt.RTypes
import Hode.Rslt.ShowAttr
import Hode.UI.ITypes
import Hode.Util.Misc
import Hode.Util.PTree


-- | Render an entire `Buffer` to text.
resultsText :: St -> [String]
resultsText st = maybe [] (concatMap $ go 0) p where
  p :: Maybe (Porest BufferRow)
  p = st ^? stGetFocused_Buffer . _Just .
      bufferRowPorest . _Just

  go :: Int -> PTree BufferRow -> [String]
  go i tv = indent ( show_ViewExprNode $
                     tv ^. pTreeLabel . viewExprNode )
            : concatMap (go $ i+1)
            (maybe [] id $ toList <$> tv ^. pMTrees)
    where indent :: String -> String
          indent s = replicate (2*i) ' ' ++ s

mkViewExpr :: Rslt -> Addr -> Either String ViewExpr
mkViewExpr r a = do
  (s :: AttrString) <- prefixLeft "mkViewExpr:"
    $ addrToExpr r a >>= eParenShowAttr 3 r
  Right $ ViewExpr { _viewExpr_Addr = a
                   , _viewExpr_String = s }

-- | `show_ViewExprNode` is used to display a `ViewExprNode` in the UI.
-- Whereas `show` shows everything about the `ViewExprNode`,
-- `show_ViewExprNode` hides things that the UI already makes clear.
show_ViewExprNode :: ViewExprNode -> String
show_ViewExprNode (VQuery vq) = vq
show_ViewExprNode (VExpr x) =
  show (x ^. viewExpr_Addr) ++ ": "
  ++ show (x ^. viewExpr_String)
show_ViewExprNode (VMemberFork _) = "its members"
show_ViewExprNode (VHostFork (RelHostFork  x)) = show x
show_ViewExprNode (VHostFork (TpltHostFork x)) = show x

show_ViewExprNode' :: ViewExprNode -> AttrString
show_ViewExprNode' (VExpr ve) =
  [(show $ _viewExpr_Addr ve, addrColor)]
  ++ _viewExpr_String ve
show_ViewExprNode' x =
  [(show_ViewExprNode x, textColor)]
