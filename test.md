 D:\zabmin\zabmin> ^C    
PS D:\zabmin\zabmin> cd zabmin/agent
cd : Cannot find path 'D:\zabmin\zabmin\zabmin\agent' because it does not exist.
At line:1 char:1
+ cd zabmin/agent
+ ~~~~~~~~~~~~~~~
    + CategoryInfo          : ObjectNotFound: (D:\zabmin\zabmin\zabmin\agent:String) [Set-Location], ItemNotFoundException
    + FullyQualifiedErrorId : PathNotFound,Microsoft.PowerShell.Commands.SetLocationCommand
 
PS D:\zabmin\zabmin> cd ..
PS D:\zabmin> cd zabmin/agent
PS D:\zabmin\zabmin\agent> venv\Scripts\activate     
(venv) PS D:\zabmin\zabmin\agent> pip install pytest pytest-mock  
Requirement already satisfied: pytest in d:\zabmin\zabmin\agent\venv\lib\site-packages (9.1.1)
Requirement already satisfied: pytest-mock in d:\zabmin\zabmin\agent\venv\lib\site-packages (3.15.1)
Requirement already satisfied: colorama>=0.4 in d:\zabmin\zabmin\agent\venv\lib\site-packages (from pytest) (0.4.6)
Requirement already satisfied: iniconfig>=1.0.1 in d:\zabmin\zabmin\agent\venv\lib\site-packages (from pytest) (2.3.0)
Requirement already satisfied: packaging>=22 in d:\zabmin\zabmin\agent\venv\lib\site-packages (from pytest) (26.2)
Requirement already satisfied: pluggy<2,>=1.5 in d:\zabmin\zabmin\agent\venv\lib\site-packages (from pytest) (1.6.0)
Requirement already satisfied: pygments>=2.7.2 in d:\zabmin\zabmin\agent\venv\lib\site-packages (from pytest) (2.20.0)

[notice] A new release of pip is available: 25.0.1 -> 26.1.2
[notice] To update, run: python.exe -m pip install --upgrade pip
(venv) PS D:\zabmin\zabmin\agent> pytest
========================================================== test session starts ===========================================================
platform win32 -- Python 3.13.3, pytest-9.1.1, pluggy-1.6.0
rootdir: D:\zabmin\zabmin\agent
plugins: mock-3.15.1
collecting ... Windows fatal exception: access violation

Current thread 0x000040a4 (most recent call first):
  File "D:\zabmin\zabmin\agent\collectors\cpu.py", line 97 in collect
  File "D:\zabmin\zabmin\agent\test_async_collectors.py", line 29 in _inner
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\concurrent\futures\thread.py", line 59 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\concurrent\futures\thread.py", line 93 in _worker
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 992 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1041 in _bootstrap_inner
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1012 in _bootstrap

Thread 0x00001ac0 (most recent call first):
  File "D:\zabmin\zabmin\agent\cpu_state.py", line 37 in _init_perf_counters
  File "D:\zabmin\zabmin\agent\cpu_state.py", line 53 in perf_monitor_loop
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 992 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1041 in _bootstrap_inner
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1012 in _bootstrap

Thread 0x000031e0 (most recent call first):
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\windows_events.py", line 775 in _poll
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\windows_events.py", line 446 in select
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\base_events.py", line 1996 in _run_once
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\base_events.py", line 677 in run_forever
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\base_events.py", line 706 in run_until_complete
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\runners.py", line 118 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\runners.py", line 195 in run
  File "D:\zabmin\zabmin\agent\test_async_collectors.py", line 73 in <module>
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\assertion\rewrite.py", line 188 in exec_module
  File "<frozen importlib._bootstrap>", line 935 in _load_unlocked
  File "<frozen importlib._bootstrap>", line 1331 in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1360 in _find_and_load
  File "<frozen importlib._bootstrap>", line 1387 in _gcd_import
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\importlib\__init__.py", line 88 in import_module
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\pathlib.py", line 596 in import_path
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 508 in importtestmodule
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 561 in _getobj
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 290 in obj
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 577 in _register_setup_module_fixture
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 564 in collect
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 406 in collect
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 361 in from_call
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 408 in pytest_make_collect_report
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_callers.py", line 121 in _multicall
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_manager.py", line 120 in _hookexec
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_hooks.py", line 512 in __call__
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 589 in collect_one_node
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 895 in _collect_one_node
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 1032 in genitems
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 1035 in genitems
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 869 in perform_collect
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 394 in pytest_collection
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_callers.py", line 121 in _multicall
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_manager.py", line 120 in _hookexec
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_hooks.py", line 512 in __call__
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 383 in _main
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 330 in wrap_session
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 377 in pytest_cmdline_main
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_callers.py", line 121 in _multicall
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_manager.py", line 120 in _hookexec
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_hooks.py", line 512 in __call__
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\config\__init__.py", line 229 in _main
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\config\__init__.py", line 253 in _console_main
  File "D:\zabmin\zabmin\agent\venv\Scripts\pytest.exe\__main__.py", line 7 in <module>
  File "<frozen runpy>", line 88 in _run_code
  File "<frozen runpy>", line 198 in _run_module_as_main
Windows fatal exception: access violation

Current thread 0x000040a4 (most recent call first):
  File "D:\zabmin\zabmin\agent\collectors\cpu.py", line 97 in collect
  File "D:\zabmin\zabmin\agent\test_async_collectors.py", line 29 in _inner
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\concurrent\futures\thread.py", line 59 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\concurrent\futures\thread.py", line 93 in _worker
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 992 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1041 in _bootstrap_inner
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1012 in _bootstrap

Thread 0x00001ac0 (most recent call first):
  File "D:\zabmin\zabmin\agent\cpu_state.py", line 37 in _init_perf_counters
  File "D:\zabmin\zabmin\agent\cpu_state.py", line 53 in perf_monitor_loop
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 992 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1041 in _bootstrap_inner
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1012 in _bootstrap

Thread 0x000031e0 (most recent call first):
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\windows_events.py", line 775 in _poll
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\windows_events.py", line 446 in select
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\base_events.py", line 1996 in _run_once
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\base_events.py", line 677 in run_forever
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\base_events.py", line 706 in run_until_complete
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\runners.py", line 118 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\runners.py", line 195 in run
  File "D:\zabmin\zabmin\agent\test_async_collectors.py", line 73 in <module>
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\assertion\rewrite.py", line 188 in exec_module
  File "<frozen importlib._bootstrap>", line 935 in _load_unlocked
  File "<frozen importlib._bootstrap>", line 1331 in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1360 in _find_and_load
  File "<frozen importlib._bootstrap>", line 1387 in _gcd_import
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\importlib\__init__.py", line 88 in import_module
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\pathlib.py", line 596 in import_path
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 508 in importtestmodule
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 561 in _getobj
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 290 in obj
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 577 in _register_setup_module_fixture
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 564 in collect
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 406 in collect
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 361 in from_call
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 408 in pytest_make_collect_report
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_callers.py", line 121 in _multicall
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_manager.py", line 120 in _hookexec
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_hooks.py", line 512 in __call__
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 589 in collect_one_node
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 895 in _collect_one_node
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 1032 in genitems
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 1035 in genitems
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 869 in perform_collect
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 394 in pytest_collection
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_callers.py", line 121 in _multicall
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_manager.py", line 120 in _hookexec
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_hooks.py", line 512 in __call__
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 383 in _main
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 330 in wrap_session
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 377 in pytest_cmdline_main
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_callers.py", line 121 in _multicall
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_manager.py", line 120 in _hookexec
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_hooks.py", line 512 in __call__
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\config\__init__.py", line 229 in _main
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\config\__init__.py", line 253 in _console_main
  File "D:\zabmin\zabmin\agent\venv\Scripts\pytest.exe\__main__.py", line 7 in <module>
  File "<frozen runpy>", line 88 in _run_code
  File "<frozen runpy>", line 198 in _run_module_as_main
collected 1 item
Testing cpu...
  OK collectors.cpu.collect -> dict[7 keys]
Testing memory...
  OK collectors.memory.collect -> dict[6 keys]
Testing disk...
  OK collectors.disk.collect -> dict[6 keys]
Testing network...
  OK collectors.network.collect -> dict[4 keys]
Testing processes...
  OK collectors.processes.collect -> list[27 items]
Testing gpu...

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! KeyboardInterrupt !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 
C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\runners.py:123: KeyboardInterrupt
(to show a full traceback on KeyboardInterrupt use --full-trace)
==================================================== no tests ran in 61.51s (0:01:01) ==================================================== 
Win32 exception occurred releasing IUnknown at 0x000001D7AC15B520
(venv) PS D:\zabmin\zabmin\agent> ^C
(venv) PS D:\zabmin\zabmin\agent> cd D:\zabmin\zabmin\agent
(venv) PS D:\zabmin\zabmin\agent> del test_async_collectors.py  
(venv) PS D:\zabmin\zabmin\agent> pytest                        
========================================================== test session starts ===========================================================
platform win32 -- Python 3.13.3, pytest-9.1.1, pluggy-1.6.0
rootdir: D:\zabmin\zabmin\agent
plugins: mock-3.15.1
collecting ... Windows fatal exception: access violation

Current thread 0x000020a8 (most recent call first):
  File "D:\zabmin\zabmin\agent\collectors\cpu.py", line 97 in collect
  File "D:\zabmin\zabmin\agent\test_hang.py", line 32 in _inner
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\concurrent\futures\thread.py", line 59 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\concurrent\futures\thread.py", line 93 in _worker
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 992 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1041 in _bootstrap_inner
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1012 in _bootstrap

Thread 0x000008f0 (most recent call first):
  File "D:\zabmin\zabmin\agent\cpu_state.py", line 65 in perf_monitor_loop
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 992 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1041 in _bootstrap_inner
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1012 in _bootstrap

Thread 0x000002f8 (most recent call first):
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\windows_events.py", line 775 in _poll
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\windows_events.py", line 446 in select
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\base_events.py", line 1996 in _run_once
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\base_events.py", line 677 in run_forever
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\base_events.py", line 706 in run_until_complete
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\runners.py", line 118 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\runners.py", line 195 in run
  File "D:\zabmin\zabmin\agent\test_hang.py", line 64 in <module>
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\assertion\rewrite.py", line 188 in exec_module
  File "<frozen importlib._bootstrap>", line 935 in _load_unlocked
  File "<frozen importlib._bootstrap>", line 1331 in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1360 in _find_and_load
  File "<frozen importlib._bootstrap>", line 1387 in _gcd_import
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\importlib\__init__.py", line 88 in import_module
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\pathlib.py", line 596 in import_path
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 508 in importtestmodule
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 561 in _getobj
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 290 in obj
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 577 in _register_setup_module_fixture
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 564 in collect
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 406 in collect
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 361 in from_call
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 408 in pytest_make_collect_report
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_callers.py", line 121 in _multicall
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_manager.py", line 120 in _hookexec
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_hooks.py", line 512 in __call__
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 589 in collect_one_node
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 895 in _collect_one_node
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 1032 in genitems
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 1035 in genitems
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 869 in perform_collect
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 394 in pytest_collection
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_callers.py", line 121 in _multicall
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_manager.py", line 120 in _hookexec
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_hooks.py", line 512 in __call__
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 383 in _main
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 330 in wrap_session
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 377 in pytest_cmdline_main
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_callers.py", line 121 in _multicall
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_manager.py", line 120 in _hookexec
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_hooks.py", line 512 in __call__
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\config\__init__.py", line 229 in _main
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\config\__init__.py", line 253 in _console_main
  File "D:\zabmin\zabmin\agent\venv\Scripts\pytest.exe\__main__.py", line 7 in <module>
  File "<frozen runpy>", line 88 in _run_code
  File "<frozen runpy>", line 198 in _run_module_as_main
Windows fatal exception: access violation

Current thread 0x000020a8 (most recent call first):
  File "D:\zabmin\zabmin\agent\collectors\cpu.py", line 97 in collect
  File "D:\zabmin\zabmin\agent\test_hang.py", line 32 in _inner
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\concurrent\futures\thread.py", line 59 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\concurrent\futures\thread.py", line 93 in _worker
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 992 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1041 in _bootstrap_inner
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1012 in _bootstrap

Thread 0x000008f0 (most recent call first):
  File "D:\zabmin\zabmin\agent\cpu_state.py", line 65 in perf_monitor_loop
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 992 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1041 in _bootstrap_inner
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\threading.py", line 1012 in _bootstrap

Thread 0x000002f8 (most recent call first):
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\windows_events.py", line 775 in _poll
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\windows_events.py", line 446 in select
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\base_events.py", line 1996 in _run_once
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\base_events.py", line 677 in run_forever
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\base_events.py", line 706 in run_until_complete
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\runners.py", line 118 in run
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\runners.py", line 195 in run
  File "D:\zabmin\zabmin\agent\test_hang.py", line 64 in <module>
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\assertion\rewrite.py", line 188 in exec_module
  File "<frozen importlib._bootstrap>", line 935 in _load_unlocked
  File "<frozen importlib._bootstrap>", line 1331 in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1360 in _find_and_load
  File "<frozen importlib._bootstrap>", line 1387 in _gcd_import
  File "C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\importlib\__init__.py", line 88 in import_module
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\pathlib.py", line 596 in import_path
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 508 in importtestmodule
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 561 in _getobj
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 290 in obj
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 577 in _register_setup_module_fixture
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\python.py", line 564 in collect
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 406 in collect
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 361 in from_call
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 408 in pytest_make_collect_report
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_callers.py", line 121 in _multicall
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_manager.py", line 120 in _hookexec
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_hooks.py", line 512 in __call__
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\runner.py", line 589 in collect_one_node
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 895 in _collect_one_node
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 1032 in genitems
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 1035 in genitems
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 869 in perform_collect
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 394 in pytest_collection
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_callers.py", line 121 in _multicall
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_manager.py", line 120 in _hookexec
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_hooks.py", line 512 in __call__
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 383 in _main
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 330 in wrap_session
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\main.py", line 377 in pytest_cmdline_main
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_callers.py", line 121 in _multicall
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_manager.py", line 120 in _hookexec
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\pluggy\_hooks.py", line 512 in __call__
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\config\__init__.py", line 229 in _main
  File "D:\zabmin\zabmin\agent\venv\Lib\site-packages\_pytest\config\__init__.py", line 253 in _console_main
  File "D:\zabmin\zabmin\agent\venv\Scripts\pytest.exe\__main__.py", line 7 in <module>
  File "<frozen runpy>", line 88 in _run_code
  File "<frozen runpy>", line 198 in _run_module_as_main
collected 47 items / 1 error

================================================================= ERRORS ================================================================= 
______________________________________________________ ERROR collecting test_ws2.py ______________________________________________________ 
C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\tasks.py:507: in wait_for
    return await fut
           ^^^^^^^^^
venv\Lib\site-packages\websockets\asyncio\connection.py:303: in recv
    return await self.recv_messages.get(decode)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
venv\Lib\site-packages\websockets\asyncio\messages.py:159: in get
    frame = await self.frames.get(not self.closed)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
venv\Lib\site-packages\websockets\asyncio\messages.py:51: in get
    await self.get_waiter
E   asyncio.exceptions.CancelledError

The above exception was the direct cause of the following exception:
test_ws2.py:26: in <module>
    asyncio.run(t())
C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\runners.py:195: in run
    return runner.run(main)
           ^^^^^^^^^^^^^^^^
C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\runners.py:118: in run
    return self._loop.run_until_complete(task)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\base_events.py:719: in run_until_complete
    return future.result()
           ^^^^^^^^^^^^^^^
test_ws2.py:8: in t
    msg = await asyncio.wait_for(ws.recv(), timeout=10)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\tasks.py:506: in wait_for
    async with timeouts.timeout(timeout):
               ^^^^^^^^^^^^^^^^^^^^^^^^^
C:\Users\shifttech\AppData\Local\Programs\Python\Python313\Lib\asyncio\timeouts.py:116: in __aexit__
    raise TimeoutError from exc_val
E   TimeoutError
------------------------------------------------------------ Captured stdout ------------------------------------------------------------- 
Connected in 0.0s
[6.0s] v3 cpu=90.3% 0 gpus 30 procs
[12.0s] v3 cpu=0.0% 0 gpus 0 procs
[18.1s] v3 cpu=0.0% 0 gpus 0 procs
============================================================ warnings summary ============================================================ 
test_ws.py:10
  D:\zabmin\zabmin\agent\test_ws.py:10: RuntimeWarning: coroutine 'Connection.close' was never awaited
    ws.close()
  Enable tracemalloc to get traceback where the object was allocated.
  See https://docs.pytest.org/en/stable/how-to/capture-warnings.html#resource-warnings for more info.

test_ws3.py:16
  D:\zabmin\zabmin\agent\test_ws3.py:16: RuntimeWarning: coroutine 'Connection.close' was never awaited
    ws.close()
  Enable tracemalloc to get traceback where the object was allocated.
  See https://docs.pytest.org/en/stable/how-to/capture-warnings.html#resource-warnings for more info.

test_ws4.py:14
  D:\zabmin\zabmin\agent\test_ws4.py:14: RuntimeWarning: coroutine 'Connection.close' was never awaited
    ws.close()
  Enable tracemalloc to get traceback where the object was allocated.
  See https://docs.pytest.org/en/stable/how-to/capture-warnings.html#resource-warnings for more info.

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
======================================================== short test summary info ========================================================= 
ERROR test_ws2.py - TimeoutError
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Interrupted: 1 error during collection !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 
================================================ 3 warnings, 1 error in 581.34s (0:09:41) ================================================ 
Win32 exception occurred releasing IUnknown at 0x000001A65BCD2E30
(venv) PS D:\zabmin\zabmin\agent> ^C
(venv) PS D:\zabmin\zabmin\agent> 