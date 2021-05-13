# copy of Kotlin's trimIndent
def trim_indent(s: str) -> str:
    source = s.splitlines()
    while source[0] == "":
        source = source[1:]
    while source[-1] == "":
        source = source[:-1]
    leading = ""
    for i in range(len(source[0])):
        if source[0][i].isspace():
            leading += source[0][i]
        else:
            break
    source = [s[len(leading) :] for s in source]
    # while source[0] == "":
    #    source=source[1:]
    # while source[-1] == "":
    #    source=source[:-1]
    return "\n".join(source)
