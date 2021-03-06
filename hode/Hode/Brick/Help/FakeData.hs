{-# LANGUAGE OverloadedStrings #-}

module Hode.Brick.Help.FakeData where

import qualified Data.List.PointedList as P
import           Data.Maybe

import Hode.Brick.Help.Types


sillyChoices :: Choice1Plist
sillyChoices = fromJust $ P.fromList
               [ ("animals & balls",       animals_and_balls)
               , ("chemicals & furniture", chemicals_and_furniture )
               , ("animals only",          animals_alone ) ]

animals_and_balls, chemicals_and_furniture, animals_alone :: Choice2Plist
animals_and_balls = fromJust $
                    P.fromList [ ("animals", animals)
                               , ("balls",   balls)
                               , ("abab",    abab)]

chemicals_and_furniture = maybe (error "impossible") id $
                          P.fromList [ ("chemicals", chemicals)
                                     , ("furniture", furniture)
                                     , ("cfcf",      cfcf) ]

animals_alone = fromJust $
                P.fromList [ ("(There's only one choice here.)", animals) ]

animals, balls, abab, chemicals, furniture, cfcf :: Choice3Plist
animals =
  fromJust $
  P.fromList [ ("Apple", "Introduced evil to the world. Tasty.")
             , ( "Bird","Flies, melodious." )
             , ( "Marsupials. Here are extra words, just to see what happens.", "Two womby phases!" )
             , ( "Snail","Slimy, fries up real nice." ) ]

balls =
  fromJust $
  P.fromList [ ("Basketball","Very bouncy.")
             , ( "Mercury","Bigger than a rugby ball, smaller than Saturn." )
             , ( "Softball","Lies! What the hell?" )
             , ( "Tennis ball", "Somehow extra awesome." ) ]

abab =
  fromJust $
  P.fromList [ ( "a", "A is for apple." )
             , ( "b", "B is for brownian motion." )
             , ( "c", "C is for Centigrade." )
             , ( "d", "D is for Darwinian." ) ]

chemicals =
  fromJust $
  P.fromList [ ("sugar", "long carbohydrate polymers")
             , ( "DMT", "illegal. Naturally manufactured by the brain." )
             , ( "capsaicin", "Intense. Probably misspelled." )
             , ( "DNA", "Hardest language ever." ) ]

furniture =
  fromJust $
  P.fromList [ ("chair","Most of a horse: four legs, a back and a butt.")
             , ("Ottoman","A roomy stool.")
             , ("table", "An arrangement of cells into columns and rows.") ]

cfcf =
  fromJust $
  P.fromList [ ( "G", "G is for gyroscope." )
             , ( "H", "H is for helium." )
             , ( "I", "I is for Indonesia." )
             , ( "J", "J is for jet skis." ) ]
