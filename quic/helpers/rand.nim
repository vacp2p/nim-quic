import bearssl/rand, bearssl/hash as bhash

proc newRng*(): ref HmacDrbgContext =
  var seeder = prngSeederSystem(nil)
  if seeder == nil:
    return nil

  var rng = (ref HmacDrbgContext)()
  hmacDrbgInit(rng[], addr sha256Vtable, nil, 0)
  if seeder(addr rng.vtable) == 0:
    return nil
  rng
