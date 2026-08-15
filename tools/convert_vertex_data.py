"""
Takes raw vertex data, provided from the tutorial as formatted C/C++ array values, and
converts them to this codebase concept of vertex data
"""

from enum import Enum, auto
from pathlib import Path


class FormatType(Enum):
    POS3_NORM3 = auto()


OUTPUT_DATA_FILE_PATH = Path("out_vertex_data.txt")

# to simplify, just create this file at CWD, each line should contain a "vertex"
INPUT_DATA_FILE_PATH = Path("vertex_data.txt")

# modify this to match the input data
INPUT_DATA_FORMAT = FormatType.POS3_NORM3

if __name__ == "__main__":
    if not INPUT_DATA_FILE_PATH.exists():
        raise FileNotFoundError(
            f"Cannot find input file: {INPUT_DATA_FILE_PATH.absolute()}, please provide it"
        )

    with INPUT_DATA_FILE_PATH.open() as f:
        raw_data_lines = f.readlines()

    raw_vertices = []
    for line in raw_data_lines:
        raw_vertex = line.split()
        for i, scalar in enumerate(raw_vertex):
            raw_vertex[i] = scalar.removesuffix("f,").removesuffix("f")

        if raw_vertex:
            raw_vertices.append(raw_vertex)

    print(f"Processing {len(raw_vertices)} vertices")

    output = []
    output.append("_VERTICES_ := [?]/*TYPE_NAME_HERE*/{\n")

    match INPUT_DATA_FORMAT:
        case FormatType.POS3_NORM3:
                  output.append("\t{:<22}{}\n".format("// positions", "// normals"))


    for raw_vertex in raw_vertices:
        match INPUT_DATA_FORMAT:
            case FormatType.POS3_NORM3:
                pos = "".join([f"{v:>4}, " for v in raw_vertex[0:3]]).rstrip()
                norm = "".join([f"{v:>4}, " for v in raw_vertex[3:]]).rstrip()
                output.append("\t{{" + pos + "}, {" + norm + "},},\n")

    output.append("}")

    text_output = "".join(output)

    with OUTPUT_DATA_FILE_PATH.open("w+") as f:
        f.write(text_output)

    print(f"Vectices converted to Odin format: {OUTPUT_DATA_FILE_PATH}")
