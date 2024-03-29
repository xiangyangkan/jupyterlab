import os
import hashlib
import random
from jupyter_server.auth import passwd

c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = int(os.getenv('PORT', 8888))
c.ServerApp.open_browser = False
c.MultiKernelManager.default_kernel_name = 'python3'

# sets a password if PASSWORD is set in the environment
if 'NOTEBOOK_PASS' in os.environ:
    c.ServerApp.password = passwd(os.environ['NOTEBOOK_PASS'])
    del os.environ['NOTEBOOK_PASS']
else:
    c.ServerApp.password = ''

if 'NOTEBOOK_USER' in os.environ:
    c.ServerApp.notebook_dir = '/root/' + os.environ['NOTEBOOK_USER']
    del os.environ['NOTEBOOK_USER']