"""Archivos y estados auxiliares de HU011, exclusivamente en una base QA local."""
import argparse
import hashlib
import io
import json

from pypdf import PdfWriter
from pypdf.generic import ArrayObject, DictionaryObject, NameObject

import qa


def create_fixtures():
    folder = qa.LOCAL / 'hu011-extra'
    folder.mkdir(parents=True, exist_ok=True)
    for pages in (50, 51):
        writer = PdfWriter()
        for _ in range(pages):
            writer.add_blank_page(width=595, height=842)
        writer.add_metadata({'/Title': f'Archivo ficticio QA {pages} paginas'})
        save_fixture(folder / f'{pages}-paginas.pdf', writer)
    writer = PdfWriter()
    writer.add_blank_page(width=595, height=842)
    writer._root_object[NameObject('/AcroForm')] = DictionaryObject({
        NameObject('/Fields'): ArrayObject(),
    })
    save_fixture(folder / 'formulario.pdf', writer)
    print('Archivos sintéticos disponibles en postman/.local/hu011-extra.')


def save_fixture(path, writer):
    buffer = io.BytesIO()
    writer.write(buffer)
    content = buffer.getvalue()
    if path.exists():
        if path.read_bytes() != content:
            raise ValueError(f'{path.name} ya existe con otro contenido; no se sobrescribe.')
    else:
        path.write_bytes(content)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('fixtures', 'unverified', 'verified', 'inspect'))
    parser.add_argument('--run', help='run-* creado por qa.py prepare; omitir usa el último.')
    args = parser.parse_args()
    # load_run comprueba la carpeta, el marcador QA y la SQLite asociada.
    path, state = qa.load_run(args.run)
    if args.action == 'fixtures':
        create_fixtures()
        return
    qa.configure(path, state)
    from accounts.models import User
    from curriculum.models import GeneratedCurriculum, UploadedCurriculum
    user = User.objects.get(email='candidate.postman@worknet.test', role='candidato')
    if args.action in ('unverified', 'verified'):
        User.objects.filter(pk=user.pk).update(email_verified=args.action == 'verified')
        print('Candidato ficticio verificado:', args.action == 'verified')
        return
    result = {
        'run': path.name,
        'candidate_verified': user.email_verified,
        'generated_count': GeneratedCurriculum.objects.count(),
        'uploaded': [
            {
                'candidate_id': row.candidate_id, 'filename': row.filename,
                'size_bytes': row.size_bytes,
                'sha256': hashlib.sha256(bytes(row.document)).hexdigest(),
            }
            for row in UploadedCurriculum.objects.order_by('candidate_id')
        ],
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
