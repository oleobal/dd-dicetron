from collections import deque


class History:
    def __init__(self):
        self.contents = {}

    def add_item(self, ident, item):
        if ident not in self.contents:
            self.contents[ident] = deque(maxlen=10)
        self.contents[ident].appendleft(item)

    def get_item(self, ident, index):
        return self.contents.get(ident, [])[index]

    def get_pretty_history(self, ident):
        h = self.contents.get(ident, [])
        msg = ""
        for i in reversed(range(len(h))):
            msg += f"{i:>2} {h[i]}\n"
        return msg
