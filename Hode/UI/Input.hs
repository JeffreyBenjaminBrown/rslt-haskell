{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE ViewPatterns #-}

module Hode.UI.Input (
    handleUncaughtInput            -- ^ St -> B.Event ->
                                   -- B.EventM BrickName (B.Next St)
  , handleKeyboard_atResultsWindow -- ^ St -> B.Event ->
                                   -- B.EventM BrickName (B.Next St)
  , handleKeyboard_atBufferWindow  -- ^ St -> B.Event ->
                                   -- B.EventM BrickName (B.Next St)
  , parseAndRunCommand             -- ^ St ->
                                   -- B.EventM BrickName (B.Next St)
  , runParsedCommand    -- ^ Command -> St ->
                    -- Either String (B.EventM BrickName (B.Next St))
  ) where

import           Control.Monad.IO.Class (liftIO)
import qualified Data.List.PointedList as P
import           Data.Set (Set)
import qualified Data.Set              as S
import qualified Data.Text             as T
import           Lens.Micro
import           System.Directory

import qualified Brick.Main            as B
import qualified Brick.Types           as B
import qualified Brick.Widgets.Edit    as B
import qualified Brick.Focus           as B
import qualified Graphics.Vty          as B

import Hode.Hash.HLookup
import Hode.Qseq.QTypes
import Hode.Rslt.Edit
import Hode.Rslt.Files
import Hode.Rslt.RTypes
import Hode.UI.BufferTree
import Hode.UI.Clipboard
import Hode.UI.ITypes
import Hode.UI.IUtil
import Hode.UI.Input.IParse
import Hode.UI.String
import Hode.UI.BufferRowTree
import Hode.UI.Window
import Hode.Util.Direction
import Hode.Util.Misc
import Hode.Util.PTree


handleUncaughtInput :: St -> B.Event -> B.EventM BrickName (B.Next St)
handleUncaughtInput st ev =
  B.continue =<< case B.focusGetCurrent $ st ^. focusRing of
    Just (BrickOptionalName Commands) -> B.handleEventLensed
      (hideReassurance st) commands B.handleEditorEvent ev
    _ -> return st

handleKeyboard_atBufferWindow :: St -> B.Event -> B.EventM BrickName (B.Next St)
handleKeyboard_atBufferWindow st ev = case ev of
  B.EvKey (B.KChar 'e') [B.MMeta] -> B.continue
    $ moveFocusedBuffer DirPrev
    $ st & hideReassurance
  B.EvKey (B.KChar 'd') [B.MMeta] -> B.continue
    $ moveFocusedBuffer DirNext
    $ st & hideReassurance
  B.EvKey (B.KChar 'f') [B.MMeta] -> B.continue
    $ moveFocusedBuffer DirDown
    $ st & hideReassurance
  B.EvKey (B.KChar 's') [B.MMeta] -> B.continue
    $ moveFocusedBuffer DirUp
    $ st & hideReassurance

  B.EvKey (B.KChar 'c') [B.MMeta] -> B.continue
    $ consBuffer_asChild emptyBuffer
    $ st & hideReassurance
  B.EvKey (B.KChar 't') [B.MMeta] -> B.continue
    $ consBuffer_topNext emptyBuffer
    $ st & hideReassurance

  _ -> handleUncaughtInput st ev

handleKeyboard_atResultsWindow :: St -> B.Event -> B.EventM BrickName (B.Next St)
handleKeyboard_atResultsWindow st ev = case ev of
  B.EvKey (B.KChar 'h') [B.MMeta] -> B.continue $ unEitherSt st
    $ insertHosts_atFocus   st
  B.EvKey (B.KChar 'm') [B.MMeta] -> B.continue $ unEitherSt st
    $ insertMembers_atFocus st
  B.EvKey (B.KChar 'c') [B.MMeta] -> B.continue
    $ closeSubviews_atFocus st
  B.EvKey (B.KChar 'F') [B.MMeta] -> B.continue
    $ foldSubviews_atFocus st

  B.EvKey (B.KChar 'b') [B.MMeta] -> B.continue
    $ unEitherSt st
    $ st & cons_focusedViewExpr_asChildOfBuffer

  B.EvKey (B.KChar 'r') [B.MMeta] -> B.continue
    $ replaceCommand st

  B.EvKey (B.KChar 'w') [B.MMeta] -> do
    -- TODO : slightly buggy: conjures, copies some empty lines.
    liftIO ( toClipboard $ unlines $ resultsText st )
    B.continue $ st
      & showReassurance "Results window copied to clipboard."

  B.EvKey (B.KChar 'e') [B.MMeta] -> B.continue
    $ moveFocusedViewExprNode DirPrev
    $ st & hideReassurance
  B.EvKey (B.KChar 'd') [B.MMeta] -> B.continue
    $ moveFocusedViewExprNode DirNext
    $ st & hideReassurance
  B.EvKey (B.KChar 'f') [B.MMeta] -> B.continue
    $ moveFocusedViewExprNode DirDown
    $ st & hideReassurance
  B.EvKey (B.KChar 's') [B.MMeta] -> B.continue
    $ moveFocusedViewExprNode DirUp
    $ st & hideReassurance

  _ -> handleUncaughtInput st ev

parseAndRunCommand :: St -> B.EventM BrickName (B.Next St)
parseAndRunCommand st =
  let cmd = unlines $ B.getEditContents $ st ^. commands
  in case pCommand (st ^. appRslt) cmd of
    Left parseErr -> B.continue $ unEitherSt st $ Left parseErr
      -- PITFALL: these two Lefts have different types.
    Right parsedCmd -> case runParsedCommand parsedCmd st of
      Left runErr -> B.continue $ unEitherSt st $ Left runErr
        -- PITFALL: these two Lefts have different types.
      Right evNextSt -> (fmap $ fmap $ commandHistory %~ (:) parsedCmd)
                        evNextSt
        -- PITFALL: Don't call `unEitherSt` on this `evNextSt`, because
        -- it might be showing errors, because the load and save commnads
        -- must return Right in order to perform IO.


-- | Pitfall: this looks like it could just return `St` rather
-- than `Event ... St`, but it needs IO to load and save.
-- (If I really want to keep it pure I could add a field in St
-- that keeps a list of actions to execute.)
runParsedCommand ::
  Command -> St -> Either String (B.EventM BrickName (B.Next St))

runParsedCommand c0 st0 = prefixLeft "-> runParsedCommand"
                          $ g c0 st0
  where

  g (CommandFind s h) st =
    prefixLeft ", called on CommandFind" $ do
    let r = st ^. appRslt

    as :: Set Addr <-
      hExprToAddrs r (mempty :: Subst Addr) h

    let p :: Porest BufferRow
        p = maybe ( porestLeaf $ bufferRow_from_viewExprNode $
                    VQuery "No matches found.") id $
            P.fromList $ map v_qr $ S.toList as
          where
          v_qr :: Addr -> PTree BufferRow
          v_qr a = pTreeLeaf $ bufferRow_from_viewExprNode $
                   VExpr $ either err id rv
            where
            (rv :: Either String ViewExpr) = resultView r a
            (err :: String -> ViewExpr) = \se -> error ("called on Find: should be impossible: `a` should be present, as it was just found by `hExprToAddrs`, but here's the original error: " ++ se)

    Right $ B.continue $ st
      & showingInMainWindow .~ Results
      & showingErrorWindow .~ False
      & (let strip :: String -> String
             strip = T.unpack . T.strip . T.pack
         in stSetFocusedBuffer . bufferQuery .~ strip s)
      & stSetFocusedBuffer . bufferRowPorest . _Just .~ p
      & ( stSetFocusedBuffer . bufferRowPorest . _Just .
          P.focus . pTreeHasFocus .~ True )

  g (CommandReplace a e) st =
    either Left (Right . f)
    $ replaceExpr a e (st ^. appRslt)
    where f :: Rslt -> B.EventM BrickName (B.Next St)
          f r = B.continue $ st & appRslt .~ r
                                & showingErrorWindow .~ False
                                & showReassurance msg
                                & showingInMainWindow .~ Results
            where msg = "Replaced Expr at " ++ show a ++ "."

  g (CommandDelete a) st =
    either Left (Right . f)
    $ delete a (st ^. appRslt)
    where f :: Rslt -> B.EventM BrickName (B.Next St)
          f r = B.continue $ st & appRslt .~ r
                                & showingErrorWindow .~ False
                                & showReassurance msg
            where msg = "Deleted Expr at " ++ show a ++ "."

  g (CommandInsert e) st =
    either Left (Right . f)
    $ exprToAddrInsert (st ^. appRslt) e
    where
      f :: (Rslt, Addr) -> B.EventM BrickName (B.Next St)
      f (r,a) = B.continue $ st & appRslt .~ r
                & showingErrorWindow .~ False
                & showReassurance ("Expr added at Addr " ++ show a)
                & showingInMainWindow .~ Results

  g (CommandLoad f) st = Right $ do
    (bad :: Bool) <- liftIO $ not <$> doesDirectoryExist f
    if bad
      then B.continue $ st & showError ("Non-existent folder: " ++ f)
      else do r <- liftIO $ readRslt f
              B.continue $ st & appRslt .~ r
                              & showReassurance "Rslt loaded."
                              & showingInMainWindow .~ Results
                              & showingErrorWindow .~ False

  g (CommandSave f) st = Right $ do
    (bad :: Bool) <- liftIO $ not <$> doesDirectoryExist f
    st' <- if bad
      then return $ st & showError ("Non-existent folder: " ++ f)
      else do liftIO $ writeRslt f $ st ^. appRslt
              return $ st & showingInMainWindow .~ Results
                          & showingErrorWindow .~ False
                          & showReassurance "Rslt saved."
    B.continue st'