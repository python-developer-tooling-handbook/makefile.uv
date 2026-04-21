from demo import parse


def test_parse():
    assert parse("1.2.3") > parse("1.2.2")
