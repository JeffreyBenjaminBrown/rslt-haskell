{-# LANGUAGE ScopedTypeVariables #-}

module RelExperim where

import           Prelude
import           Data.Either
import qualified Data.List      as L
import           Data.Map (Map)
import qualified Data.Map       as M
import qualified Data.Relation  as R
import           Data.Set (Set)
import qualified Data.Set       as S

import Subst
import Types
import Util


type Rel = R.Relation
type CondElts' e = Rel e (Subst e)
type Possible' e = Map Var (CondElts' e)

data TSource = TSource  { plans   :: [TSourcePlan]
                        , inputs  :: [Var]
                        , outputs :: [Var] }
data TSourcePlan = TSourcePlan {
    tSource     :: Var
  , tName       :: Var
  , inputNames  :: [Var]
  , outputNames :: [Var] }

-- | If s binds i to i0 and o to o0, calling
-- `varPossibilities p s (TSource v (S.singleton i) (S.singleton o))`,
-- should yield all values of v for which i=i0 is an input and for which
-- o=o0 is an output.

--varPossibilities :: forall e. (Ord e, Show e)
--                 => Possible e -> Subst e -> TSource
--                 -> Either String (Possible e)
--varPossibilities    p           s            (TSource plans ins outs) = let
--  se, lefts :: [Either String (CondElts e)]
--  se = map (f . tSource) plans where
--    f :: Var -> Either String (CondElts e)
--    f v = maybe (Left $ keyErr "varPossibilities" v p) Right
--          $ M.lookup v p
--  lefts = filter isLeft se
--  in case null lefts of
--  False -> Left $ foldr (++) "" $ map (fromLeft "") lefts
--  True -> let
--    (subPoss :: Possible e) = M.fromList $ zip (map tName plans)
--                              $ map (fromRight mempty) se
--    in Right $ M.map insMatch subPoss
--    -- TODO : match outputs also

--insMatch :: TSource -> TSourcePlan -> CondElts e -> CondElts e
--insMatch (TSource _ ins _) t = M.filter (not . S.null)
--  . M.map ( S.filter $ M.isSubmapOf
--            $ M.mapKeys renameIn
--            $ M.restrictKeys s
--            $ S.fromList ins )

renameIn :: TSource -> TSourcePlan -> Var -> Either String Var
renameIn t pl k = let ins = inputs t
                      newNames = inputNames pl
                      renamer = M.fromList $ zip ins newNames
  in maybe  (Left $ keyErr "renameInput" k renamer) Right
     $ M.lookup k renamer
