"""Deriva la fase HU012 existente y una preparacion minima para Postman Desktop.

No envia peticiones, no contiene credenciales y no sustituye la coleccion completa.
"""
from copy import deepcopy
import json
from pathlib import Path
import uuid

HERE = Path(__file__).resolve().parent


def build():
    original = json.loads((HERE / 'WorkNet.postman_collection.json').read_text(encoding='utf-8'))
    hu011 = json.loads((HERE / 'WorkNet.HU011.postman_collection.json').read_text(encoding='utf-8'))
    phase = deepcopy(next(f for f in original['item'] if f['name'].startswith('14 ')))
    assert len(phase['item']) == 27
    phase['description'] = ('Ejecutar despues de 00 en una base nueva de qa.py prepare. '
                            'Conservar entorno entre carpetas. Casos PM255-PM281 originales, sin cambios.')
    logins = deepcopy(hu011['item'][0]['item'][:2])
    name = {
        'name': 'QA012-P01 - Preparar nombre esperado por PM255 y PM264',
        'id': str(uuid.uuid5(uuid.NAMESPACE_URL, 'worknet-hu012-preparar-nombre')),
        'request': {
            'method': 'PATCH', 'url': '{{base_url}}/account/',
            'auth': {'type': 'noauth'},
            'header': [{'key': 'Authorization', 'value': 'Token {{candidate_token}}'},
                       {'key': 'Content-Type', 'value': 'application/json'}],
            'body': {'mode': 'raw', 'raw': json.dumps({'full_name': 'Candidato actualizado Postman'}),
                     'options': {'raw': {'language': 'json'}}},
            'description': 'Solo candidato ficticio del run aislado. Prepara el mismo nombre que las fases previas de la coleccion completa.',
        },
        'event': [{'listen': 'test', 'script': {'type': 'text/javascript', 'exec': [
            'pm.test("HTTP 200", () => pm.response.to.have.status(200));',
            'pm.test("Nombre QA preparado", () => pm.expect(pm.response.json().user.full_name).to.equal("Candidato actualizado Postman"));',
        ]}}],
        'response': [],
    }
    uploaded = deepcopy(next(x for f in original['item'] for x in f['item'] if x['name'].startswith('PM242 ')))
    collection = deepcopy(original)
    collection['info']['name'] = 'WorkNet HU012 - preparacion y 27 casos originales'
    collection['info']['_postman_id'] = str(uuid.uuid5(uuid.NAMESPACE_URL, 'worknet-hu012-desktop'))
    collection['info']['description'] = ('Usar SOLO una base nueva de qa.py prepare y su entorno privado. '
        'Directorio de trabajo backend/postman. Ejecutar 00 y 14, una iteracion, conservando variables. '
        'No necesita repetir 01-13. No acredita ejecucion Desktop ni revision humana hasta realizarlas. '
        'PM279 y PM280 se conservan como parte de la coexistencia de CV. No prueba postulacion HU018.')
    collection['item'] = [
        {'name': '00 - HU012 sesiones y estado previo', 'description':
         'Base nueva, candidato sin CV; obtiene dos sesiones, prepara nombre y carga PDF ficticio. No usar el run de la interfaz.',
         'item': [*logins, name, uploaded]},
        phase,
    ]
    return collection


if __name__ == '__main__':
    target = HERE / 'WorkNet.HU012.postman_collection.json'
    target.write_text(json.dumps(build(), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Coleccion HU012 generada; no se ejecutaron peticiones.')
