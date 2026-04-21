from packaging.version import Version


def parse(v: str) -> Version:
    return Version(v)
