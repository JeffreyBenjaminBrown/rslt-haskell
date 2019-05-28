{-# LANGUAGE ScopedTypeVariables #-}

module Hode.UI.String (
    resultsText  -- ^ St -> [String]
  , resultView   -- ^ Rslt -> Addr -> Either String ViewExpr
  , showRsltView -- ^ RsltView -> String
  ) where

import           Data.Foldable (toList)
import           Lens.Micro

import Hode.Rslt.RLookup
import Hode.Rslt.RTypes
import Hode.Rslt.Show
import Hode.UI.ITypes
import Hode.Util.Misc
import Hode.Util.PTree


resultsText :: St -> [String]
resultsText st = maybe [] (concatMap $ go 0) p where
  p :: Maybe (Porest BufferRow)
  p = st ^? stGetFocusedBuffer . _Just . bufferRsltViewPorest . _Just

  go :: Int -> PTree BufferRow -> [String]
  go i tv = indent (showRsltView $ tv ^. pTreeLabel . rsltView)
    : concatMap (go $ i+1) (maybe [] id $ toList <$> tv ^. pMTrees)
    where indent :: String -> String
          indent s = replicate (2*i) ' ' ++ s

resultView :: Rslt -> Addr -> Either String ViewExpr
resultView r a = do
  (s :: String) <- prefixLeft "resultView"
                   $ addrToExpr r a >>= eShow r
  Right $ ViewExpr { _viewResultAddr = a
                     , _viewResultString = s }

-- | `showRsltView` is used to display a `RsltView` in the UI. It is distinct
-- from `show` so that `show` can show everything about the `RsltView`,
-- whereas `showRsltView` hides things that the UI already makes clear.
showRsltView :: RsltView -> String -- TODO : rename showRsltView
showRsltView (VQuery vq)  = vq
showRsltView (VExpr qr) = show (qr ^. viewResultAddr)
  ++ ": " ++ show (qr ^. viewResultString)
showRsltView (VMemberGroup _) = "its members"
showRsltView (VHostGroup (RelHostGroup x)) = show x
showRsltView (VHostGroup (TpltHostGroup x)) = show x
