"""Run existing tests once, recording per-test results without raw tracebacks."""
import contextlib
import io
import json
import os
from pathlib import Path
import sys
import unittest


def main():
    root=Path(sys.argv[1]).resolve(); output=Path(sys.argv[2]).resolve()
    sys.path.insert(0,str(root/'backend')); os.environ.setdefault('DJANGO_SETTINGS_MODULE','config.settings')
    import django
    django.setup()
    from django.test.runner import DiscoverRunner
    rows=[]
    class RecordedResult(unittest.TextTestResult):
        def addSuccess(self,test):
            super().addSuccess(test); rows.append({'prueba':test.id(),'resultado':'aprobada'})
        def addFailure(self,test,error):
            super().addFailure(test,error); rows.append({'prueba':test.id(),'resultado':'fallida'})
        def addError(self,test,error):
            super().addError(test,error); rows.append({'prueba':test.id(),'resultado':'error'})
    class RecordedRunner(DiscoverRunner):
        def get_test_runner_kwargs(self):
            return {**super().get_test_runner_kwargs(),'resultclass':RecordedResult}
    log=io.StringIO()
    with contextlib.redirect_stdout(log),contextlib.redirect_stderr(log):
        failures=RecordedRunner(verbosity=1,interactive=False).run_tests(['accounts','candidate_dashboard'])
    output.mkdir(parents=True,exist_ok=True)
    report={'fecha_cliente':'2026-10-18','tipo':'Suite automática existente de Django','codigo_backend':'a40045545ff874b079392d55786992786093ee83','base':'Base temporal del runner, independiente de la base habitual y de QA HTTP','revision_humana':'pendiente','pruebas':rows,'total':len(rows),'fallos':failures}
    (output/'suite.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f"Suite backend: {len(rows)} pruebas; {failures} fallos. Informe sin credenciales.")
    return failures


if __name__=='__main__': raise SystemExit(main())
