module Hode.Hash.Parse.Keywords where

import Hode.Hash.Parse.Util
import Hode.Util.Misc


reach :: HashKeyword
reach = let
  hs = [HashSymbol { _rawSymbol = "#"
                   , _slashPrefix = True } ]
  in HashKeyword {
    _title = "transitive reach",
    _symbol = hs,
    _help = "`/tr /_ #<= b` finds everything less than or equal to b." }

transLeft :: HashKeyword
transLeft = let
  hs = [ HashSymbol { _rawSymbol = "trl"
                    , _slashPrefix = True } ]
  in HashKeyword {
    _title = "leftward transitive search",
    _symbol = hs,
    _help = "If `0 #< 1 #< 2 #< 3`, then `/trl (/it= 1/|3) #< 2` will return 1 and not 3, and search leftward. If the it= was on the other side, then it would return 2, because for something in {1,3}, the relationship holds." }

transRight :: HashKeyword
transRight = let
  hs = [ HashSymbol { _rawSymbol = "trr"
                    , _slashPrefix = True } ]
  in HashKeyword {
    _title = "rightward transitive search",
    _symbol = hs,
    _help = "If `0 #< 1 #< 2 #< 3`, then `/trl (/it= 1/|3) #< 2` will return 1 and not 3, and search leftward. If the it= was on the other side, then it would return 2, because for something in {1,3}, the relationship holds." }

hash :: HashKeyword
hash = let
  hs = [ HashSymbol { _rawSymbol = "#"
                    , _slashPrefix = False } ]
  s = rep 1 $ head hs
  in HashKeyword {
    _title = "build relationships",
    _symbol = hs,
    _help = paragraphs
      [ paragraph
        [ "The " ++ s ++ " symbol is used to define relationships."
        , "It is the fundamental operator in the Hash language."
        , "See docs/hash/the-hash-language.md for an in-depth discussion." ]

      , paragraph
        [ "Here are some examples: "
        , "`bird " ++ s ++ "eats worm` defines a two-member \"eats\" relatinoship between bird and worm."
        , "`Bill " ++ s ++ "uses hammer " ++ s ++ "on nail` defines a three-member \"uses-on\" relationship involving Bill, hammer and nail."
        , "`Bill " ++ s ++ "eats pizza " ++ concat (replicate 2 s) ++ "because bill " ++ s ++ "cannot cook` defines a \"because\" relationship between two relationships." ]

      , paragraph
        [ "The last example illustrates the use of symbols like " ++ error "TODO: illustrate ##, ### etc." ]
      ] }

hOr :: HashKeyword
hOr = let
  hs = [ HashSymbol { _rawSymbol = "|"
                    , _slashPrefix = True } ]
  in HashKeyword {
    _title = "or",
    _symbol = hs,
    _help = "TODO" }

diff :: HashKeyword
diff = let
  hs = [ HashSymbol { _rawSymbol = "\\"
                    , _slashPrefix = True } ]
  in HashKeyword {
    _title = "difference",
    _symbol = hs,
    _help = "TODO" }

hAnd :: HashKeyword
hAnd = let
  hs = [ HashSymbol { _rawSymbol = "&"
                    , _slashPrefix = True } ]
  s = rep 1 $ head hs
  in HashKeyword {
    _title = "and",
    _symbol = hs,
    _help = paragraphs
      [ paragraph
        [ "The " ++ s ++ " symbol is used for logical conjunction."
        , "`a " ++ s ++ " b` represents all expressions that match both `a` and `b`."
        , "See docs/hash/the-hash-language.md for an in-depth discussion." ]
      , paragraph
        [ "Here are some examples: "
        , error "TODO: illustrate `eval` and precedence." ]
      ] }
