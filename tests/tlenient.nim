import eminim, streams

type
  Percent = object
    Name: string
    Percent: int
  Data = object
    majorsectorPercent: seq[Percent]
    borrower: string

block:
  let s = newFileStream("world_bank.json") # only a part of it to save space
  var a: seq[Data]
  for x in jsonItems(s, Data):
    a.add x
  assert a.len == 3
  assert a[0].borrower == "FEDERAL DEMOCRATIC REPUBLIC OF ETHIOPIA"
  assert a[0].majorsectorPercent.len == 4
  assert a[0].majorsectorPercent[0].Name == "Education"
  assert a[1].borrower == "GOVERNMENT OF TUNISIA"
