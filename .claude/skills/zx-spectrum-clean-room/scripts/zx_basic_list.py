#!/usr/bin/env python3
"""List the Sinclair BASIC program(s) inside a ZX Spectrum .tap, .tzx or .sna file.

Usage:
    python3 -I zx_basic_list.py GAME.tap [--blocks] [--strings]

Prints every BASIC program found as a readable listing, one line per BASIC line.
It handles:
  * normal "Program:" blocks (SAVE "name" [LINE n]);
  * programs saved as a memory dump that starts at or below the system
    variables (e.g. SAVE "name" CODE 23552,n), by reading PROG and VARS from
    the dumped system variables.
  * 48K .sna snapshots (the program is found through PROG and VARS).
--blocks also prints the tape's block structure.
--strings also prints printable text found in machine-code / data blocks
  (runs of at least 6 characters; a final character with bit 7 set, a common
  end-of-string marker in Spectrum games, is accepted), for games that have no
  BASIC listing.

Control codes are shown as {n}, user-defined graphics as {UDG-A}..{UDG-U},
block graphics as {GFX-n}. Hidden 5-byte number forms are skipped.
"""
import sys

KEYWORDS = [
    "RND", "INKEY$", "PI", "FN ", "POINT ", "SCREEN$ ", "ATTR ", "AT ", "TAB ",
    "VAL$ ", "CODE ", "VAL ", "LEN ", "SIN ", "COS ", "TAN ", "ASN ", "ACS ",
    "ATN ", "LN ", "EXP ", "INT ", "SQR ", "SGN ", "ABS ", "PEEK ", "IN ",
    "USR ", "STR$ ", "CHR$ ", "NOT ", "BIN ", " OR ", " AND ", "<=", ">=", "<>",
    " LINE ", " THEN ", " TO ", " STEP ", " DEF FN ", " CAT ", " FORMAT ",
    " MOVE ", " ERASE ", " OPEN #", " CLOSE #", " MERGE ", " VERIFY ", " BEEP ",
    " CIRCLE ", " INK ", " PAPER ", " FLASH ", " BRIGHT ", " INVERSE ", " OVER ",
    " OUT ", " LPRINT ", " LLIST ", " STOP ", " READ ", " DATA ", " RESTORE ",
    " NEW ", " BORDER ", " CONTINUE ", " DIM ", " REM ", " FOR ", " GO TO ",
    " GO SUB ", " INPUT ", " LOAD ", " LIST ", " LET ", " PAUSE ", " NEXT ",
    " POKE ", " PRINT ", " PLOT ", " RUN ", " SAVE ", " RANDOMIZE ", " IF ",
    " CLS ", " DRAW ", " CLEAR ", " RETURN ", " COPY ",
]
SYSVARS = 23552
PROG, VARS = 23635, 23627


def tap_blocks(data):
    i = 0
    while i + 2 <= len(data):
        n = data[i] | data[i + 1] << 8
        yield data[i + 2:i + 2 + n]
        i += 2 + n


def tzx_blocks(data):
    if not data.startswith(b"ZXTape!\x1a"):
        raise ValueError("not a TZX file")
    i = 10

    def u(off, n):
        return int.from_bytes(data[off:off + n], "little")

    while i < len(data):
        bid = data[i]
        i += 1
        if bid == 0x10:
            n = u(i + 2, 2); yield data[i + 4:i + 4 + n]; i += 4 + n
        elif bid == 0x11:
            n = u(i + 15, 3); yield data[i + 18:i + 18 + n]; i += 18 + n
        elif bid == 0x14:
            n = u(i + 7, 3); yield data[i + 10:i + 10 + n]; i += 10 + n
        elif bid == 0x12: i += 4
        elif bid == 0x13: i += 1 + data[i] * 2
        elif bid == 0x15: i += 8 + u(i + 5, 3)
        elif bid in (0x18, 0x19): i += 4 + u(i, 4)
        elif bid in (0x20, 0x23, 0x24): i += 2
        elif bid in (0x21, 0x30): i += 1 + data[i]
        elif bid in (0x22, 0x25, 0x27): pass
        elif bid == 0x26: i += 2 + u(i, 2) * 2
        elif bid in (0x28, 0x32): i += 2 + u(i, 2)
        elif bid == 0x2A: i += 4
        elif bid == 0x2B: i += 5
        elif bid == 0x31: i += 2 + data[i + 1]
        elif bid == 0x33: i += 1 + data[i] * 3
        elif bid == 0x35: i += 20 + u(i + 16, 4)
        elif bid == 0x5A: i += 9
        else:
            raise ValueError("unsupported TZX block 0x%02X at %d" % (bid, i - 1))


def detokenize(body):
    out, j = [], 0
    while j < len(body):
        c = body[j]
        if c == 13:
            break
        if c == 14:          # hidden 5-byte number follows the printed digits
            j += 6; continue
        if 16 <= c <= 21:    # INK/PAPER/FLASH/BRIGHT/INVERSE/OVER control + 1 byte
            j += 2; continue
        if c in (22, 23):    # AT / TAB control + 2 bytes
            j += 3; continue
        if c >= 165:
            kw = KEYWORDS[c - 165]
            if kw.startswith(" ") and (not out or out[-1].endswith(" ")):
                kw = kw[1:]
            out.append(kw)
        elif 144 <= c <= 164:
            out.append("{UDG-%s}" % chr(c - 144 + 65))
        elif 128 <= c <= 143:
            out.append("{GFX-%d}" % (c - 128))
        elif c == 96:
            out.append("£")
        elif c == 127:
            out.append("©")
        elif 32 <= c < 127:
            out.append(chr(c))
        else:
            out.append("{%d}" % c)
        j += 1
    return "".join(out).rstrip()


def listing(prog):
    lines, i = [], 0
    while i + 4 <= len(prog):
        number = prog[i] << 8 | prog[i + 1]
        length = prog[i + 2] | prog[i + 3] << 8
        if number > 9999:
            break
        body = prog[i + 4:i + 4 + length]
        if body[:1] == bytes([0xEA]) and length > 40 and sum(32 <= c < 127 for c in body) < length * 0.6:
            lines.append("%4d REM <%d bytes of embedded machine code/data>" % (number, length))
        else:
            lines.append("%4d %s" % (number, detokenize(body).lstrip()))
        i += 4 + length
    return lines


def programs(blocks, show_blocks=False):
    header = None
    for index, b in enumerate(blocks):
        if len(b) == 19 and b[0] == 0:
            kind = ["Program", "Number array", "Character array", "Bytes"][min(b[1], 3)]
            name = b[2:12].decode("latin-1")
            length = b[12] | b[13] << 8
            p1 = b[14] | b[15] << 8
            p2 = b[16] | b[17] << 8
            header = (b[1], name, length, p1, p2)
            if show_blocks:
                print("# header: %s %r length=%d param1=%d param2=%d" % (kind, name, length, p1, p2))
            continue
        payload = b[1:-1]  # strip flag and checksum
        if show_blocks:
            print("# data: %d bytes" % len(payload))
        if header and header[0] == 0:
            yield index, header[1].strip(), payload[:header[4]]
        elif header and header[0] == 3 and header[3] <= SYSVARS and header[3] + len(payload) > PROG + 2:
            base = header[3]

            def word(addr):
                return payload[addr - base] | payload[addr - base + 1] << 8
            start, end = word(PROG), word(VARS)
            if base <= start < end <= base + len(payload):
                yield index, header[1].strip() + " (from CODE dump)", payload[start - base:end - base]
        header = None


def text_runs(data, minimum=6):
    """Yield (offset, text) for printable runs of text.

    A last character with bit 7 set (a common end-of-string marker) is accepted.
    Runs are split at 3+ spaces (fixed-width padded names) and kept only if at
    least half of their non-space characters are letters.
    """
    import re

    def emit(start, chars):
        text = "".join(chars)
        pos = 0
        for part in re.split(r"( {3,})", text):
            stripped = part.strip()
            letters = sum(ch.isalpha() for ch in stripped)
            visible = len(stripped.replace(" ", ""))
            if len(stripped) >= minimum and letters >= 4 and letters * 2 >= visible:
                yield start + pos + (len(part) - len(part.lstrip())), stripped
            pos += len(part)

    run, start = [], 0
    for i, c in enumerate(data):
        if 32 <= c < 127:
            if not run:
                start = i
            run.append(chr(c))
            continue
        if 160 <= c < 255 and run:  # last character with bit 7 set
            run.append(chr(c & 0x7F))
        yield from emit(start, run)
        run = []
    yield from emit(start, run)


def sna_program(data):
    if len(data) != 49179:
        raise ValueError("only 48K .sna snapshots are supported")
    ram, base = data[27:], 16384

    def word(addr):
        return ram[addr - base] | ram[addr - base + 1] << 8
    start, end = word(PROG), word(VARS)
    return ram, ram[start - base:end - base]


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        print(__doc__)
        return 2
    data = open(argv[1], "rb").read()
    strings = "--strings" in argv
    found = 0
    if argv[1].lower().endswith(".sna"):
        ram, prog = sna_program(data)
        found = 1
        print("# program (from snapshot)")
        print("\n".join(listing(prog)))
        if strings:
            print("# text in RAM")
            for off, t in text_runs(ram[6912:]):
                print("%5d %s" % (16384 + 6912 + off, t))
        return 0
    blocks = list(tzx_blocks(data) if data.startswith(b"ZXTape!") else tap_blocks(data))
    program_blocks = set()
    for index, name, prog in programs(blocks, "--blocks" in argv):
        program_blocks.add(index)
        found += 1
        print("# program %r" % name)
        print("\n".join(listing(prog)))
    if strings:
        for n, b in enumerate(blocks):
            if (len(b) == 19 and b[0] == 0) or n in program_blocks:
                continue
            runs = list(text_runs(b[1:-1]))
            if runs:
                print("# text in block %d" % n)
                for off, t in runs:
                    print("%5d %s" % (off, t))
        if not found:
            return 0
    if not found:
        print("# no BASIC program found (machine-code game? look for a fan disassembly)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
