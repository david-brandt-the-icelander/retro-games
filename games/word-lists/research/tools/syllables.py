"""Icelandic syllable count: vowel nuclei, with the diphthongs au, ei, ey counted as one."""
import re
_NUC = re.compile(r"au|ei|ey|[aáeéiíoóuúyýæö]", re.I)
def syllables(word: str) -> int:
    return len(_NUC.findall(word.lower()))
if __name__ == "__main__":
    for w, n in [("hús",1),("baun",1),("hey",1),("fríið",2),("hestur",2),("jólasveinn",3),("eldgos",2),("æður",2),("tröll",1),("augu",2)]:
        assert syllables(w) == n, (w, syllables(w), n)
    print("ok")
