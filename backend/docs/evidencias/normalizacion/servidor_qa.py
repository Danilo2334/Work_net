"""HTTP QA isolated, file mail only, without logging signed request URLs."""
from pathlib import Path
import runpy
import sys
from django.core.servers.basehttp import WSGIRequestHandler

root=Path(sys.argv[1]).resolve()
WSGIRequestHandler.log_message=lambda *args,**kwargs:None
script=root/'frontend/tool/qa_backend.py'
sys.argv=[str(script),'--port','8005','--frontend-origin','http://localhost:55004']
runpy.run_path(str(script),run_name='__main__')
