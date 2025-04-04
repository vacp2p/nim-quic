import std/bitops

type
  Bit* = range[0'u8 .. 1'u8]
  Bits* = distinct byte
  BitIndex = BitsRange[byte]

proc lsb(index: BitIndex): BitsRange[byte] =
  ### Converts a bit index from MSB 0 to LSB 0
  BitsRange[byte].high - BitsRange[byte](index)

proc `[]`*(bits: Bits, index: BitIndex): Bit =
  ## Returns the bit at the specified index.
  ## Uses MSB 0 bit numbering, so an `index`
  ## of 0 indicates the most significant bit.
  testBit[byte](bits.byte, index.lsb).Bit

proc `[]=`*(bits: var Bits, index: BitIndex, value: Bit) =
  ## Sets the bit at the specified index.
  ## Uses MSB 0 bit numbering, so an `index`
  ## of 0 indicates the most significant bit.
  case value
  of 0:
    clearBit[byte](bits.byte, index.lsb)
  of 1:
    setBit[byte](bits.byte, index.lsb)

proc bits*(value: byte): Bits =
  Bits(value)

proc bits*(value: var byte): var Bits =
  Bits(value)
