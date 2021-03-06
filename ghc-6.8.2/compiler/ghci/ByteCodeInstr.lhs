%
% (c) The University of Glasgow 2000-2006
%
ByteCodeInstrs: Bytecode instruction definitions

\begin{code}
{-# OPTIONS_GHC -funbox-strict-fields #-}

{-# OPTIONS -w #-}
-- The above warning supression flag is a temporary kludge.
-- While working on this module you are encouraged to remove it and fix
-- any warnings in the module. See
--     http://hackage.haskell.org/trac/ghc/wiki/Commentary/CodingStyle#Warnings
-- for details

module ByteCodeInstr ( 
 	BCInstr(..), ProtoBCO(..), bciStackUse, BreakInfo (..) 
  ) where

#include "HsVersions.h"
#include "../includes/MachDeps.h"

import ByteCodeItbls	( ItblPtr )

import Type
import Outputable
import Name
import Id
import CoreSyn
import PprCore
import Literal
import DataCon
import VarSet
import PrimOp
import SMRep

import GHC.Ptr

import Module (Module)
import GHC.Prim


-- ----------------------------------------------------------------------------
-- Bytecode instructions

data ProtoBCO a 
   = ProtoBCO { 
	protoBCOName       :: a,	  -- name, in some sense
	protoBCOInstrs     :: [BCInstr],  -- instrs
	-- arity and GC info
	protoBCOBitmap     :: [StgWord],
	protoBCOBitmapSize :: Int,
	protoBCOArity	   :: Int,
	-- what the BCO came from
	protoBCOExpr       :: Either  [AnnAlt Id VarSet] (AnnExpr Id VarSet),
	-- malloc'd pointers
        protoBCOPtrs       :: [Either ItblPtr (Ptr ())]
   }

type LocalLabel = Int

data BCInstr
   -- Messing with the stack
   = STKCHECK  Int

   -- Push locals (existing bits of the stack)
   | PUSH_L    !Int{-offset-}
   | PUSH_LL   !Int !Int{-2 offsets-}
   | PUSH_LLL  !Int !Int !Int{-3 offsets-}

   -- Push a ptr  (these all map to PUSH_G really)
   | PUSH_G       Name
   | PUSH_PRIMOP  PrimOp
   | PUSH_BCO     (ProtoBCO Name)

   -- Push an alt continuation
   | PUSH_ALTS          (ProtoBCO Name)
   | PUSH_ALTS_UNLIFTED (ProtoBCO Name) CgRep

   -- Pushing literals
   | PUSH_UBX  (Either Literal (Ptr ())) Int
	-- push this int/float/double/addr, on the stack.  Int
	-- is # of words to copy from literal pool.  Eitherness reflects
	-- the difficulty of dealing with MachAddr here, mostly due to
	-- the excessive (and unnecessary) restrictions imposed by the
	-- designers of the new Foreign library.  In particular it is
	-- quite impossible to convert an Addr to any other integral
	-- type, and it appears impossible to get hold of the bits of
	-- an addr, even though we need to to assemble BCOs.

   -- various kinds of application
   | PUSH_APPLY_N
   | PUSH_APPLY_V
   | PUSH_APPLY_F
   | PUSH_APPLY_D
   | PUSH_APPLY_L
   | PUSH_APPLY_P
   | PUSH_APPLY_PP
   | PUSH_APPLY_PPP
   | PUSH_APPLY_PPPP
   | PUSH_APPLY_PPPPP
   | PUSH_APPLY_PPPPPP

   | SLIDE     Int{-this many-} Int{-down by this much-}

   -- To do with the heap
   | ALLOC_AP  !Int	-- make an AP with this many payload words
   | ALLOC_PAP !Int !Int	-- make a PAP with this arity / payload words
   | MKAP      !Int{-ptr to AP is this far down stack-} !Int{-# words-}
   | MKPAP     !Int{-ptr to PAP is this far down stack-} !Int{-# words-}
   | UNPACK    !Int	-- unpack N words from t.o.s Constr
   | PACK      DataCon !Int
			-- after assembly, the DataCon is an index into the
			-- itbl array
   -- For doing case trees
   | LABEL     LocalLabel
   | TESTLT_I  Int    LocalLabel
   | TESTEQ_I  Int    LocalLabel
   | TESTLT_F  Float  LocalLabel
   | TESTEQ_F  Float  LocalLabel
   | TESTLT_D  Double LocalLabel
   | TESTEQ_D  Double LocalLabel

   -- The Int value is a constructor number and therefore
   -- stored in the insn stream rather than as an offset into
   -- the literal pool.
   | TESTLT_P  Int    LocalLabel
   | TESTEQ_P  Int    LocalLabel

   | CASEFAIL
   | JMP              LocalLabel

   -- For doing calls to C (via glue code generated by ByteCodeFFI)
   | CCALL            Int 	-- stack frame size
		      (Ptr ())  -- addr of the glue code

   -- For doing magic ByteArray passing to foreign calls
   | SWIZZLE          Int	-- to the ptr N words down the stack,
		      Int	-- add M (interpreted as a signed 16-bit entity)

   -- To Infinity And Beyond
   | ENTER
   | RETURN		-- return a lifted value
   | RETURN_UBX CgRep -- return an unlifted value, here's its rep

   -- Breakpoints 
   | BRK_FUN          (MutableByteArray# RealWorld) Int BreakInfo

data BreakInfo 
   = BreakInfo
   { breakInfo_module :: Module
   , breakInfo_number :: {-# UNPACK #-} !Int
   , breakInfo_vars   :: [(Id,Int)]
   , breakInfo_resty  :: Type
   }

instance Outputable BreakInfo where
   ppr info = text "BreakInfo" <+>
              parens (ppr (breakInfo_module info) <+>
                      ppr (breakInfo_number info) <+>
                      ppr (breakInfo_vars info) <+>
                      ppr (breakInfo_resty info))

-- -----------------------------------------------------------------------------
-- Printing bytecode instructions

instance Outputable a => Outputable (ProtoBCO a) where
   ppr (ProtoBCO name instrs bitmap bsize arity origin malloced)
      = (text "ProtoBCO" <+> ppr name <> char '#' <> int arity 
		<+> text (show malloced) <> colon)
	$$ nest 6 (text "bitmap: " <+> text (show bsize) <+> text (show bitmap))
        $$ nest 6 (vcat (map ppr instrs))
        $$ case origin of
              Left alts -> vcat (map (pprCoreAlt.deAnnAlt) alts)
              Right rhs -> pprCoreExpr (deAnnotate rhs)

instance Outputable BCInstr where
   ppr (STKCHECK n)          = text "STKCHECK" <+> int n
   ppr (PUSH_L offset)       = text "PUSH_L  " <+> int offset
   ppr (PUSH_LL o1 o2)       = text "PUSH_LL " <+> int o1 <+> int o2
   ppr (PUSH_LLL o1 o2 o3)   = text "PUSH_LLL" <+> int o1 <+> int o2 <+> int o3
   ppr (PUSH_G nm)  	     = text "PUSH_G  " <+> ppr nm
   ppr (PUSH_PRIMOP op)      = text "PUSH_G  " <+> text "GHC.PrimopWrappers." 
                                               <> ppr op
   ppr (PUSH_BCO bco)        = text "PUSH_BCO" <+> nest 3 (ppr bco)
   ppr (PUSH_ALTS bco)       = text "PUSH_ALTS " <+> ppr bco
   ppr (PUSH_ALTS_UNLIFTED bco pk) = text "PUSH_ALTS_UNLIFTED " <+> ppr pk <+> ppr bco

   ppr (PUSH_UBX (Left lit) nw) = text "PUSH_UBX" <+> parens (int nw) <+> ppr lit
   ppr (PUSH_UBX (Right aa) nw) = text "PUSH_UBX" <+> parens (int nw) <+> text (show aa)
   ppr PUSH_APPLY_N		= text "PUSH_APPLY_N"
   ppr PUSH_APPLY_V		= text "PUSH_APPLY_V"
   ppr PUSH_APPLY_F		= text "PUSH_APPLY_F"
   ppr PUSH_APPLY_D		= text "PUSH_APPLY_D"
   ppr PUSH_APPLY_L		= text "PUSH_APPLY_L"
   ppr PUSH_APPLY_P		= text "PUSH_APPLY_P"
   ppr PUSH_APPLY_PP		= text "PUSH_APPLY_PP"
   ppr PUSH_APPLY_PPP		= text "PUSH_APPLY_PPP"
   ppr PUSH_APPLY_PPPP		= text "PUSH_APPLY_PPPP"
   ppr PUSH_APPLY_PPPPP		= text "PUSH_APPLY_PPPPP"
   ppr PUSH_APPLY_PPPPPP	= text "PUSH_APPLY_PPPPPP"

   ppr (SLIDE n d)           = text "SLIDE   " <+> int n <+> int d
   ppr (ALLOC_AP sz)         = text "ALLOC_AP   " <+> int sz
   ppr (ALLOC_PAP arity sz)  = text "ALLOC_PAP   " <+> int arity <+> int sz
   ppr (MKAP offset sz)      = text "MKAP    " <+> int sz <+> text "words," 
                                               <+> int offset <+> text "stkoff"
   ppr (MKPAP offset sz)     = text "MKPAP   " <+> int sz <+> text "words,"
                                               <+> int offset <+> text "stkoff"
   ppr (UNPACK sz)           = text "UNPACK  " <+> int sz
   ppr (PACK dcon sz)        = text "PACK    " <+> ppr dcon <+> ppr sz
   ppr (LABEL     lab)       = text "__"       <> int lab <> colon
   ppr (TESTLT_I  i lab)     = text "TESTLT_I" <+> int i <+> text "__" <> int lab
   ppr (TESTEQ_I  i lab)     = text "TESTEQ_I" <+> int i <+> text "__" <> int lab
   ppr (TESTLT_F  f lab)     = text "TESTLT_F" <+> float f <+> text "__" <> int lab
   ppr (TESTEQ_F  f lab)     = text "TESTEQ_F" <+> float f <+> text "__" <> int lab
   ppr (TESTLT_D  d lab)     = text "TESTLT_D" <+> double d <+> text "__" <> int lab
   ppr (TESTEQ_D  d lab)     = text "TESTEQ_D" <+> double d <+> text "__" <> int lab
   ppr (TESTLT_P  i lab)     = text "TESTLT_P" <+> int i <+> text "__" <> int lab
   ppr (TESTEQ_P  i lab)     = text "TESTEQ_P" <+> int i <+> text "__" <> int lab
   ppr CASEFAIL              = text "CASEFAIL"
   ppr (JMP lab)             = text "JMP"      <+> int lab
   ppr (CCALL off marshall_addr) = text "CCALL   " <+> int off 
						<+> text "marshall code at" 
                                               <+> text (show marshall_addr)
   ppr (SWIZZLE stkoff n)    = text "SWIZZLE " <+> text "stkoff" <+> int stkoff 
                                               <+> text "by" <+> int n 
   ppr ENTER                 = text "ENTER"
   ppr RETURN		     = text "RETURN"
   ppr (RETURN_UBX pk)       = text "RETURN_UBX  " <+> ppr pk
   ppr (BRK_FUN breakArray index info) = text "BRK_FUN" <+> text "<array>" <+> int index <+> ppr info 

-- -----------------------------------------------------------------------------
-- The stack use, in words, of each bytecode insn.  These _must_ be
-- correct, or overestimates of reality, to be safe.

-- NOTE: we aggregate the stack use from case alternatives too, so that
-- we can do a single stack check at the beginning of a function only.

-- This could all be made more accurate by keeping track of a proper
-- stack high water mark, but it doesn't seem worth the hassle.

protoBCOStackUse :: ProtoBCO a -> Int
protoBCOStackUse bco = sum (map bciStackUse (protoBCOInstrs bco))

bciStackUse :: BCInstr -> Int
bciStackUse STKCHECK{}            = 0
bciStackUse PUSH_L{}       	  = 1
bciStackUse PUSH_LL{}       	  = 2
bciStackUse PUSH_LLL{}            = 3
bciStackUse PUSH_G{} 		  = 1
bciStackUse PUSH_PRIMOP{}         = 1
bciStackUse PUSH_BCO{}    	  = 1
bciStackUse (PUSH_ALTS bco)       = 2 + protoBCOStackUse bco
bciStackUse (PUSH_ALTS_UNLIFTED bco _) = 2 + protoBCOStackUse bco
bciStackUse (PUSH_UBX _ nw)       = nw
bciStackUse PUSH_APPLY_N{}	  = 1
bciStackUse PUSH_APPLY_V{}	  = 1
bciStackUse PUSH_APPLY_F{}	  = 1
bciStackUse PUSH_APPLY_D{}	  = 1
bciStackUse PUSH_APPLY_L{}	  = 1
bciStackUse PUSH_APPLY_P{}	  = 1
bciStackUse PUSH_APPLY_PP{}	  = 1
bciStackUse PUSH_APPLY_PPP{}	  = 1
bciStackUse PUSH_APPLY_PPPP{}	  = 1
bciStackUse PUSH_APPLY_PPPPP{}	  = 1
bciStackUse PUSH_APPLY_PPPPPP{}	  = 1
bciStackUse ALLOC_AP{}            = 1
bciStackUse ALLOC_PAP{}           = 1
bciStackUse (UNPACK sz)           = sz
bciStackUse LABEL{}       	  = 0
bciStackUse TESTLT_I{}     	  = 0
bciStackUse TESTEQ_I{}     	  = 0
bciStackUse TESTLT_F{}     	  = 0
bciStackUse TESTEQ_F{}     	  = 0
bciStackUse TESTLT_D{}     	  = 0
bciStackUse TESTEQ_D{}     	  = 0
bciStackUse TESTLT_P{}     	  = 0
bciStackUse TESTEQ_P{}     	  = 0
bciStackUse CASEFAIL{}		  = 0
bciStackUse JMP{}		  = 0
bciStackUse ENTER{}		  = 0
bciStackUse RETURN{}		  = 0
bciStackUse RETURN_UBX{}	  = 1
bciStackUse CCALL{} 		  = 0
bciStackUse SWIZZLE{}    	  = 0
bciStackUse BRK_FUN{}    	  = 0

-- These insns actually reduce stack use, but we need the high-tide level,
-- so can't use this info.  Not that it matters much.
bciStackUse SLIDE{}		  = 0
bciStackUse MKAP{}		  = 0
bciStackUse MKPAP{}		  = 0
bciStackUse PACK{}		  = 1 -- worst case is PACK 0 words
\end{code}
