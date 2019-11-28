{-# LANGUAGE OverloadedStrings
, ScopedTypeVariables
, TupleSections #-}

module Hode.UI.Main where

import qualified Data.List.PointedList as P
import qualified Data.Map             as M
import           Lens.Micro

import qualified Brick.Main           as B
import qualified Brick.Types          as B
import           Brick.Widgets.Core
import qualified Brick.Widgets.Center as B
import qualified Brick.Widgets.Edit   as B
import qualified Brick.AttrMap        as B
import qualified Brick.Focus          as B
import           Brick.Util (on)
import qualified Graphics.Vty         as V

import Hode.PTree.Initial
import Hode.Rslt.Index (mkRslt)
import Hode.Rslt.RTypes
import Hode.UI.BufferShow
import Hode.UI.IUtil
import Hode.UI.Input
import Hode.UI.Types.Names
import Hode.UI.Types.State


ui :: IO St
ui = uiFromRslt $ mkRslt mempty

uiFromSt :: St -> IO St
uiFromSt = B.defaultMain app

uiFromRslt :: Rslt -> IO St
uiFromRslt = B.defaultMain app . emptySt

app :: B.App St e BrickName
app = B.App
  { B.appDraw         = appDraw
  , B.appChooseCursor = appChooseCursor
  , B.appHandleEvent  = appHandleEvent
  , B.appStartEvent   = return
  , B.appAttrMap      = const appAttrMap
  }


-- | The focused subview is recalculated at each call to `appDisplay`.
-- Each `ViewExprNodeTree`'s `viewIsFocused` field is `False` outside of `appDisplay`.
appDraw :: St -> [B.Widget BrickName]
appDraw st0 = [w] where
  w :: B.Widget BrickName =
    B.center $
    ( if st0 ^. showingErrorWindow
      then errorWindow else mainWindow )
    <=> optionalWindows

  st :: St = st0
    & ( searchBuffers . _Just . P.focus
        . setFocusedSubtree
        -- set focus in the SearchBuffers window
        . pTreeHasFocus .~ True )
    & ( stSetFocused_ViewExprNode_Tree
        -- set focus in the Results window
        . pTreeHasFocus .~ True )

  b :: Buffer = maybe
    (error "Focused Buffer not found.") id
    $ st0 ^? stGetFocused_Buffer . _Just

  mainWindow :: B.Widget BrickName =
    case st ^. showingInMainWindow of
      CommandHistory -> commandHistoryWindow
      SearchBuffers  -> bufferWindow $ st ^. searchBuffers
      Results        -> resultWindow (st ^. viewOptions) b

  optionalWindows :: B.Widget BrickName =
    mShow Reassurance reassuranceWindow <=>
    mShow Commands commandWindow
    where mShow wName window =
            if (st ^. showingOptionalWindows) M.! wName
            then window else emptyWidget

  commandHistoryWindow :: B.Widget BrickName =
    strWrap $ unlines $ map show $ st0 ^. commandHistory

  commandWindow :: B.Widget BrickName =
    vLimit 2
    ( B.withFocusRing (st ^. focusRing)
      (B.renderEditor $ str . unlines) (st ^. commands) )

  errorWindow :: B.Widget BrickName = vBox
    [ strWrap $ st ^. uiError
    , padTop (B.Pad 2) $ strWrap $ "(To escape this error message, press M-S-r (to go to Results), M-S-b (SearchBuffers), or M-S-h (command History)." ]

  reassuranceWindow :: B.Widget BrickName =
    withAttr (B.attrName "white on blue")
    $ strWrap $ st0 ^. reassurance

appChooseCursor :: St -> [B.CursorLocation BrickName]
                -> Maybe (B.CursorLocation BrickName)
appChooseCursor = B.focusRingCursor (^. focusRing)

appHandleEvent :: St -> B.BrickEvent BrickName e
               -> B.EventM BrickName (B.Next St)
appHandleEvent st (B.VtyEvent ev) = case ev of
  V.EvKey V.KEsc [V.MMeta] -> B.halt st

  -- command window
  V.EvKey (V.KChar 'x') [V.MMeta] -> parseAndRunCommand st

  -- switch main window content
  V.EvKey (V.KChar 'H') [V.MMeta] -> B.continue
    $ st & showingInMainWindow .~ CommandHistory
         & showingErrorWindow .~ False
  V.EvKey (V.KChar 'B') [V.MMeta] -> B.continue
    $ st & showingInMainWindow .~ SearchBuffers
         & showingErrorWindow .~ False
  V.EvKey (V.KChar 'R') [V.MMeta] -> B.continue
    $ st & showingInMainWindow .~ Results
         & showingErrorWindow .~ False
  -- Brick-focus-related stuff. So far unneeded.
    -- PITFALL: The focused `Window` is distinct from
    -- the focused widget within the `mainWindow`.
    -- V.EvKey (V.KChar '\t') [] -> B.continue $ st & focusRing %~ B.focusNext
    -- V.EvKey V.KBackTab []     -> B.continue $ st & focusRing %~ B.focusPrev

  _ -> case st ^. showingInMainWindow of
    Results       -> handleKeyboard_atResultsWindow st ev
    SearchBuffers -> handleKeyboard_atBufferWindow  st ev
    _             -> handleUncaughtInput            st ev


appHandleEvent st _ = B.continue st

appAttrMap :: B.AttrMap
appAttrMap = let
  rc :: Int -> Int -> Int -> V.Color
    = V.rgbColor
  gray (k :: Int) = V.rgbColor k k k
  -- black  = gray 0
  -- gray1  = gray 1 -- PITFALL: Vty offers darker non-black grays.
  --  -- See VTY issue https://github.com/jtdaugherty/vty/issues/172
  white     = gray 255
  darkBlue  = rc 0 0 1
  darkGreen = rc 0 1 0
  darkRed   = rc 1 0 0
  in B.attrMap V.defAttr
    [ (B.editAttr                    , V.black `on` V.red) -- unused
    , (B.editFocusedAttr             , white   `on` darkBlue)
    , (B.attrName "white on red"     , white   `on` darkRed)
    , (B.attrName "white on green"   , white   `on` darkGreen)
    , (B.attrName "white on blue"    , white   `on` darkBlue)
    ]
