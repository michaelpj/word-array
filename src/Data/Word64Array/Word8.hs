{-# LANGUAGE
    MagicHash
  , TypeOperators
  , DataKinds
  , BangPatterns
  , KindSignatures
  , TypeFamilies
  , StandaloneDeriving
  , GeneralizedNewtypeDeriving
  , TypeApplications
  , ScopedTypeVariables
  , InstanceSigs
  , BinaryLiterals
  , RankNTypes
  , UnboxedTuples
#-}

module Data.Word64Array.Word8
  ( WordArray(..)
  , Index(..)
  , toWordArray
  , overIndex
  , iforWordArray
  , toList
  , toTuple
  , displayWordArray
  , index
  ) where

import Data.MonoTraversable
import Data.Word
import Data.Primitive
import Data.Maybe (fromMaybe)
import Data.Bits
import Numeric (showHex)
import Text.Show (showListWith)

newtype WordArray = WordArray { fromWordArray :: Word64 }
  deriving (Show, Eq, Ord)

type instance Element WordArray = Word8

newtype Index = Index { getIndex :: Int }
  deriving (Num, Eq, Ord)

instance Bounded Index where
  maxBound = 7
  minBound = 0

{-# INLINE toWordArray #-}
toWordArray :: Word64 -> WordArray
toWordArray = WordArray

displayWordArray :: WordArray -> String
displayWordArray wa = displayWordArrayS wa ""
  where
  displayHex x s = "0x" <> showHex x s
  displayWordArrayS = showListWith displayHex . toList

{-# INLINE toTuple #-}
toTuple :: WordArray -> (# Element WordArray, Element WordArray, Element WordArray, Element WordArray, Element WordArray, Element WordArray, Element WordArray, Element WordArray #)
toTuple (WordArray !w) = 
  let
    !w7 = w
    !w6 = unsafeShiftR w7 8
    !w5 = unsafeShiftR w6 8
    !w4 = unsafeShiftR w5 8
    !w3 = unsafeShiftR w4 8
    !w2 = unsafeShiftR w3 8
    !w1 = unsafeShiftR w2 8
    !w0 = unsafeShiftR w1 8
  in 
  (# fromIntegral w0
  ,  fromIntegral w1
  ,  fromIntegral w2
  ,  fromIntegral w3
  ,  fromIntegral w4
  ,  fromIntegral w5
  ,  fromIntegral w6
  ,  fromIntegral w7
  #)

{-# INLINE toList #-}
toList :: WordArray -> [Element WordArray]
toList w =
  let (# !w0, !w1, !w2, !w3, !w4, !w5, !w6, !w7 #) = toTuple w
  in [w0, w1, w2, w3, w4, w5, w6, w7]

index :: WordArray -> Index -> Element WordArray
index (WordArray w) (Index i) = 
  let offset = (-8 * i) + 56
  in fromIntegral $ unsafeShiftR w offset

{-# INLINE overIndex #-}
overIndex :: Int -> (Element WordArray -> Element WordArray) -> WordArray -> WordArray
overIndex i f (WordArray w) =
  let offset = (-8 * i) + 56
      w8 = fromIntegral $ unsafeShiftR w offset
      w8' = f w8
      w64 :: Word64
      w64 = unsafeShiftL (fromIntegral w8') offset
  in WordArray ((w .&. mask i) + w64)

{-# INLINE mask #-}
mask :: Int -> Word64
mask 0 = 0x00ffffffffffffff
mask 1 = 0xff00ffffffffffff
mask 2 = 0xffff00ffffffffff
mask 3 = 0xffffff00ffffffff
mask 4 = 0xffffffff00ffffff
mask 5 = 0xffffffffff00ffff
mask 6 = 0xffffffffffff00ff
mask 7 = 0xffffffffffffff00
mask _ = error "mask"

{-# INLINE iforWordArray #-}
iforWordArray :: Applicative f => WordArray -> (Int -> Element WordArray -> f ()) -> f ()
iforWordArray w f =
  let (# !w0, !w1, !w2, !w3, !w4, !w5, !w6, !w7 #) = toTuple w
  in   f 0 (fromIntegral w0) 
    *> f 1 (fromIntegral w1) 
    *> f 2 (fromIntegral w2) 
    *> f 3 (fromIntegral w3) 
    *> f 4 (fromIntegral w4) 
    *> f 5 (fromIntegral w5) 
    *> f 6 (fromIntegral w6) 
    *> f 7 (fromIntegral w7)


instance MonoFunctor WordArray where
  omap f w = 
    let (# !w0, !w1, !w2, !w3, !w4, !w5, !w6, !w7 #) = toTuple w
    in WordArray 
      (                (fromIntegral (f (fromIntegral w0)))
      .|. unsafeShiftL (fromIntegral (f (fromIntegral w1))) 8
      .|. unsafeShiftL (fromIntegral (f (fromIntegral w2))) 16
      .|. unsafeShiftL (fromIntegral (f (fromIntegral w3))) 24
      .|. unsafeShiftL (fromIntegral (f (fromIntegral w4))) 32
      .|. unsafeShiftL (fromIntegral (f (fromIntegral w5))) 40
      .|. unsafeShiftL (fromIntegral (f (fromIntegral w6))) 48
      .|. unsafeShiftL (fromIntegral (f (fromIntegral w7))) 56
      )

instance MonoFoldable WordArray where
  ofoldr f b w =
    let (# !w0, !w1, !w2, !w3, !w4, !w5, !w6, !w7 #) = toTuple w
    in  f (fromIntegral w0) 
      $ f (fromIntegral w1) 
      $ f (fromIntegral w2) 
      $ f (fromIntegral w3) 
      $ f (fromIntegral w4) 
      $ f (fromIntegral w5) 
      $ f (fromIntegral w6) 
      $ f (fromIntegral w7) b
  ofoldl' f z0 xs = ofoldr f' id xs z0
    where f' x k z = k $! f z x
  ofoldMap f = ofoldr (mappend . f) mempty
  onull _ = False
  oelem e = ofoldr (\a b -> a == e || b) False
  ofoldr1Ex f xs = fromMaybe 
      (errorWithoutStackTrace "error in word-array ofoldr1Ex: empty array")
      (ofoldr mf Nothing xs)
    where
    mf x m = Just $ case m of
      Nothing -> x
      Just y  -> f x y
  ofoldl1Ex' f xs = fromMaybe 
      (errorWithoutStackTrace "error in word-array ofoldr1Ex: empty array")
      (ofoldl' mf Nothing xs)
    where
    mf m y = Just $ case m of
      Nothing -> y
      Just x  -> f x y
