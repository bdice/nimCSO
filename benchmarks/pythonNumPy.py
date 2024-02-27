import time
import sys
import numpy as np

with open('alloyList.txt', 'r') as f:
    alloyList = f.read().splitlines()
elementalList = [s.split(',') for s in alloyList]

assert len(elementalList)==2150
elementOrder = ["Fe", "Cr", "Ni", "Co", "Al", "Ti", "Nb", "Cu", "Mo", "Ta", "Zr", "V", "Hf", "W", "Mn", "Si", "Re", "B", "Ru", "C", "Sn", "Mg", "Zn", "Li", "O", "Y", "Pd", "N", "Ca", "Ir", "Sc", "Ge", "Be", "Ag", "Nd", "S", "Ga"]

def elList2vec(elList):
    return np.array([1 if el in elList else 0 for el in elementOrder], dtype=np.int8)

elMatrix = np.array([elList2vec(comp) for comp in elementalList], dtype=np.int8)

def elList2negVec(elList):
    return np.array([0 if el in elList else 1 for el in elementOrder], dtype=np.int8)

def preventedData(elList):
    um = elMatrix*elList2negVec(set(elementOrder).difference(set(elList)))
    return np.amax(um, axis=1).sum()

assert preventedData(['Cr', 'Fe', 'Ni', 'Co', 'Al', 'Ti']) == 1955

if __name__ == '__main__':
    print(sys.getsizeof(elMatrix))

    evalN = 10000
    print("\nCount Data Points Prevented by Removal of Cr-Fe-Ni-Co-Al (NumPy) from Elements")
    for i in range(evalN):
        preventedData(['Cr', 'Fe', 'Ni', 'Co', 'Al', 'Ti'])
    t0 = time.time()
    for i in range(evalN):
        preventedData(['Cr', 'Fe', 'Ni', 'Co', 'Al', 'Ti'])
    time_us = (time.time() - t0) * 1e6 / evalN
    print(f"CPU Time [per dataset evaluation] {time_us:.1f} us")
    time_ns_pc = time_us * 1000 / len(elementalList)
    print(f"CPU Time [per comparison] {time_ns_pc:.1f} ns")

    print("\nCount Data Points Prevented by Removal of Cr-Fe-Ni-Co-Al (NumPy) from Vector (like nimCSO)")
    for i in range(evalN):
        elVec = np.zeros(37, dtype=np.int8)
        for i in range(6):
            elVec[i] = 1
        um = elMatrix*elVec
        np.amax(um, axis=1).sum()
    t0 = time.time()
    for i in range(evalN):
        elVec = np.zeros(37, dtype=np.int8)
        for i in range(6):
            elVec[i] = 1
        um = elMatrix*elVec
        np.amax(um, axis=1).sum()
    time_us = (time.time() - t0) * 1e6 / evalN
    print(f"CPU Time [per dataset evaluation] {time_us:.1f} us")
    time_ns_pc = time_us * 1000 / len(elementalList)
    print(f"CPU Time [per comparison] {time_ns_pc:.1f} ns")