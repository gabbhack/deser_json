func toString*(slice: openArray[char]): string =
  result = newStringOfCap(slice.len)

  for i in slice:
    result.add(i)
