import bitops

type
  Bit* = range[0'u8..1'u8]
  Bits* = distinct byte
  BitIndex = BitsRange[byte]
  Bytes* = distinct uint32
  ByteIndex* = range[0..sizeof(uint32)-1]

proc lsb(index: BitIndex): BitsRange[byte] =
  ### Converts a bit index from MSB 0 to LSB 0
  BitsRange[byte].high - BitsRange[byte](index)

proc lsb(index: ByteIndex): ByteIndex =
  ## Converts a byte index from MSB 0 to LSB 0
  ByteIndex.high - index

proc `[]`*(bits: Bits, index: BitIndex): Bit =
  ## Returns the bit at the specified index.
  ## Uses MSB 0 bit numbering, so an `index`
  ## of 0 indicates the most significant bit.
  testBit[byte](bits.byte, index.lsb).Bit

proc `[]`*(bytes: Bytes, index: ByteIndex): byte =
  ## Returns the byte at the specified index.
  ## Uses MSB 0 byte numbering, so an `index`
  ## of 0 indicates the most significant byte.
  byte(uint32(bytes) shr (index.lsb * 8))

proc `[]=`*(bits: var Bits, index: BitIndex, value: Bit) =
  ## Sets the bit at the specified index.
  ## Uses MSB 0 bit numbering, so an `index`
  ## of 0 indicates the most significant bit.
  case value:
  of 0: clearBit[byte](bits.byte, index.lsb)
  of 1: setBit[byte](bits.byte, index.lsb)

proc `[]=`*(bytes: var Bytes, index: ByteIndex, value: byte) =
  ## Sets the byte at the specified index.
  ## Uses MSB 0 byte numbering, so an `index`
  ## of 0 indicates the most significant byte.
  bytes = Bytes(uint32(bytes) or (uint32(value) shl (index.lsb * 8)))

proc bits*(value: byte): Bits =
  Bits(value)

proc bits*(value: var byte): var Bits =
  Bits(value)

proc bytes*(value: uint32): Bytes =
  Bytes(value)

proc bytes*(value: var uint32): var Bytes =
  Bytes(value)
