"""Smoke test for src/ashenvale_survivor.lua outside Warcraft III.

Runs the script against mock.lua (stand-ins for the natives it uses) and plays
it through with drive.lua. Needs Lua 5.3 through lupa:  pip install lupa
Usage:  python tools/smoketest/run.py
        python tools/smoketest/run.py --balance [zone] [difficulty] [hero ids...]   (balance.lua's report)
"""
import os, sys
import lupa.lua53 as lua

here = os.path.dirname(os.path.abspath(__file__))
balance = len(sys.argv) > 1 and sys.argv[1] == '--balance'
script = sys.argv[1] if len(sys.argv) > 1 and not balance else os.path.join(here, '..', '..', 'src', 'ashenvale_survivor.lua')
rt = lua.LuaRuntime(unpack_returned_tuples=True)
loader = rt.eval('function(s, n) local f, e = load(s, n) if not f then error(e) end return f end')


def run(path):
    with open(path, encoding='utf-8') as f:
        return loader(f.read(), '@' + os.path.basename(path))()


run(os.path.join(here, 'mock.lua'))
run(script)
def print_script_output():
    printed = rt.eval('MOCK.printed')
    for i in range(1, min(12, len(printed)) + 1):
        print('  script error:', printed[i])


if balance:
    rt.globals().BALANCE_ARGS = rt.table_from(sys.argv[2:])
try:
    print(run(os.path.join(here, 'balance.lua' if balance else 'drive.lua')))
    print_script_output()
except Exception as e:
    print('FAILED:', e)
    print_script_output()
    sys.exit(1)
