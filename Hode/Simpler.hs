{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}

module Hode.Simpler where

import           Lens.Micro
import           Brick.Util (on)
import           Brick.Types hiding (render)
import           Brick.Widgets.Core
import qualified Brick.BorderMap as B
import qualified Brick.Main      as B
import qualified Graphics.Vty as V


-- | Like `String`, but font can vary across it.
type AttrString = [(String, V.Attr)]

-- | Something to display
type Row = ( [String]    -- ^ shown on the left
           , [String] ) -- ^ show on the right

test :: Size -> Size
     -> (Size -> Size -> [Row] -> Widget ())
     -> IO ()
test s t render = B.simpleMain $ render s t rows

showRightSide, showBothSides :: Size -> Size -> [Row] -> Widget ()
showRightSide = showRows False
showBothSides = showRows True

showRows :: Bool -- ^ Whether to show left side. (Right side always shows.)
         -> Size -> Size -> [Row] -> Widget ()
showRows showLeft s t = vBox . map showRow where
  toAttrString :: V.Attr -> [String] -> AttrString
  toAttrString a = map (, a)
  showRow :: Row -> Widget n
  showRow (l,r) = let w = attrStringWrap s t
    in case showLeft of
         True  -> hBox [ w $ toAttrString (V.red `on` V.blue) l
                       , w $ toAttrString (V.blue `on` V.red) r ]
         False ->        w $ toAttrString (V.blue `on` V.red) r

rows :: [Row]
rows = [ (["10"],  replicate 32 " Hi! " )
       , (["123456789012345"], replicate 18  " What's up?  ") ]

attrStringWrap ::  Size -> Size -> AttrString -> Widget n
attrStringWrap hSize0 vSize0 content =
  Widget hSize0 vSize0 $ do
    ctx <- getContext
    let w = ctx^.availWidthL
        i :: V.Image = linesToImage $ splitLines w content
    return $ Result i [] [] [] B.empty
  where

  linesToImage :: [AttrString] -> V.Image
  linesToImage = let g (s,a) = V.string a s
    in V.vertCat . map (V.horizCat . map g)

  -- | PITFALL: Does not consider the case in which a single token
  -- does not fit on one line. Its right side will be truncated.
  splitLines :: Int -> AttrString -> [AttrString]
  splitLines maxWidth = reverse . map reverse . f 0 [] where
    f _       acc               []                  = acc
    f _       []                ((s,a):moreInput)   =
      f (length s) [[(s,a)]] moreInput
    f lineLen o@(line:moreOutput) ((s,a):moreInput) =
      let newLen = lineLen + length s
      in if newLen > maxWidth
         then f (length s) ([(s,a)]     :o)          moreInput
         else f newLen     (((s,a):line):moreOutput) moreInput
