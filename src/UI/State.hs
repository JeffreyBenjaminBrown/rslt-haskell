{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE ViewPatterns #-}

module UI.State (
  initialState         -- ^ Rslt -> St
  , unEitherSt           -- ^ Either String St -> St -> St
  , resultsText        -- ^ St -> [String]
  , emptyCommandWindow -- ^ St -> St
  , parseAndRunCommand -- ^ St -> B.EventM WindowName (B.Next St)
  , runCommand -- ^ Command -> St
               -- -> Either String (B.EventM WindowName (B.Next St))
  ) where

import           Control.Monad.IO.Class (liftIO)
import           Data.Set (Set)
import qualified Data.Set                 as S
import qualified Data.Text.Zipper.Generic as TxZ
import qualified Data.Vector              as V
import           Lens.Micro
import           System.Directory

import qualified Brick.Main               as B
import qualified Brick.Focus              as B
import qualified Brick.Types              as B
import qualified Brick.Widgets.Edit       as B

import Hash.HLookup
import Qseq.QTypes
import Rslt.Edit
import Rslt.Files
import Rslt.RTypes
import UI.IParse
import UI.ITypes
import UI.IUtil
import Util.Misc


initialState :: Rslt -> St
initialState r = St {
    _focusRing = B.focusRing [Commands, Results]
      -- Almost always (for safety), Results is listed first. Not so
      -- here, because we want focus to start on the Commands window.
  , _viewTree  = ViewTree { _viewChildFocus = 0
                          , _viewIsFocused = False
                          , _viewContent = VQuery ""
                          , _viewSubviews = V.empty
                          }
  , _pathToFocus = []
  , _uiError   = ""
  , _commands  = B.editor Commands Nothing ""
  , _appRslt   = r
  , _shownInResultsWindow = ShowingResults
  }


unEitherSt :: St -> Either String St -> St
unEitherSt old (Left s) = old
  & shownInResultsWindow .~ ShowingError
  & uiError .~ s
unEitherSt _ (Right new) = new
  & shownInResultsWindow .~ ShowingResults


emptyCommandWindow :: St -> St
emptyCommandWindow = commands . B.editContentsL
                     .~ TxZ.textZipper [] Nothing


parseAndRunCommand :: St -> B.EventM WindowName (B.Next St)
parseAndRunCommand st =
  let cmd = unlines $ B.getEditContents $ st ^. commands
  in case pCommand (st ^. appRslt) cmd of
    Left parseErr -> B.continue $ unEitherSt st $ Left parseErr
      -- PITFALL: these two Lefts have different types.
    Right parsedCmd -> case runCommand parsedCmd st of
      Left runErr -> B.continue $ unEitherSt st $ Left runErr
        -- PITFALL: these two Lefts have different types.
      Right evNextSt -> evNextSt
        -- PITFALL: Don't call `unEitherSt` on this `evNextSt`, because
        -- it might be showing errors, because the load and save commnads
        -- must return Right in order to perform IO.


-- | Pitfall: this looks like it could just return `St` rather
-- than `Event ... St`, but it needs IO to load and save.
-- (If I really want to keep it pure I could add a field in St
-- that keeps a list of actions to execute.)
runCommand ::
  Command -> St -> Either String (B.EventM WindowName (B.Next St))

runCommand (CommandFind s h) st = do
  let r = st ^. appRslt
      title = "runCommand, called on CommandFind"

  (as :: Set Addr)   <- prefixLeft title
    $ hExprToAddrs r (mempty :: Subst Addr) h

  let v = ViewTree { _viewChildFocus = 0
                   , _viewIsFocused = False
                   , _viewContent = VQuery s
                   , _viewSubviews =
                     V.fromList $ map v_qr $ S.toList as
                   } where

        v_qr :: Addr -> ViewTree
        v_qr a = ViewTree {
            _viewChildFocus = 0
          , _viewIsFocused = False
          , _viewContent = let
              (rv :: Either String ViewResult) = resultView r a
              (err :: String -> ViewResult) = \se -> error ("runCommand (Find): should be impossible: `a` should be present, as it was just found by `hExprToAddrs`, but here's the original error: " ++ se)
              in VResult $ either err id rv
          , _viewSubviews = V.empty }

  Right $ B.continue $ st & pathToFocus .~ []
                          & shownInResultsWindow .~ ShowingResults
                          & viewTree .~ v

runCommand (CommandInsert e) st =
  either Left (Right . f)
  $ exprToAddrInsert (st ^. appRslt) e
  where
    f :: (Rslt, Addr) -> B.EventM WindowName (B.Next St)
    f (r,_) = B.continue $ st & appRslt .~ r
                              & shownInResultsWindow .~ ShowingResults

runCommand (CommandLoad f) st = Right $ do
  (bad :: Bool) <- liftIO $ not <$> doesDirectoryExist f
  if bad
    then B.continue $ st & uiError .~ "Non-existent folder: " ++ f
                         & shownInResultsWindow .~ ShowingError
    else do r <- liftIO $ readRslt f
            B.continue $ st & appRslt .~ r
                            & shownInResultsWindow .~ ShowingResults

runCommand (CommandSave f) st = Right $ do
  (bad :: Bool) <- liftIO $ not <$> doesDirectoryExist f
  st' <- if bad
    then return $ st & shownInResultsWindow .~ ShowingError
                     & uiError .~ "Non-existent folder: " ++ f
    else do liftIO $ writeRslt f $ st ^. appRslt
            return $ st & shownInResultsWindow .~ ShowingResults
  B.continue st'
