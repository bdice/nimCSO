# Copyrigth (C) 2023 Adam M. Krajewski

import arraymancer
import std/strutils
import std/times
import bitty
import std/os
import std/sequtils
import std/random
import std/heapqueue
import std/hashes

when compileOption("profiler"):
  import nimprof

let elementOrder* = ["Fe", "Cr", "Ni", "Co", "Al", "Ti", "Nb", "Cu", "Mo", "Ta", "Zr",
                     "V",  "Hf", "W",  "Mn", "Si", "Re", "B",  "Ru", "C",  "Sn", "Mg",
                     "Zn", "Li", "O",  "Y",  "Pd", "N",  "Ca", "Ir", "Sc", "Ge", "Be", 
                     "Ag", "Nd", "S",  "Ga"]

proc getPresenceTensor*(): Tensor[uint8] =
    let elementsPresentList = readFile("elementLists.txt").splitLines()
    var
        presence = newTensor[uint8]([elementsPresentList.len, elementOrder.len])
        lineN: int = 0
        elN: int = 0

    for line in elementsPresentList:
        let elements = line.split(",")
        elN = 0
        for el in elementOrder:
            if elements.contains(el):
                presence[lineN, elN] = 1
            elN += 1
        lineN += 1
    result = presence

proc getPresenceBitArrays*(): seq[BitArray] =
    let elementsPresentList = readFile("elementLists.txt").splitLines()
    var
        presence = newBitArray(elementOrder.len)
        elN: int = 0

    for line in elementsPresentList:
        let elements = line.split(",")
        elN = 0
        for el in elementOrder:
            if elements.contains(el):
                presence[elN] = true
            elN += 1
        result.add(presence)
        presence = newBitArray(elementOrder.len)

proc getPresenceBoolArrays*(): seq[seq[bool]] =
    let 
        elementsPresentList = readFile("elementLists.txt").splitLines()
        alloyN = elementsPresentList.len
        elN = elementOrder.len
    var
        elI: int = 0
        lineI: int = 0
        
    result = newSeqWith(alloyN, newSeq[bool](elN))

    for line in elementsPresentList:
        let elements = line.split(",")
        elI = 0
        for el in elementOrder:
            if elements.contains(el):
                result[lineI][elI] = true
            elI += 1
        lineI += 1

proc preventedData*(elList: BitArray, presenceBitArrays: seq[BitArray]): int  =
    let elN = elList.len
    var elBoolSeq = newSeq[bool](elN)
    for i in 0 ..< elN:
        elBoolSeq[i] = elList.unsafeGet(i)

    func isPrevented(presenceBitArray: BitArray): bool =
        for i in 0..<elN:
            if elBoolSeq[i] and presenceBitArray.unsafeGet(i):
                return true
        return false
    for pm in presenceBitArrays:
        if isPrevented(pm):
            result += 1

proc preventedData*(elList: BitArray, presenceBoolArrays: seq[seq[bool]]): int  =
    let elN = elList.len
    var elBoolSeq = newSeq[bool](elN)
    for i in 0 ..< elN:
        elBoolSeq[i] = elList.unsafeGet(i)

    func isPrevented(presenceBoolArray: seq[bool]): bool =
        for i in 0..<elN:
            if elBoolSeq[i] and presenceBoolArray[i]:
                return true
        return false
    for pm in presenceBoolArrays:
        if isPrevented(pm):
            result += 1

proc preventedData*(elList: Tensor[uint8], presenceTensor: Tensor[uint8]): int =
    let c = presenceTensor *. elList
    result = c.max(axis=1).asType(int).sum()

### Solution class implementation

type ElSolution* = ref object 
    elBA*: BitArray
    prevented*: int 

proc newElSolution*(elBA: BitArray, pBA: seq[BitArray] | seq[seq[bool]]): ElSolution =
    result = ElSolution()
    result.elBA = elBA
    result.prevented = preventedData(elBA, pBA)

func hash*(elSol: ElSolution): Hash =
    hash(elSol.elBA)

proc `$`*(elSol: ElSolution): string =
    for i in 0..elSol.elBA.len-1:
        if elSol.elBA[i]:
            result.add(elementOrder[i])
    result.add("->")
    result.add(elSol.prevented.intToStr())

proc `<`*(a, b: ElSolution): bool = a.prevented < b.prevented

proc `>`*(a, b: ElSolution): bool = a.prevented > b.prevented

proc setPrevented*(elSol: var ElSolution, presenceArrays: seq[BitArray] | seq[seq[bool]]): void =
    elSol.prevented = preventedData(elSol.elBA, presenceArrays)

proc randomize*(elSol: var ElSolution): void =
    for i in 0..elSol.elBA.len-1:
        elSol.elBA[i] = (rand(1) > 0)

proc getNextNodes*(elSol: ElSolution, 
                   exclusions: BitArray, 
                   presenceBitArrays: seq[BitArray] | seq[seq[bool]]): seq[ElSolution] =
    for i in 0..<elSol.elBA.len:
        if not elSol.elBA[i] and not exclusions[i]:
            var newElBA = newBitArray(elSol.elBA.len)
            for bit in 0..elSol.elBA.len-1:
                newElBA[bit] =  elSol.elBA[bit]
            newElBA[i] = true
            result.add(newElSolution(newElBA, presenceBitArrays))

### Helper procedures

template benchmark(benchmarkName: string, code: untyped) =
  block:
    let t0 = epochTime()
    for i in 1..1000:
        code
    let elapsed = (epochTime() - t0) * 1000
    let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 1)
    echo "CPU Time [", benchmarkName, "] ", elapsedStr, "us"

template benchmarkOnce(benchmarkName: string, code: untyped) =
  block:
    let t0 = epochTime()
    code
    let elapsed = (epochTime() - t0) * 1000
    let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 1)
    echo "CPU Time [", benchmarkName, "] ", elapsedStr, "ms"

proc echoHelp() = echo """
To use form command line, provide parameters. Currently supported usage:

--covBenchmark | -cb     --> Run small coverage benchmarks under two implementations.
--expBenchmark | -eb     --> Run small node expansion benchmarks.
--develpment   | -d      --> Run development code.

"""

when isMainModule:
    let args = commandLineParams()
    if args.len == 0:
        echoHelp()

    if "--covBenchmark" in args or "-cb" in args:
        block:
            echo "Running coverage benchmark with uint8 Tensor representation"

            let presenceTensor = getPresenceTensor()
            var b = zeros[uint8](shape = [1, 37])
            b[0, 0..5] = 1
            echo b

            benchmark "arraymancer+randomizing":
                discard preventedData(randomTensor[uint8](shape = [1, 37], sample_source = [0.uint8,1.uint8]), 
                                        presenceTensor)
            echo "Prevented count:", preventedData(b, presenceTensor)

        block:
            echo "\nRunning coverage benchmark with BitArray representation"
            let presenceBitArrays = getPresenceBitArrays()
            var bb = newBitArray(37)
            for i in 0..5: bb[i] = true
            echo bb

            benchmark "bitty+randomizing":
                var esTemp = ElSolution()
                esTemp.elBA = newBitArray(37)
                esTemp.randomize()
                esTemp.setPrevented(presenceBitArrays)
            let particularResult = newElSolution(bb, presenceBitArrays)
            echo particularResult
            echo "Prevented count:", particularResult.prevented

        block:
            echo "\nRunning coverage benchmark with bool arrays representation (BitArray graph retained)"
            let presenceBoolArrays = getPresenceBoolArrays()
            var bb = newBitArray(37)
            for i in 0..5: bb[i] = true
            echo bb
            benchmark "bit&boolArrays+randomizing":
                var esTemp = ElSolution()
                esTemp.elBA = newBitArray(37)
                esTemp.randomize()
                esTemp.setPrevented(presenceBoolArrays)
            let particularResult = newElSolution(bb, presenceBoolArrays)
            echo particularResult
            echo "Prevented count:", particularResult.prevented

    if "--expBenchmark" in args or "-eb" in args:
        block:
            echo "\nRunning coverage benchmark with BitArray representation:"
            let 
                bb = newBitArray(37)
                presenceBitArrays = getPresenceBitArrays()

            var esTemp = newElSolution(bb, presenceBitArrays)
            echo esTemp.getNextNodes(newBitArray(37), presenceBitArrays)
            benchmark "Expanding to 37 nodes 1000 times from empty":
                discard esTemp.getNextNodes(bb, presenceBitArrays)

            benchmark "Expanding to 1-37 nodes 1000 times from random":
                esTemp.randomize()
                discard esTemp.getNextNodes(bb, presenceBitArrays)
            
            var 
                solutions = initHeapQueue[ElSolution]()
                toExpand: ElSolution
                toExclude = newBitArray(37)

            solutions.push(newElSolution(newBitArray(37), presenceBitArrays))
            benchmark "Expanding 1000 steps (results dataset-dependent!)":
                toExpand = solutions.pop()
                for sol in getNextNodes(toExpand, toExclude, presenceBitArrays):
                    solutions.push(sol)
                toExclude = toExclude or toExpand.elBA
            echo "Last solution on heap: ", solutions[0]

        block:
            echo "\nRunning coverage benchmark with bool arrays representation (BitArray graph retained)"
            let bb = newBitArray(37)
            let presenceBoolArrays = getPresenceBoolArrays()
            var esTemp = newElSolution(bb, presenceBoolArrays)

            benchmark "Expanding to 37 nodes 1000 times from empty":
                discard esTemp.getNextNodes(bb, presenceBoolArrays)

            benchmark "Expanding to 1-37 nodes 1000 times from random":
                esTemp.randomize()
                discard esTemp.getNextNodes(bb, presenceBoolArrays)
            
            var 
                solutions = initHeapQueue[ElSolution]()
                toExpand: ElSolution
                toExclude = newBitArray(37)
            solutions.push(newElSolution(newBitArray(37), presenceBoolArrays))
            benchmark "Expanding 1000 steps (results dataset-dependent!)":
                toExpand = solutions.pop()
                for sol in getNextNodes(toExpand, toExclude, presenceBoolArrays):
                    solutions.push(sol)
                toExclude = toExclude or toExpand.elBA
            echo "Last solution on heap: ", solutions[0]
    
    if "--development" in args or "-d" in args:
        let presenceBitArrays = getPresenceBoolArrays()
        
        var solutions = initHeapQueue[ElSolution]()

        benchmark "exploring":
            solutions.push(newElSolution(newBitArray(37), presenceBitArrays))
            var toExpand: ElSolution
            for order in 1..37:
                var toExclude = newBitArray(37)
                var topSolutionOrder: int = 0
                while true:
                    toExpand = solutions.pop()
                    for sol in getNextNodes(toExpand, toExclude, presenceBitArrays):
                        solutions.push(sol)
                    toExclude = toExclude or toExpand.elBA
                    topSolutionOrder = count(solutions[0].elBA)
                    if topSolutionOrder >= order:
                        break
                    
                echo order, "=>", solutions[0], " => exlored:", len(solutions)

    
    echo "\nnimCSO Done!"




